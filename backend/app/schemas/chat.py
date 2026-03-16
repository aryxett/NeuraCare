from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class ConversationBase(BaseModel):
    title: str

class ConversationCreateRequest(ConversationBase):
    pass

class ConversationRenameRequest(BaseModel):
    title: str

class ConversationPinRequest(BaseModel):
    is_pinned: bool

class ConversationResponse(ConversationBase):
    id: str
    user_id: int
    is_pinned: bool = False
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class ConversationListResponse(BaseModel):
    conversations: List[ConversationResponse]

class MessageBase(BaseModel):
    content: str
    role: str

class SendMessageRequest(BaseModel):
    content: str

class MessageResponse(MessageBase):
    id: str
    created_at: datetime

    class Config:
        orm_mode = True

class ConversationMessagesResponse(BaseModel):
    conversation_id: str
    messages: List[MessageResponse]

class SendMessageResponse(BaseModel):
    user_message: MessageResponse
    ai_message: MessageResponse
    updated_title: Optional[str] = None
