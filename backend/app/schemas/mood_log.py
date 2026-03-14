from pydantic import BaseModel, root_validator
from enum import Enum

class MoodOption(str, Enum):
    calm = "calm"
    happy = "happy"
    motivated = "motivated"
    neutral = "neutral"
    stressed = "stressed"
    tired = "tired"

class MoodCheckInRequest(BaseModel):
    mood: MoodOption

class MoodCheckInStatusResponse(BaseModel):
    has_checked_in_today: bool
    today_mood: str | None = None
