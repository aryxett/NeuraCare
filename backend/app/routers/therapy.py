from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models.user import User
from app.models.journal import JournalEntry
from app.models.therapy import ChatMessage
from app.schemas.therapy import JournalCreate, JournalResponse, ChatRequest, TherapyChatResponse, ChatResponse
from app.schemas.common import StandardizedResponse
from app.services.auth_service import get_current_user
from app.services.therapy_llm_service import generate_therapy_response

router = APIRouter(prefix="/api/therapy", tags=["Therapy"])

@router.post("/journal", response_model=StandardizedResponse[JournalResponse], status_code=status.HTTP_201_CREATED)
async def create_journal_entry(
    data: JournalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    analysis = analyze_sentiment(data.content)
    
    entry = JournalEntry(
        user_id=current_user.user_id,
        content=data.content,
        sentiment=analysis["sentiment"],
        emotion=analysis["emotion"]
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return {"success": True, "data": entry}

@router.get("/journal", response_model=StandardizedResponse[List[JournalResponse]])
async def get_journal_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    entries = db.query(JournalEntry).filter(JournalEntry.user_id == current_user.user_id).order_by(JournalEntry.created_at.desc()).all()
    return {"success": True, "data": entries}

@router.post("/chat", response_model=StandardizedResponse[TherapyChatResponse])
async def send_chat_message(
    data: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 1. Fetch last 5 messages for context
    past_messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.user_id == current_user.user_id)
        .order_by(ChatMessage.timestamp.desc())
        .limit(5)
        .all()
    )
    # Reverse to get chronological order for LLM
    context = [{"role": m.role, "content": m.message} for m in reversed(past_messages)]
    
    # 2. Save user message
    user_msg = ChatMessage(user_id=current_user.user_id, message=data.message, role="user")
    db.add(user_msg)
    db.commit()
    db.refresh(user_msg)
    
    # 3. Get AI response from OpenAI LLM
    ai_text = generate_therapy_response(data.message, history=context)
    
    # 4. Save AI (assistant) message
    ai_msg = ChatMessage(user_id=current_user.user_id, message=ai_text, role="assistant")
    db.add(ai_msg)
    db.commit()
    db.refresh(ai_msg)
    
    return {"success": True, "data": TherapyChatResponse(
        user_message=user_msg,
        ai_response=ai_msg
    )}

@router.get("/chat", response_model=StandardizedResponse[List[ChatResponse]])
async def get_chat_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    history = db.query(ChatMessage).filter(ChatMessage.user_id == current_user.user_id).order_by(ChatMessage.timestamp.asc()).all()
    return {"success": True, "data": history}
