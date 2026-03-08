from pydantic import BaseModel
from typing import List

class Phase4DashboardSummary(BaseModel):
    avg_sleep: float
    avg_mood: float
    avg_screen_time: float
    stress_score: int
    wellness_score: int
    burnout_risk: int
    triggers: List[str]

class Phase4WeeklyTrends(BaseModel):
    sleep: list[float]
    screen_time: list[float]
    mood: list[float]
