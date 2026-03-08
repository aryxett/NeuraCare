from pydantic import BaseModel, Field
from datetime import date, datetime
from typing import Optional


class BehaviorLogCreate(BaseModel):
    date: date
    sleep_hours: float = Field(..., ge=0, le=24, description="Hours of sleep (0-24)")
    screen_time: float = Field(..., ge=0, le=24, description="Screen time in hours (0-24)")
    mood: int = Field(..., ge=1, le=10, description="Mood scale (1=worst, 10=best)")
    exercise: bool = Field(default=False, description="Whether user exercised")


class BehaviorLogResponse(BaseModel):
    log_id: int
    user_id: int
    date: date
    sleep_hours: float
    screen_time: float
    mood: int
    exercise: bool
    created_at: datetime

    class Config:
        from_attributes = True


class BehaviorLogList(BaseModel):
    logs: list[BehaviorLogResponse]
    total: int
