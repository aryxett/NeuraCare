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
from app.services.auth_service import get_current_user
from app.services.pattern_discovery import discover_patterns
from app.services.mental_state_service import calculate_mental_state_radar
from app.schemas.patterns import LifePatternsResponse
from cachetools import TTLCache

# In-memory caches for performance optimization (10-second TTL for near-real-time updates)
summary_cache = TTLCache(maxsize=1000, ttl=10)
trends_cache = TTLCache(maxsize=1000, ttl=10)

# We use /api/analytics as a prefix to avoid colliding with the older /api/dashboard-summary from previous phases
router = APIRouter(prefix="/api/analytics", tags=["Phase 4 - Analytics"])

@router.get("/debug-db")
async def debug_db(db: Session = Depends(get_db)):
    """Temporary debug endpoint to check DB state on Render."""
    import traceback
    result = {"status": "ok", "checks": {}}
    try:
        # Check 1: Can we query BehaviorLog at all?
        from sqlalchemy import text
        cols = db.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name='behavior_logs'")).fetchall()
        result["checks"]["columns"] = [c[0] for c in cols]
    except Exception as e:
        result["checks"]["columns_error"] = f"{type(e).__name__}: {str(e)}"
    
    try:
        # Check 2: Can we query a BehaviorLog row?
        log = db.query(BehaviorLog).first()
        result["checks"]["query_ok"] = True
        result["checks"]["has_logs"] = log is not None
    except Exception as e:
        result["checks"]["query_error"] = f"{type(e).__name__}: {str(e)}"
        result["checks"]["query_traceback"] = traceback.format_exc()
    
    try:
        # Check 3: Check alembic_version
        from sqlalchemy import text
        ver = db.execute(text("SELECT version_num FROM alembic_version")).fetchall()
        result["checks"]["alembic_version"] = [v[0] for v in ver]
    except Exception as e:
        result["checks"]["alembic_error"] = f"{type(e).__name__}: {str(e)}"
    
    try:
        # Check 4: Try the full dashboard-summary logic
        test_log = db.query(BehaviorLog).order_by(BehaviorLog.date.desc()).first()
        if test_log:
            result["checks"]["latest_log_date"] = str(test_log.date)
            result["checks"]["latest_log_sleep"] = test_log.sleep_hours
            result["checks"]["latest_log_social_time"] = getattr(test_log, 'social_time', 'ATTR_MISSING')
    except Exception as e:
        result["checks"]["latest_log_error"] = f"{type(e).__name__}: {str(e)}"
        result["checks"]["latest_log_traceback"] = traceback.format_exc()
    
    return result

