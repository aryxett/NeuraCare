import sys
from app.database import SessionLocal
from app.models.chat import ChatConversation, ConversationMessage

db = SessionLocal()
convs = db.query(ChatConversation).all()
for c in convs:
    print('Conv:', c.id, c.title)
    msgs = db.query(ConversationMessage).filter_by(conversation_id=c.id).all()
    for m in msgs:
        print('  Msg:', m.role, m.content)
