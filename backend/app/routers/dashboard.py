"""
Dashboard API Router
Combined endpoints for mobile app real-time data sync.
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func as sqlfunc
from datetime import date, timedelta

from app.database import get_db
from app.models.user import User
from app.models.behavior_log import BehaviorLog
from app.models.prediction import Prediction
from app.schemas.dashboard import (
    DailyDataRequest,
    DailyDataResponse,
    DashboardSummaryResponse,
    WeeklyTrendsResponse,
)
from app.schemas.common import StandardizedResponse
from app.services.auth_service import get_current_user
from app.services.insight_engine import generate_insights, get_risk_level
from app.routers.analytics import summary_cache as analytics_summary_cache, trends_cache as analytics_trends_cache
from app.services.behavior_analysis import (
    calculate_wellness_score,
    predict_burnout,
    detect_triggers,
    update_behavioral_profile
)
from app.ml.predict import predict_stress

router = APIRouter(prefix="/api", tags=["Dashboard"])


@router.post("/submit-daily-data", response_model=StandardizedResponse[DailyDataResponse], status_code=status.HTTP_201_CREATED)
async def submit_daily_data(
    data: DailyDataRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Combined endpoint: saves behavior log + runs AI prediction + returns result.
    This is the single endpoint the mobile app calls after the user fills the daily log form.
    """
    today = date.today()

    # ── 1. Upsert behavior log ──
    existing = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id,
        BehaviorLog.date == today,
    ).first()

    if existing:
        existing.sleep_hours = data.sleep_hours
        existing.screen_time = data.screen_time
        existing.mood = data.mood
        existing.exercise = data.exercise
        db.commit()
        db.refresh(existing)
    else:
        log = BehaviorLog(
            user_id=current_user.user_id,
            date=today,
            sleep_hours=data.sleep_hours,
            screen_time=data.screen_time,
            mood=data.mood,
            exercise=data.exercise,
        )
        db.add(log)
        db.commit()

    # ── 2. Run stress prediction ──
    stress_score = predict_stress(
        sleep_hours=data.sleep_hours,
        screen_time=data.screen_time,
        mood=data.mood,
        exercise=data.exercise,
    )
    risk_level = get_risk_level(stress_score)

    # Recent logs for insight generation
    recent_logs = (
        db.query(BehaviorLog)
        .filter(BehaviorLog.user_id == current_user.user_id)
        .order_by(BehaviorLog.date.desc())
        .limit(7)
        .all()
    )

    insight_data = generate_insights(
        sleep_hours=data.sleep_hours,
        screen_time=data.screen_time,
        mood=data.mood,
        exercise=data.exercise,
        stress_score=stress_score,
        recent_logs=recent_logs,
        use_llm=False, # Bypass heavy Azure OpenAI call to prevent 8-second UI load delays
    )

    message = insight_data["summary"]

    # ── 3. Store prediction ──
    prediction = Prediction(
        user_id=current_user.user_id,
        stress_score=round(stress_score, 2),
        risk_level=risk_level,
        insights=message,
        prediction_date=today,
    )
    db.add(prediction)
    db.commit()

    # Clear analytics caches so the user sees updated insights immediately
    if current_user.user_id in analytics_summary_cache: del analytics_summary_cache[current_user.user_id]
    if current_user.user_id in analytics_trends_cache: del analytics_trends_cache[current_user.user_id]

    return {"success": True, "data": DailyDataResponse(
        stress_score=round(stress_score, 2),
        risk_level=risk_level,
        message=message,
    )}


@router.get("/dashboard-summary", response_model=StandardizedResponse[DashboardSummaryResponse])
async def get_dashboard_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Returns aggregated KPI data for the mobile dashboard.
    Calculates averages over the last 7 days and returns weekly sleep array.
    """
    seven_days_ago = date.today() - timedelta(days=7)

    logs = (
        db.query(BehaviorLog)
        .filter(
            BehaviorLog.user_id == current_user.user_id,
            BehaviorLog.date >= seven_days_ago,
        )
        .order_by(BehaviorLog.date.asc())
        .all()
    )

    if not logs:
        return {"success": True, "data": DashboardSummaryResponse(
            stress_score=0,
            wellness_score=0,
            burnout_risk=0.0,
            avg_sleep=0,
            avg_mood=0,
            avg_screen_time=0,
            weekly_sleep=[],
            weekly_mood=[],
            weekly_screen_time=[],
            triggers=[]
        )}

    avg_sleep = sum(l.sleep_hours for l in logs) / len(logs)
    avg_mood = sum(l.mood for l in logs) / len(logs)
    avg_screen = sum(l.screen_time for l in logs) / len(logs)

    weekly_sleep = [round(l.sleep_hours, 1) for l in logs]
    weekly_mood = [l.mood for l in logs]
    weekly_screen = [round(l.screen_time, 1) for l in logs]

    # Latest stress prediction
    preds = db.query(Prediction).filter(
        Prediction.user_id == current_user.user_id,
        Prediction.prediction_date >= seven_days_ago
    ).order_by(Prediction.prediction_date.desc()).all()
    
    latest_pred = preds[0] if preds else None
    stress = latest_pred.stress_score if latest_pred else 0

    # ── New Therapy Assistant Metrics ──
    wellness_score = calculate_wellness_score(
        sleep=avg_sleep, 
        screen=avg_screen, 
        mood=int(avg_mood), 
        exercise=any(l.exercise for l in logs)
    )
    
    burnout_risk = predict_burnout(logs)
    triggers = detect_triggers(logs, preds)
    
    # Background update profile
    update_behavioral_profile(db, current_user.user_id)

    return {"success": True, "data": DashboardSummaryResponse(
        stress_score=round(stress, 2),
        wellness_score=wellness_score,
        burnout_risk=burnout_risk,
        avg_sleep=round(avg_sleep, 1),
        avg_mood=round(avg_mood, 1),
        avg_screen_time=round(avg_screen, 1),
        weekly_sleep=weekly_sleep,
        weekly_mood=weekly_mood,
        weekly_screen_time=weekly_screen,
        triggers=triggers
    )}


@router.get("/weekly-trends", response_model=StandardizedResponse[WeeklyTrendsResponse])
async def get_weekly_trends(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Returns 7-day trend arrays for all tracked metrics + stress predictions.
    """
    seven_days_ago = date.today() - timedelta(days=7)

    logs = (
        db.query(BehaviorLog)
        .filter(
            BehaviorLog.user_id == current_user.user_id,
            BehaviorLog.date >= seven_days_ago,
        )
        .order_by(BehaviorLog.date.asc())
        .all()
    )

    preds = (
        db.query(Prediction)
        .filter(
            Prediction.user_id == current_user.user_id,
            Prediction.prediction_date >= seven_days_ago,
        )
        .order_by(Prediction.prediction_date.asc())
        .all()
    )

    return {"success": True, "data": WeeklyTrendsResponse(
        dates=[str(l.date) for l in logs],
        sleep=[round(l.sleep_hours, 1) for l in logs],
        mood=[l.mood for l in logs],
        screen_time=[round(l.screen_time, 1) for l in logs],
        exercise=[l.exercise for l in logs],
        stress=[round(p.stress_score, 1) for p in preds],
    )}
