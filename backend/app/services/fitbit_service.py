from fastapi import HTTPException
import httpx
from datetime import datetime, timedelta
from app.config import get_settings
from app.models.fitbit import FitbitToken
from sqlalchemy.orm import Session
import base64
from urllib.parse import urlencode

settings = get_settings()

FITBIT_OAUTH_URL = "https://www.fitbit.com/oauth2/authorize"
FITBIT_TOKEN_URL = "https://api.fitbit.com/oauth2/token"
FITBIT_API_BASE = "https://api.fitbit.com/1.2/user/-"
FITBIT_API_V1 = "https://api.fitbit.com/1/user/-"

def generate_auth_url() -> str:
    """Generate the Fitbit OAuth2 authorization URL."""
    scope = "sleep+activity+profile"
    return f"{FITBIT_OAUTH_URL}?response_type=code&client_id={settings.FITBIT_CLIENT_ID}&redirect_uri={settings.FITBIT_REDIRECT_URI}&scope={scope}"

async def exchange_code_for_token(code: str, db: Session, user_id: int):
    """Exchanges an authorization code for an access token and stores it."""
    # Clean the code - remove any URL fragments like #_=_
    clean_code = code.split('#')[0].strip()
    
    auth_header = base64.b64encode(f"{settings.FITBIT_CLIENT_ID}:{settings.FITBIT_CLIENT_SECRET}".encode()).decode()
    
    headers = {
        "Authorization": f"Basic {auth_header}",
        "Content-Type": "application/x-www-form-urlencoded"
    }
    
    data = {
        "client_id": settings.FITBIT_CLIENT_ID,
        "grant_type": "authorization_code",
        "redirect_uri": settings.FITBIT_REDIRECT_URI,
        "code": clean_code
    }

    async with httpx.AsyncClient() as client:
        response = await client.post(FITBIT_TOKEN_URL, headers=headers, data=data)
        
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail=f"Fitbit Token Error: {response.text}")
            
        token_data = response.json()
        
        # Calculate expiry
        expires_in = token_data.get("expires_in", 28800)
        expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
        
        # Check if token exists for user
        token_record = db.query(FitbitToken).filter(FitbitToken.user_id == user_id).first()
        
        if token_record:
            token_record.access_token = token_data["access_token"]
            token_record.refresh_token = token_data["refresh_token"]
            token_record.expires_at = expires_at
        else:
            token_record = FitbitToken(
                user_id=user_id,
                access_token=token_data["access_token"],
                refresh_token=token_data["refresh_token"],
                expires_at=expires_at
            )
            db.add(token_record)
            
        db.commit()
        return token_record

async def refresh_access_token(db: Session, token_record: FitbitToken):
    """Refreshes the Fitbit access token using the refresh token."""
    auth_header = base64.b64encode(f"{settings.FITBIT_CLIENT_ID}:{settings.FITBIT_CLIENT_SECRET}".encode()).decode()
    
    headers = {
        "Authorization": f"Basic {auth_header}",
        "Content-Type": "application/x-www-form-urlencoded"
    }
    
    data = {
        "grant_type": "refresh_token",
        "refresh_token": token_record.refresh_token
    }

    async with httpx.AsyncClient() as client:
        response = await client.post(FITBIT_TOKEN_URL, headers=headers, data=data)
        
        if response.status_code != 200:
            # If refresh fails, user might need to re-authenticate
            raise HTTPException(status_code=401, detail="Fitbit session expired. Please reconnect.")
            
        token_data = response.json()
        expires_in = token_data.get("expires_in", 28800)
        
        token_record.access_token = token_data["access_token"]
        token_record.refresh_token = token_data["refresh_token"]
        token_record.expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
        
        db.commit()
        return token_record

async def _get_valid_token(db: Session, user_id: int):
    """Retrieves a valid token from DB, refreshing if necessary."""
    token_record = db.query(FitbitToken).filter(FitbitToken.user_id == user_id).first()
    if not token_record:
        return None
        
    # Check if expired (or expiring in next 5 mins)
    if datetime.utcnow() > (token_record.expires_at - timedelta(minutes=5)):
        token_record = await refresh_access_token(db, token_record)
        
    return token_record.access_token

async def fetch_sleep_data(db: Session, user_id: int, date: str = "today") -> dict:
    """Fetch sleep data for a given date."""
    access_token = await _get_valid_token(db, user_id)
    if not access_token:
        return {"error": "not_connected"}
        
    headers = {"Authorization": f"Bearer {access_token}"}
    
    async with httpx.AsyncClient() as client:
        # e.g. GET https://api.fitbit.com/1.2/user/-/sleep/date/today.json
        resp = await client.get(f"{FITBIT_API_BASE}/sleep/date/{date}.json", headers=headers)
        if resp.status_code != 200:
            return {"error": resp.text}
        
        data = resp.json()
        summary = data.get("summary", {})
        
        # minutesAsleep or totalMinutesAsleep
        total_minutes = summary.get("totalMinutesAsleep", 0)
        hours = round(total_minutes / 60.0, 1)
        
        return {
            "connected": True,
            "sleep_hours": hours if hours > 0 else None,
            "raw": data
        }

async def fetch_activity_data(db: Session, user_id: int, date: str = "today") -> dict:
    """Fetch activity data to determine exercise status."""
    access_token = await _get_valid_token(db, user_id)
    if not access_token:
        return {"error": "not_connected"}
        
    headers = {"Authorization": f"Bearer {access_token}"}
    
    async with httpx.AsyncClient() as client:
        # e.g. GET https://api.fitbit.com/1/user/-/activities/date/today.json
        resp = await client.get(f"{FITBIT_API_V1}/activities/date/{date}.json", headers=headers)
        if resp.status_code != 200:
            return {"error": resp.text}
            
        data = resp.json()
        summary = data.get("summary", {})
        
        active_mins = summary.get("fairlyActiveMinutes", 0) + summary.get("veryActiveMinutes", 0)
        steps = summary.get("steps", 0)
        
        # We define 'exercise' as True if there are >15 active mins or >4000 steps loosely
        is_exercised = active_mins > 15 or steps > 4000
        
        return {
            "connected": True,
            "exercise": is_exercised,
            "steps": steps,
            "active_minutes": active_mins,
            "raw": data
        }
