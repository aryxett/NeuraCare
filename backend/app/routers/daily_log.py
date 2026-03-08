from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from datetime import date, timedelta

from app.database import get_db
from app.models.user import User
from app.models.behavior_log import BehaviorLog
from app.services.auth_service import get_current_user
from app.schemas.daily_log import DailyLogSubmit, DailyLogResponse

router = APIRouter(prefix="/api", tags=["Phase 2 - Data Logging"])

@router.post("/submit-daily-log", response_model=DailyLogResponse, status_code=status.HTTP_201_CREATED)
async def submit_daily_log(
    data: DailyLogSubmit,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Submit daily wellness data. Validates JWT token and stores in BehaviorLogs.
    """
    # Security Check: Ensure the user_id in the payload matches the authenticated token
    if data.user_id != current_user.user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token user does not match payload user_id"
        )

    today = date.today()

    # Check for existing log today and upsert
    existing_log = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id,
        BehaviorLog.date == today
    ).first()

    if existing_log:
        existing_log.sleep_hours = data.sleep_hours
        existing_log.screen_time = data.screen_time
        existing_log.mood = data.mood
        existing_log.exercise = data.exercise
        db.commit()
        db.refresh(existing_log)
        log_id = existing_log.log_id
        message = "Daily log updated successfully"
    else:
        new_log = BehaviorLog(
            user_id=current_user.user_id,
            date=today,
            sleep_hours=data.sleep_hours,
            screen_time=data.screen_time,
            mood=data.mood,
            exercise=data.exercise
        )
        db.add(new_log)
        db.commit()
        db.refresh(new_log)
        log_id = new_log.log_id
        message = "Daily log created successfully"

    return DailyLogResponse(
        status="success",
        message=message,
        log_id=log_id
    )

@router.get("/user-history")
async def get_user_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Returns the last 30 days of behavior data for the authenticated user.
    """
    thirty_days_ago = date.today() - timedelta(days=30)
    
    logs = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == current_user.user_id,
        BehaviorLog.date >= thirty_days_ago
    ).order_by(BehaviorLog.date.desc()).all()

    return {
        "status": "success",
        "count": len(logs),
        "history": [
            {
                "id": log.log_id,
                "date": str(log.date),
                "sleep_hours": log.sleep_hours,
                "screen_time": log.screen_time,
                "mood": log.mood,
                "exercise": log.exercise
            }
            for log in logs
        ]
    }
