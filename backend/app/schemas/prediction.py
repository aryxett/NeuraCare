from pydantic import BaseModel
from datetime import date, datetime
from typing import Optional


from pydantic import BaseModel, Field

class PredictionRequest(BaseModel):
    sleep_hours: float = Field(..., ge=0, le=24, description="Hours of sleep (0-24)")
    screen_time: float = Field(..., ge=0, le=24, description="Screen time in hours (0-24)")
    mood: int = Field(..., ge=1, le=10, description="Mood scale (1-10)")
    exercise: bool = Field(default=False, description="Whether user exercised")


class PredictionResponse(BaseModel):
    prediction_id: int
    user_id: int
    stress_score: float
    risk_level: str
    insights: Optional[str] = None
    prediction_date: date
    created_at: datetime

    class Config:
        from_attributes = True


class PredictionList(BaseModel):
    predictions: list[PredictionResponse]
    total: int


class InsightResponse(BaseModel):
    insights: list[str]
    overall_risk: str
    summary: str
    recommendations: list[str]