@router.get("/dashboard-summary", response_model=StandardizedResponse[Phase4DashboardSummary])
async def get_dashboard_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Returns Phase 4 Dashboard analytics based on the most recent log entry."""

    # Get the most recent log entry (the latest data the user submitted)
    latest_log = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id
    ).order_by(BehaviorLog.date.desc()).first()

    if not latest_log:
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

    # Use latest log's data directly (not 30-day averages)
    current_sleep = round(latest_log.sleep_hours, 1)
    current_mood = round(float(latest_log.mood), 1)
    current_screen = round(latest_log.screen_time, 1)

    # Get the latest prediction for this user (should match the latest log submission)
    latest_pred = db.query(Prediction).filter(
        Prediction.user_id == current_user.user_id
    ).order_by(Prediction.prediction_date.desc()).first()

    if latest_pred:
        stress = int(round(latest_pred.stress_score))
    else:
        # Fallback: calculate from the latest log's data
        from app.ml.predict import predict_stress
        stress = int(round(predict_stress(
            sleep_hours=latest_log.sleep_hours,
            screen_time=latest_log.screen_time,
            mood=latest_log.mood,
            exercise=latest_log.exercise,
        )))

    # Calculate Wellness Score (0-100)
    sleep_score = min(current_sleep / 8.0 * 100, 100)
    mood_score = current_mood * 10
    stress_inverse = max(100 - stress, 0)
    wellness_score = int((sleep_score * 0.4) + (mood_score * 0.4) + (stress_inverse * 0.2))

    # Calculate Burnout Risk (0-100)
    burnout_risk = int(stress * 0.5 + (100 - sleep_score) * 0.3 + (100 - mood_score) * 0.2)

    # Recent logs for insight generation (last 7 days)
    seven_days_ago = date.today() - timedelta(days=6)
    recent_logs = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id,
        BehaviorLog.date >= seven_days_ago
    ).order_by(BehaviorLog.date.desc()).all()

    # Use Insight Engine for deeper analysis
    insight_data = generate_insights(
        sleep_hours=current_sleep,
        screen_time=current_screen,
        mood=int(current_mood),
        exercise=latest_log.exercise,
        stress_score=float(stress),
        recent_logs=recent_logs
    )

    result = Phase4DashboardSummary(
        avg_sleep=current_sleep,
        avg_mood=current_mood,
        avg_screen_time=current_screen,
        stress_score=stress,
        wellness_score=wellness_score,
        burnout_risk=burnout_risk,
        triggers=insight_data["insights"]
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


@router.get("/life-patterns", response_model=StandardizedResponse[LifePatternsResponse])
async def get_life_patterns(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Phase 2: Life Pattern Discovery — detects hidden behavioral correlations."""
    result = discover_patterns(db, current_user.user_id)
    return {"success": True, "data": result}
    

@router.get("/mental-state-radar")
async def get_mental_state_radar(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Phase 4: Mental State Radar metrics based on last 7 days."""
    result = calculate_mental_state_radar(db, current_user.user_id)
    return {"success": True, "data": result}

from app.schemas.correlation import CorrelationResponse
from app.services.correlation_engine import compute_correlations

@router.get("/correlations", response_model=StandardizedResponse[CorrelationResponse])
async def get_correlations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Phase 3: Behavioral Correlation Engine — detects statistical links between behavior & mood/stress."""
    correlations_data = compute_correlations(db, current_user.user_id)
    return {"success": True, "data": CorrelationResponse(correlations=correlations_data)}

from pydantic import BaseModel

class UsageCategorySync(BaseModel):
    social_time: float
    entertainment_time: float
    productivity_time: float
    screen_time: float

@router.post("/sync-usage")
async def sync_usage(
    payload: UsageCategorySync,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Phase 5: Silent Behavioral Automation. Receives aggregated category app usage."""
    today = date.today()
    log = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id,
        BehaviorLog.date == today
    ).first()
    
    if log:
        log.social_time = payload.social_time
        log.entertainment_time = payload.entertainment_time
        log.productivity_time = payload.productivity_time
        # We also override total screen time automatically
        log.screen_time = payload.screen_time
    else:
        # Create tentative log (mood/sleep require manual input)
        log = BehaviorLog(
            user_id=current_user.user_id,
            date=today,
            sleep_hours=0.0,
            screen_time=payload.screen_time,
            mood=5, # neutral default until user logs
            exercise=False,
            social_time=payload.social_time,
            entertainment_time=payload.entertainment_time,
            productivity_time=payload.productivity_time
        )
        db.add(log)
    db.commit()
    
    # Invalidate cache
    if current_user.user_id in summary_cache: del summary_cache[current_user.user_id]
    if current_user.user_id in trends_cache: del trends_cache[current_user.user_id]
    
    return {"success": True, "message": "Usage stats synced securely"}

from app.services.behavioral_intelligence import compute_full_intelligence

@router.get("/behavioral-intelligence")
async def get_behavioral_intelligence(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Advanced Behavioral Intelligence — returns risk scores, enhanced correlations,
    emerging patterns, drift alerts, interventions, and weekly summary."""
    result = compute_full_intelligence(db, current_user.user_id)
    return {"success": True, "data": result}
