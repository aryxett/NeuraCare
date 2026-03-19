from pydantic import BaseModel
from typing import List

class CorrelationCard(BaseModel):
    title: str
    explanation: str
    confidence_level: str

class CorrelationResponse(BaseModel):
    correlations: List[CorrelationCard]
