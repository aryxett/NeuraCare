from pydantic import BaseModel, Field

class DailyLogSubmit(BaseModel):
    user_id: int = Field(..., description="User ID submitting the log")
    sleep_hours: float = Field(..., ge=0, le=24, description="Hours of sleep")
    screen_time: float = Field(..., ge=0, le=24, description="Screen time in hours")
    mood: int = Field(..., ge=1, le=10, description="Mood (1-10)")
    exercise: bool = Field(default=False, description="Did the user exercise?")

class DailyLogResponse(BaseModel):
    status: str
    message: str
    log_id: int

class UserHistoryResponse(BaseModel):
    history: list[dict]
