from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import date, timedelta

from app.database import get_db
from app.models.user import User
from app.models.behavior_log import BehaviorLog
from app.models.prediction import Prediction
from app.services.auth_service import get_current_user
from app.schemas.analytics import Phase4DashboardSummary, Phase4WeeklyTrends
from app.schemas.common import StandardizedResponse
from cachetools import TTLCache

# In-memory caches for performance optimization (5-minute TTL)
summary_cache = TTLCache(maxsize=1000, ttl=300)
trends_cache = TTLCache(maxsize=1000, ttl=300)

# We use /api/analytics as a prefix to avoid colliding with the older /api/dashboard-summary from previous phases
router = APIRouter(prefix="/api/analytics", tags=["Phase 4 - Analytics"])

@router.get("/dashboard-summary", response_model=StandardizedResponse[Phase4DashboardSummary])
async def get_dashboard_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Returns Phase 4 Dashboard analytics."""
    if current_user.user_id in summary_cache:
        return {"success": True, "data": summary_cache[current_user.user_id]}
        
    thirty_days_ago = date.today() - timedelta(days=30)
    
    logs = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id,
        BehaviorLog.date >= thirty_days_ago
    ).all()

    if not logs:
        result = Phase4DashboardSummary(
            avg_sleep=0.0,
            avg_mood=0.0,
            avg_screen_time=0.0,
            stress_score=0,
            wellness_score=0,
            burnout_risk=0,
            triggers=[]
        )
        return {"success": True, "data": result}

    avg_sleep = round(sum(l.sleep_hours for l in logs) / len(logs), 1)
    avg_mood = round(sum(l.mood for l in logs) / len(logs), 1)
    avg_screen = round(sum(l.screen_time for l in logs) / len(logs), 1)

    latest_pred = db.query(Prediction).filter(
        Prediction.user_id == current_user.user_id
    ).order_by(Prediction.prediction_date.desc()).first()

    stress = int(round(latest_pred.stress_score)) if latest_pred else 0

    # Calculate Wellness Score (0-100)
    sleep_score = min(avg_sleep / 8.0 * 100, 100)
    mood_score = avg_mood * 10
    stress_inverse = max(100 - stress, 0)
    wellness_score = int((sleep_score * 0.4) + (mood_score * 0.4) + (stress_inverse * 0.2))

    # Calculate Burnout Risk (0-100)
    burnout_risk = int(stress * 0.5 + (100 - sleep_score) * 0.3 + (100 - mood_score) * 0.2)

    # Detect Triggers
    triggers = []
    if avg_sleep < 6.0:
        triggers.append("Low average sleep (< 6 hours)")
    if avg_screen > 6.0:
        triggers.append("High screen time (> 6 hours)")
    if avg_mood < 4.0:
        triggers.append("Consistently low mood")
    if stress > 70:
        triggers.append("High AI stress levels")

    result = Phase4DashboardSummary(
        avg_sleep=avg_sleep,
        avg_mood=avg_mood,
        avg_screen_time=avg_screen,
        stress_score=stress,
        wellness_score=wellness_score,
        burnout_risk=burnout_risk,
        triggers=triggers
    )
    summary_cache[current_user.user_id] = result
    return {"success": True, "data": result}

@router.get("/weekly-trends", response_model=StandardizedResponse[Phase4WeeklyTrends])
async def get_weekly_trends(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Returns weekly trends."""
    if current_user.user_id in trends_cache:
        return {"success": True, "data": trends_cache[current_user.user_id]}
        
    today = date.today()
    seven_days_ago = today - timedelta(days=6)  # Today + 6 previous days = 7 days
    
    logs = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id,
        BehaviorLog.date >= seven_days_ago
    ).all()

    # Create a map of date -> log
    log_map = {log.date: log for log in logs}
    
    sleep = []
    screen_time = []
    mood = []
    
    # Fill exactly 7 days
    for i in range(7):
        current_date = seven_days_ago + timedelta(days=i)
        log = log_map.get(current_date)
        if log:
            sleep.append(round(log.sleep_hours, 1))
            screen_time.append(round(log.screen_time, 1))
            mood.append(float(log.mood))
        else:
            sleep.append(0.0)
            screen_time.append(0.0)
            mood.append(0.0)

    result = Phase4WeeklyTrends(
        sleep=sleep,
        screen_time=screen_time,
        mood=mood
    )
    trends_cache[current_user.user_id] = result
    return {"success": True, "data": result}
