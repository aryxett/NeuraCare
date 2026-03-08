from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional
from datetime import date
from app.database import get_db
from app.models.user import User
from app.models.behavior_log import BehaviorLog
from app.schemas.behavior_log import BehaviorLogCreate, BehaviorLogResponse, BehaviorLogList
from app.schemas.common import StandardizedResponse
from app.services.auth_service import get_current_user

router = APIRouter(prefix="/api/behavior-logs", tags=["Behavior Logs"])


@router.post("/", response_model=StandardizedResponse[BehaviorLogResponse], status_code=status.HTTP_201_CREATED)
async def create_behavior_log(
    log_data: BehaviorLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Log daily behavioral data."""
    # Check if a log already exists for this date
    existing_log = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id,
        BehaviorLog.date == log_data.date
    ).first()

    if existing_log:
        # Update existing log
        existing_log.sleep_hours = log_data.sleep_hours
        existing_log.screen_time = log_data.screen_time
        existing_log.mood = log_data.mood
        existing_log.exercise = log_data.exercise
        db.commit()
        db.refresh(existing_log)
        return {"success": True, "data": existing_log}

    # Create new log
    new_log = BehaviorLog(
        user_id=current_user.user_id,
        date=log_data.date,
        sleep_hours=log_data.sleep_hours,
        screen_time=log_data.screen_time,
        mood=log_data.mood,
        exercise=log_data.exercise
    )
    db.add(new_log)
    db.commit()
    db.refresh(new_log)

    return {"success": True, "data": new_log}


@router.get("/", response_model=StandardizedResponse[BehaviorLogList])
async def get_behavior_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(30, ge=1, le=100),
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's behavior logs with optional date filtering."""
    query = db.query(BehaviorLog).filter(BehaviorLog.user_id == current_user.user_id)

    if start_date:
        query = query.filter(BehaviorLog.date >= start_date)
    if end_date:
        query = query.filter(BehaviorLog.date <= end_date)

    total = query.count()
    logs = query.order_by(BehaviorLog.date.desc()).offset(skip).limit(limit).all()

    return {"success": True, "data": BehaviorLogList(logs=logs, total=total)}


@router.post("/", response_model=StandardizedResponse[BehaviorLogResponse], status_code=status.HTTP_201_CREATED)
async def get_behavior_log(
    log_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific behavior log."""
    log = db.query(BehaviorLog).filter(
        BehaviorLog.log_id == log_id,
        BehaviorLog.user_id == current_user.user_id
    ).first()

    if not log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Behavior log not found"
        )

    return {"success": True, "data": log}


@router.delete("/{log_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_behavior_log(
    log_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a behavior log."""
    log = db.query(BehaviorLog).filter(
        BehaviorLog.log_id == log_id,
        BehaviorLog.user_id == current_user.user_id
    ).first()

    if not log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Behavior log not found"
        )

    db.delete(log)
    db.commit()
    return {"success": True, "data": {"message": "Log deleted"}}
