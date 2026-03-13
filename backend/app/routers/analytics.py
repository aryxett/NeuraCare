from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import date, timedelta, datetime
import random

from app.database import get_db
from app.models.user import User
from app.models.behavior_log import BehaviorLog
from app.models.prediction import Prediction
from app.services.insight_engine import generate_insights, get_risk_level
from app.schemas.analytics import Phase4DashboardSummary, Phase4WeeklyTrends
from app.schemas.common import StandardizedResponse
from app.services.auth_service import get_current_user
from cachetools import TTLCache

# In-memory caches for performance optimization (10-second TTL for near-real-time updates)
summary_cache = TTLCache(maxsize=1000, ttl=10)
trends_cache = TTLCache(maxsize=1000, ttl=10)

# We use /api/analytics as a prefix to avoid colliding with the older /api/dashboard-summary from previous phases
router = APIRouter(prefix="/api/analytics", tags=["Phase 4 - Analytics"])

@router.get("/dashboard-summary", response_model=StandardizedResponse[Phase4DashboardSummary])
async def get_dashboard_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Returns Phase 4 Dashboard analytics."""

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

    # Use Insight Engine for deeper analysis
    insight_data = generate_insights(
        sleep_hours=avg_sleep,
        screen_time=avg_screen,
        mood=int(avg_mood),
        exercise=any(l.exercise for l in logs),
        stress_score=float(stress),
        recent_logs=logs
    )

    result = Phase4DashboardSummary(
        avg_sleep=avg_sleep,
        avg_mood=avg_mood,
        avg_screen_time=avg_screen,
        stress_score=stress,
        wellness_score=wellness_score,
        burnout_risk=burnout_risk,
        triggers=insight_data["insights"] # Use AI-generated insights as triggers
    )
    response_data = {"success": True, "data": result}
    return response_data

@router.get("/weekly-trends", response_model=StandardizedResponse[Phase4WeeklyTrends])
async def get_weekly_trends(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Returns weekly trends."""
        
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
    response_data = {"success": True, "data": result}
    return response_data

@router.post("/seed-demo-data")
async def seed_demo_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Seed the database with 7 days of mock data for the current user."""
    # Clear existing logs for these dates to avoid duplicates
    today = date.today()
    start_date = today - timedelta(days=7)
    
    db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id,
        BehaviorLog.date >= start_date
    ).delete()
    
    db.query(Prediction).filter(
        Prediction.user_id == current_user.user_id,
        Prediction.prediction_date >= start_date
    ).delete()
    
    new_logs = []
    new_preds = []
    
    for i in range(8):  # 7 days + today
        d = start_date + timedelta(days=i)
        
        # Mock wellness data
        sleep = random.uniform(5.5, 9.0)
        screen = random.uniform(3.0, 8.0)
        mood = random.randint(3, 9)
        ex = random.choice([True, False])
        
        log = BehaviorLog(
            user_id=current_user.user_id,
            date=d,
            sleep_hours=round(sleep, 1),
            screen_time=round(screen, 1),
            mood=mood,
            exercise=ex
        )
        new_logs.append(log)
        
        # Base stress calculation for prediction
        stress_score = max(0, min(100, 100 - (mood * 10) + (screen * 5) - (sleep * 2)))
        risk = "Low"
        if stress_score > 75: risk = "Critical"
        elif stress_score > 50: risk = "High"
        elif stress_score > 25: risk = "Moderate"
        
        pred = Prediction(
            user_id=current_user.user_id,
            stress_score=stress_score,
            risk_level=risk,
            prediction_date=d,
            insights=f"Stress score {stress_score:.0f} based on sleep {round(sleep,1)}h, screen {round(screen,1)}h, mood {mood}/10."
        )
        new_preds.append(pred)
    
    db.add_all(new_logs)
    db.add_all(new_preds)
    db.commit()
    
    # Clear cache
    if current_user.user_id in summary_cache: del summary_cache[current_user.user_id]
    if current_user.user_id in trends_cache: del trends_cache[current_user.user_id]
    
    return {"success": True, "message": "7 days of mock data generated successfully!"}

@router.delete("/clear-history")
async def clear_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Wipe all logs and predictions for the current user."""
    db.query(BehaviorLog).filter(BehaviorLog.user_id == current_user.user_id).delete()
    db.query(Prediction).filter(Prediction.user_id == current_user.user_id).delete()
    db.commit()
    
    # Clear cache
    if current_user.user_id in summary_cache: del summary_cache[current_user.user_id]
    if current_user.user_id in trends_cache: del trends_cache[current_user.user_id]
    
    return {"success": True, "message": "History cleared successfully!"}
