import asyncio
from app.database import SessionLocal
from app.services.mental_state_service import calculate_mental_state_radar

def test_radar():
    db = SessionLocal()
    try:
        # Assuming user_id 1 is the main test user
        result = calculate_mental_state_radar(db, 1)
        print("RADAR RESULT:", result)
    finally:
        db.close()

if __name__ == '__main__':
    test_radar()
