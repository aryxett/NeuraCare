"""
Dashboard Pydantic Schemas
Request/Response models for the combined dashboard endpoints.
"""

from pydantic import BaseModel, Field


class DailyDataRequest(BaseModel):
    sleep_hours: float = Field(..., ge=0, le=24, description="Hours of sleep")
    screen_time: float = Field(..., ge=0, le=24, description="Screen time in hours")
    mood: int = Field(..., ge=1, le=10, description="Mood (1-10)")
    exercise: bool = Field(default=False, description="Did the user exercise?")


class DailyDataResponse(BaseModel):
    stress_score: float
    risk_level: str
    message: str


class DashboardSummaryResponse(BaseModel):
    stress_score: float
    wellness_score: int
    burnout_risk: float
    avg_sleep: float
    avg_mood: float
    avg_screen_time: float
    weekly_sleep: list[float]
    weekly_mood: list[int]
    weekly_screen_time: list[float]
    triggers: list[str] = Field(default_factory=list)


class WeeklyTrendsResponse(BaseModel):
    dates: list[str]
    sleep: list[float]
    mood: list[int]
    screen_time: list[float]
    exercise: list[bool]
    stress: list[float]
