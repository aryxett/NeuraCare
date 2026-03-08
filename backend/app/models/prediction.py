from sqlalchemy import Column, Integer, Float, String, Text, Date, DateTime, ForeignKey, func
from sqlalchemy.orm import relationship
from app.database import Base


class Prediction(Base):
    __tablename__ = "predictions"

    prediction_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True)
    stress_score = Column(Float, nullable=False)  # 0-100
    risk_level = Column(String(20), nullable=False)  # Low, Moderate, High, Critical
    insights = Column(Text, nullable=True)
    prediction_date = Column(Date, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    # Relationships
    user = relationship("User", back_populates="predictions")

    def __repr__(self):
        return f"<Prediction(prediction_id={self.prediction_id}, stress_score={self.stress_score})>"
