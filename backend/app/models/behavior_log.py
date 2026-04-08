from sqlalchemy import Column, Integer, Float, Boolean, Date, DateTime, ForeignKey, func
from sqlalchemy.orm import relationship
from app.database import Base


class BehaviorLog(Base):
    __tablename__ = "behavior_logs"

    log_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True)
    date = Column(Date, nullable=False, index=True)
    sleep_hours = Column(Float, nullable=False)
    screen_time = Column(Float, nullable=False)
    mood = Column(Integer, nullable=False)  # 1-10 scale
    exercise = Column(Boolean, default=False)
    
    # Phase 5: App Usage Categories (in hours)
    social_time = Column(Float, nullable=True, default=0.0)
    entertainment_time = Column(Float, nullable=True, default=0.0)
    productivity_time = Column(Float, nullable=True, default=0.0)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    # Relationships
    user = relationship("User", back_populates="behavior_logs")

    def __repr__(self):
        return f"<BehaviorLog(log_id={self.log_id}, date='{self.date}', mood={self.mood})>"
