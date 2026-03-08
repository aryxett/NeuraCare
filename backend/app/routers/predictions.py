from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from datetime import date
from app.database import get_db
from app.models.user import User
from app.models.prediction import Prediction
from app.models.behavior_log import BehaviorLog
from app.schemas.prediction import PredictionRequest, PredictionResponse, PredictionList
from app.schemas.common import StandardizedResponse
from app.services.auth_service import get_current_user
from app.services.insight_engine import generate_insights, get_risk_level
from app.ml.predict import predict_stress

router = APIRouter(prefix="/api/predictions", tags=["Predictions"])


@router.post("/predict", response_model=StandardizedResponse[PredictionResponse])
async def create_prediction(
    data: PredictionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Run stress prediction on provided behavioral data."""
    # Get stress prediction from ML model
    stress_score = predict_stress(
        sleep_hours=data.sleep_hours,
        screen_time=data.screen_time,
        mood=data.mood,
        exercise=data.exercise
    )

    risk_level = get_risk_level(stress_score)

    # Get recent logs for trend analysis
    recent_logs = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id
    ).order_by(BehaviorLog.date.desc()).limit(7).all()

    # Generate insights
    insight_data = generate_insights(
        sleep_hours=data.sleep_hours,
        screen_time=data.screen_time,
        mood=data.mood,
        exercise=data.exercise,
        stress_score=stress_score,
        recent_logs=recent_logs
    )

    insights_text = insight_data["summary"] + "\n\n" + "\n".join(insight_data["insights"])

    # Save prediction
    prediction = Prediction(
        user_id=current_user.user_id,
        stress_score=round(stress_score, 2),
        risk_level=risk_level,
        insights=insights_text,
        prediction_date=date.today()
    )
    db.add(prediction)
    db.commit()
    db.refresh(prediction)

    return {"success": True, "data": prediction}


@router.get("/", response_model=StandardizedResponse[PredictionList])
async def get_predictions(
    skip: int = Query(0, ge=0),
    limit: int = Query(30, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's prediction history."""
    query = db.query(Prediction).filter(Prediction.user_id == current_user.user_id)
    total = query.count()
    predictions = query.order_by(Prediction.prediction_date.desc()).offset(skip).limit(limit).all()

    return {"success": True, "data": PredictionList(predictions=predictions, total=total)}
