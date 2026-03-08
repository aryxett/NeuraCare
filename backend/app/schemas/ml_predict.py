from pydantic import BaseModel, Field

class PredictStressRequest(BaseModel):
    sleep_hours: float = Field(..., ge=0, le=24, description="Hours of sleep")
    screen_time: float = Field(..., ge=0, le=24, description="Screen time in hours")
    mood: int = Field(..., ge=1, le=10, description="Self-reported mood (1-10)")
    exercise: bool = Field(default=False, description="Did the user exercise?")

class PredictStressResponse(BaseModel):
    stress_score: int
    risk_level: str
