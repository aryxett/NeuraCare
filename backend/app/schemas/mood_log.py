from pydantic import BaseModel, root_validator
from enum import Enum

class MoodOption(str, Enum):
    calm = "calm"
    stressed = "stressed"
    tired = "tired"
    motivated = "motivated"

class MoodCheckInRequest(BaseModel):
    mood: MoodOption

class MoodCheckInStatusResponse(BaseModel):
    has_checked_in_today: bool
    today_mood: str | None = None
