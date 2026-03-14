from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.services.auth_service import get_current_user
from app.models.user import User
from app.services import fitbit_service

router = APIRouter(prefix="/api/fitbit", tags=["Fitbit Integration"])

@router.get("/login")
async def fitbit_login(current_user: User = Depends(get_current_user)):
    """
    Redirects the user to the Fitbit OAuth consent screen.
    We pass the JWT token in state so we know who authorized it in the callback.
    """
    auth_url = fitbit_service.generate_auth_url()
    # In a real production app, we would use a more secure state mechanism (e.g. redis cache session ID)
    # but for simplicity we append the user_id as state.
    state = str(current_user.user_id)
    return {"success": True, "data": {"auth_url": f"{auth_url}&state={state}"}}


from fastapi.responses import HTMLResponse

@router.get("/callback")
async def fitbit_callback(code: str = Query(None), state: str = Query(None), db: Session = Depends(get_db)):
    """
    Fitbit redirects here after user grants permission.
    We return a simple HTML page telling them to copy the URL
    so the mobile app can exchange the code.
    """
    if not code or not state:
        raise HTTPException(status_code=400, detail="Missing authorization code or state.")
        
    html_content = """
    <html>
        <head>
            <title>Fitbit Connected</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; text-align: center; padding: 40px 20px; background-color: #0f172a; color: white; }
                .container { max-width: 500px; margin: 0 auto; background-color: #1e293b; padding: 30px; border-radius: 16px; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1); }
                h2 { color: #10B981; margin-top: 0; }
                p { line-height: 1.6; color: #cbd5e1; }
                .copy-btn { margin-top: 20px; padding: 12px 24px; background-color: #3b82f6; color: white; border: none; border-radius: 8px; font-weight: bold; cursor: pointer; }
            </style>
        </head>
        <body>
            <div class="container">
                <h2>✅ Authorization Successful!</h2>
                <p>Cognify AI has been authorized.</p>
                <p><strong>Please copy the full URL from your browser's address bar</strong> and paste it into the Cognify AI app to finish connecting.</p>
            </div>
        </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@router.post("/exchange-code")
async def exchange_fitbit_code(
    code: str = Query(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Mobile app sends the authorization code here after user
    copies it from the browser redirect URL.
    """
    try:
        await fitbit_service.exchange_code_for_token(code, db, current_user.user_id)
        return {"success": True, "data": {"status": "success", "message": "Fitbit connected successfully!"}}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to exchange code: {str(e)}")


@router.get("/daily-data")
async def get_daily_fitbit_data(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Mobile app calls this when the Daily Log screen opens.
    Fetches the latest sleep and activity and formats it for our prediction pipeline.
    """
    user_id = current_user.user_id
    
    # 1. Fetch sleep
    sleep_result = await fitbit_service.fetch_sleep_data(db, user_id)
    if "error" in sleep_result and sleep_result["error"] == "not_connected":
        return {"success": True, "data": {"connected": False}}
        
    # 2. Fetch Activity
    activity_result = await fitbit_service.fetch_activity_data(db, user_id)
    
    return {"success": True, "data": {
        "connected": True,
        "sleep_hours": sleep_result.get("sleep_hours", 0.0),
        "exercise": activity_result.get("exercise", False)
    }}
