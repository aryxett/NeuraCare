from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional, Dict, Any
import json


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    user_id: int
    name: str
    email: str
    created_at: datetime
    profile_metadata: Optional[Dict[str, Any]] = None

    class Config:
        from_attributes = True

    @classmethod
    def from_user(cls, user):
        """Parse profile_metadata from JSON string to dict."""
        meta = {}
        if user.profile_metadata:
            try:
                meta = json.loads(user.profile_metadata)
            except (json.JSONDecodeError, TypeError):
                meta = {}
        return cls(
            user_id=user.user_id,
            name=user.name,
            email=user.email,
            created_at=user.created_at,
            profile_metadata=meta,
        )


class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    profile_metadata: Optional[Dict[str, Any]] = None


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: Optional[int] = None
