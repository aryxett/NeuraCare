from app.database import engine, Base
from sqlalchemy import text, inspect

# First ensure all tables exist
from app.models.chat import ChatConversation, ConversationMessage
from app.models.user import User
from app.models.mood_log import MoodLog

Base.metadata.create_all(bind=engine)
print("Tables synced via create_all")

# Now check if is_pinned column exists and add if not
try:
    insp = inspect(engine)
    columns = [c['name'] for c in insp.get_columns('chat_conversations')]
    if 'is_pinned' not in columns:
        with engine.connect() as conn:
            conn.execute(text("ALTER TABLE chat_conversations ADD COLUMN is_pinned BOOLEAN DEFAULT FALSE"))
            conn.commit()
        print("Added is_pinned column")
    else:
        print("is_pinned column already exists")
except Exception as e:
    print(f"Note: {e}")
    print("The column will be created with the table on next server start")
