from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional

class JournalCreate(BaseModel):
    content: str = Field(..., description="The journal reflection text")

class JournalResponse(BaseModel):
    id: int
    content: str
    sentiment: float
    emotion: str
    created_at: datetime

    class Config:
        from_attributes = True

class ChatRequest(BaseModel):
    message: str = Field(..., description="User message to the AI therapy assistant")

class ChatResponse(BaseModel):
    id: int
    message: str
    role: str
    timestamp: datetime

    class Config:
        from_attributes = True

class TherapyChatResponse(BaseModel):
    user_message: ChatResponse
    ai_response: ChatResponse
