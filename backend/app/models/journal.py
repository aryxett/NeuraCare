from sqlalchemy import Column, Integer, String, Text, DateTime, Float, ForeignKey, func
from sqlalchemy.orm import relationship
from app.database import Base


class JournalEntry(Base):
    __tablename__ = "journal_entries"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)
    content = Column(Text, nullable=False)
    sentiment = Column(Float, nullable=True)  # -1.0 to 1.0
    emotion = Column(String(50), nullable=True) # happy, neutral, stressed, sad
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User")

    def __repr__(self):
        return f"<JournalEntry(id={self.id}, user_id={self.user_id}, sentiment={self.sentiment})>"
