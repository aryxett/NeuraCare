from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from typing import List
from uuid import uuid4

from app.database import get_db
from app.models.user import User
from app.models.chat import ChatConversation, ConversationMessage
from app.schemas.chat import (
    ConversationResponse,
    ConversationListResponse,
    ConversationCreateRequest,
    ConversationRenameRequest,
    ConversationPinRequest,
    ConversationMessagesResponse,
    SendMessageRequest,
    SendMessageResponse,
    MessageResponse
)
from app.schemas.common import StandardizedResponse
from app.services.auth_service import get_current_user
from app.services.therapy_llm_service import generate_therapy_response, generate_chat_title
from app.models.mood_log import MoodLog
from sqlalchemy import desc

router = APIRouter(prefix="/api/chat", tags=["Chat Management"])

@router.get("/sync-db")
async def sync_db(db: Session = Depends(get_db)):
    """Manually trigger database migration to add missing columns."""
    from sqlalchemy import text
    try:
        # This is safe for PostgreSQL 9.6+
        db.execute(text("ALTER TABLE chat_conversations ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE"))
        db.commit()
        return {"success": True, "message": "Database synced: is_pinned column added or verified."}
    except Exception as e:
        return {"success": False, "message": f"Sync skipped or failed: {str(e)}"}

@router.get("/conversations", response_model=StandardizedResponse[ConversationListResponse])
async def get_conversations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all conversations for the current user. Pinned first, then by most recent."""
    conversations = (
        db.query(ChatConversation)
        .filter(
            ChatConversation.user_id == current_user.user_id,
            ChatConversation.title != "New Conversation"
        )
        .order_by(ChatConversation.is_pinned.desc(), ChatConversation.updated_at.desc())
        .all()
    )
    return {"success": True, "data": {"conversations": conversations}}


@router.post("/conversations", response_model=StandardizedResponse[ConversationResponse], status_code=status.HTTP_201_CREATED)
async def create_conversation(
    data: ConversationCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new empty conversation and inject the initial greeting."""
    new_conv = ChatConversation(
        user_id=current_user.user_id,
        title=data.title or "New Conversation"
    )
    db.add(new_conv)
    db.commit()
    db.refresh(new_conv)

    # Initial Context-Aware Greeting
    greeting_msg = ConversationMessage(
        conversation_id=new_conv.id,
        role="assistant",
        content="Hello, how are you feeling today?"
    )
    db.add(greeting_msg)
    db.commit()

    return {"success": True, "data": new_conv}


@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a conversation and all its messages."""
    conversation = db.query(ChatConversation).filter(
        ChatConversation.id == conversation_id,
        ChatConversation.user_id == current_user.user_id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
        
    db.delete(conversation)
    db.commit()
    return {"success": True, "message": "Conversation deleted successfully"}


@router.patch("/conversations/{conversation_id}/rename")
async def rename_conversation(
    conversation_id: str,
    data: ConversationRenameRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Rename a conversation."""
    conversation = db.query(ChatConversation).filter(
        ChatConversation.id == conversation_id,
        ChatConversation.user_id == current_user.user_id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    conversation.title = data.title.strip() or "Therapy Session"
    db.commit()
    db.refresh(conversation)
    return {"success": True, "data": {"id": conversation.id, "title": conversation.title}}


@router.patch("/conversations/{conversation_id}/pin")
async def pin_conversation(
    conversation_id: str,
    data: ConversationPinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Pin or unpin a conversation."""
    conversation = db.query(ChatConversation).filter(
        ChatConversation.id == conversation_id,
        ChatConversation.user_id == current_user.user_id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    conversation.is_pinned = data.is_pinned
    db.commit()
    db.refresh(conversation)
    return {"success": True, "data": {"id": conversation.id, "is_pinned": conversation.is_pinned}}


@router.get("/conversations/{conversation_id}/messages", response_model=StandardizedResponse[ConversationMessagesResponse])
async def get_messages(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all messages for a specific conversation."""
    conversation = db.query(ChatConversation).filter(
        ChatConversation.id == conversation_id,
        ChatConversation.user_id == current_user.user_id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
        
    messages = (
        db.query(ConversationMessage)
        .filter(ConversationMessage.conversation_id == conversation_id)
        .order_by(ConversationMessage.created_at.asc())
        .all()
    )
    
    return {"success": True, "data": {
        "conversation_id": conversation_id,
        "messages": messages
    }}


@router.post("/conversations/{conversation_id}/messages", response_model=StandardizedResponse[SendMessageResponse])
async def send_message(
    conversation_id: str,
    data: SendMessageRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Send a message to a conversation, get AI response, and save both."""
    # 1. Verify ownership and get conversation
    conversation = db.query(ChatConversation).filter(
        ChatConversation.id == conversation_id,
        ChatConversation.user_id == current_user.user_id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
        
    # 2. Save user message
    user_msg = ConversationMessage(
        conversation_id=conversation_id,
        role="user",
        content=data.content
    )
    db.add(user_msg)
    db.commit()
    
    # 3. Fetch recent history for context (last 10 messages)
    history_msgs = (
        db.query(ConversationMessage)
        .filter(ConversationMessage.conversation_id == conversation_id)
        .order_by(ConversationMessage.created_at.desc())
        .limit(10)
        .all()
    )
    history_msgs = history_msgs[1:]
    context = [{"role": m.role, "content": m.content} for m in reversed(history_msgs)]
    
    # 4. Fetch current mood and mental state context (safe)
    current_mood = None
    mental_state = None
    try:
        latest_mood_log = db.query(MoodLog).filter(MoodLog.user_id == current_user.user_id).order_by(desc(MoodLog.timestamp)).first()
        current_mood = latest_mood_log.mood if latest_mood_log else None
    except Exception:
        pass
    
    try:
        from app.services.mental_state_service import calculate_mental_state_radar
        mental_state = calculate_mental_state_radar(db, current_user.user_id)
    except Exception:
        pass

    # 5. Generate AI reply (with fallback)
    try:
        ai_text = generate_therapy_response(
            user_message=data.content, 
            history=context,
            current_mood=current_mood,
            mental_state=mental_state
        )
    except Exception:
        ai_text = "I'm here to listen. Could you tell me more about how you're feeling?"
    
    # 6. Save AI message
    ai_msg = ConversationMessage(
        conversation_id=conversation_id,
        role="assistant",
        content=ai_text
    )
    db.add(ai_msg)
    
    # Update conversation's updated_at timestamp
    import datetime
    conversation.updated_at = datetime.datetime.utcnow()
    
    # Generate smart title from first user message if title is still default
    new_title = None
    try:
        user_msg_count = db.query(ConversationMessage).filter(
            ConversationMessage.conversation_id == conversation_id,
            ConversationMessage.role == "user"
        ).count()
        
        if conversation.title == "New Conversation" and user_msg_count <= 1:
            try:
                new_title = generate_chat_title(data.content)
            except Exception:
                new_title = "Therapy Session"
            conversation.title = new_title
    except Exception:
        pass
        
    db.commit()
    db.refresh(user_msg)
    db.refresh(ai_msg)
    
    return {"success": True, "data": {
        "user_message": user_msg,
        "ai_message": ai_msg,
        "updated_title": new_title
    }}

