"""Pydantic schemas for Life Pattern Discovery Engine (Phase 2)."""

from pydantic import BaseModel
from typing import List, Optional


class PatternInsight(BaseModel):
    pattern_id: str
    title: str
    description: str
    confidence: float
    data_points: int
    category: str


class LifePatternsResponse(BaseModel):
    has_enough_data: bool
    total_days_analyzed: int
    min_days_required: int
    patterns: List[PatternInsight]
    message: str
