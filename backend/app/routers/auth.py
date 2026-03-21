from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse, Token, ProfileUpdate
from app.schemas.common import StandardizedResponse
from app.services.auth_service import (
    hash_password,
    verify_password,
    create_access_token,
    get_current_user,
)
import json

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


@router.post("/register", response_model=StandardizedResponse[UserResponse], status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Register a new user account."""
    # Check if email already exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email already exists"
        )

    # Create new user
    new_user = User(
        name=user_data.name,
        email=user_data.email,
        password_hash=hash_password(user_data.password)
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {"success": True, "data": new_user}


@router.post("/login", response_model=StandardizedResponse[Token])
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Authenticate and get a JWT token."""
    user = db.query(User).filter(User.email == form_data.username).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    is_valid, needs_rehash = verify_password(form_data.password, user.password_hash)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Automatically upgrade hash to fast-login version if it's on the old slow version
    if needs_rehash:
        user.password_hash = hash_password(form_data.password)
        db.commit()

    access_token = create_access_token(data={"sub": str(user.user_id)})
    return {"success": True, "data": {"access_token": access_token, "token_type": "bearer"}}


@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    """Get the currently authenticated user's profile."""
    return {"success": True, "data": UserResponse.from_user(current_user).model_dump()}


@router.patch("/profile")
async def update_profile(
    update_data: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update user profile. Merges profile_metadata with existing data."""
    # Update name if provided
    if update_data.name is not None:
        current_user.name = update_data.name

    # Merge profile_metadata (don't overwrite — merge keys)
    if update_data.profile_metadata is not None:
        existing = {}
        if current_user.profile_metadata:
            try:
                existing = json.loads(current_user.profile_metadata)
            except (json.JSONDecodeError, TypeError):
                existing = {}
        existing.update(update_data.profile_metadata)
        current_user.profile_metadata = json.dumps(existing)

    db.commit()
    db.refresh(current_user)

    return {"success": True, "data": UserResponse.from_user(current_user).model_dump()}
