from fastapi import APIRouter
from app.schemas.ml_predict import PredictStressRequest, PredictStressResponse
from app.schemas.common import StandardizedResponse
from app.ml.predict import predict_stress, _load_model

router = APIRouter(prefix="", tags=["Phase 3 - Stress Prediction"])

# Pre-load the model if available
_load_model()

def get_risk_level(score: int) -> str:
    if score < 25:
        return "Low"
    elif score < 50:
        return "Moderate"
    elif score < 75:
        return "High"
    return "Critical"

@router.post("/predict-stress", response_model=StandardizedResponse[PredictStressResponse])
async def predict_stress_endpoint(data: PredictStressRequest):
    """
    Run behavioral data against the RandomForestClassifier ML model to get a stress score and risk level.
    """
    # Use the existing ML service prediction logic logic
    # predict_stress expects bool for exercise, returns float
    prediction_raw = predict_stress(
        sleep_hours=data.sleep_hours,
        screen_time=data.screen_time,
        mood=data.mood,
        exercise=data.exercise
    )
    
    # Cast safely
    score = int(round(prediction_raw))
    score = max(0, min(100, score))
    
    risk_level = get_risk_level(score)

    return {"success": True, "data": PredictStressResponse(
        stress_score=score,
        risk_level=risk_level
    )}
