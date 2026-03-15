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
    ConversationMessagesResponse,
    SendMessageRequest,
    SendMessageResponse,
    MessageResponse
)
from app.schemas.common import StandardizedResponse
from app.services.auth_service import get_current_user
from app.services.therapy_llm_service import generate_therapy_response

router = APIRouter(prefix="/api/chat", tags=["Chat Management"])

@router.get("/conversations", response_model=StandardizedResponse[ConversationListResponse])
async def get_conversations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all conversations for the current user, ordered by most recent."""
    conversations = (
        db.query(ChatConversation)
        .filter(ChatConversation.user_id == current_user.user_id)
        .order_by(ChatConversation.updated_at.desc())
        .all()
    )
    return {"success": True, "data": {"conversations": conversations}}


@router.post("/conversations", response_model=StandardizedResponse[ConversationResponse], status_code=status.HTTP_201_CREATED)
async def create_conversation(
    data: ConversationCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new empty conversation."""
    new_conv = ChatConversation(
        user_id=current_user.user_id,
        title=data.title or "New Conversation"
    )
    db.add(new_conv)
    db.commit()
    db.refresh(new_conv)
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


@router.get("/conversations/{conversation_id}/messages", response_model=StandardizedResponse[ConversationMessagesResponse])
async def get_messages(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all messages for a specific conversation."""
    # First verify ownership
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
    # Exclude the just-saved message to avoid duplication in history payload, but include it implicitly as the current prompt.
    # Wait, generate_therapy_response takes `message` and `history`.
    # Let's pass the 10 messages before the current one as history.
    history_msgs = history_msgs[1:] # remove the user message we just saved if it's the first in desc order
    context = [{"role": m.role, "content": m.content} for m in reversed(history_msgs)]
    
    # 4. Generate AI reply
    ai_text = generate_therapy_response(data.content, history=context)
    
    # 5. Save AI message
    ai_msg = ConversationMessage(
        conversation_id=conversation_id,
        role="assistant",
        content=ai_text
    )
    db.add(ai_msg)
    
    # Update conversation's updated_at timestamp
    import datetime
    conversation.updated_at = datetime.datetime.utcnow()
    
    # Update title to summarize first message if it's still Default
    if conversation.title == "New Conversation" and len(history_msgs) == 0:
        # Simple summarizing: take first 30 chars
        conversation.title = (data.content[:27] + '...') if len(data.content) > 30 else data.content
        
    db.commit()
    db.refresh(user_msg)
    db.refresh(ai_msg)
    
    return {"success": True, "data": {
        "user_message": user_msg,
        "ai_message": ai_msg
    }}
