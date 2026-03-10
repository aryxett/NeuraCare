from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.models.behavior_log import BehaviorLog
from app.schemas.prediction import InsightResponse
from app.services.auth_service import get_current_user
from app.services.insight_engine import generate_insights
from app.ml.predict import predict_stress
from app.schemas.common import StandardizedResponse

router = APIRouter(prefix="/api/insights", tags=["Insights"])

@router.get("/", response_model=StandardizedResponse[InsightResponse])
async def get_insights(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get AI-generated wellness insights based on recent behavior data."""
    # Get recent behavior logs
    recent_logs = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id
    ).order_by(BehaviorLog.date.desc()).limit(7).all()

    if not recent_logs:
        return {"success": True, "data": InsightResponse(
            insights=["No behavior data found. Start logging your daily habits to get personalized insights."],
            overall_risk="Unknown",
            summary="We need more data to provide meaningful insights. Please log your daily behavior.",
            recommendations=["Log your sleep, mood, screen time, and exercise daily for personalized wellness advice."]
        )}

    # Use the most recent log for prediction
    latest = recent_logs[0]
    stress_score = predict_stress(
        sleep_hours=latest.sleep_hours,
        screen_time=latest.screen_time,
        mood=latest.mood,
        exercise=latest.exercise
    )

    # Generate comprehensive insights
    insight_data = generate_insights(
        sleep_hours=latest.sleep_hours,
        screen_time=latest.screen_time,
        mood=latest.mood,
        exercise=latest.exercise,
        stress_score=stress_score,
        recent_logs=recent_logs
    )

    return {"success": True, "data": InsightResponse(**insight_data)}
