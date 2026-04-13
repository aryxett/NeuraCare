import json
from sqlalchemy.orm import Session
from app.database import engine, Base, SessionLocal
from app.models.user import User
from app.schemas.user import UserCreate
from app.services.auth_service import hash_password

db = SessionLocal()
try:
    user_data = UserCreate(name="Aryan", email="test@gmail.com", password="123")
    new_user = User(
        name=user_data.name,
        email=user_data.email,
        password_hash=hash_password(user_data.password)
    )
    db.add(new_user)
    db.commit()
    print("Success")
except Exception as e:
    import traceback
    traceback.print_exc()
finally:
    db.close()
