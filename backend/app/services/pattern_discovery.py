"""
Life Pattern Discovery Engine (Phase 2)

Detects hidden behavioral patterns from existing BehaviorLog and Prediction data.
Uses correlation-based rules with confidence scoring. No DB schema changes.
"""

from typing import List, Dict, Any, Optional
from datetime import date, timedelta
from sqlalchemy.orm import Session
from app.models.behavior_log import BehaviorLog
from app.models.prediction import Prediction

# Minimum total log entries required before generating ANY patterns
MIN_DATA_POINTS = 5

# Minimum relevant samples PER PATTERN before it can be shown
MIN_PATTERN_SAMPLES = 5

# Minimum confidence threshold — patterns below this are suppressed
MIN_CONFIDENCE = 0.4


def _data_strength(sample_count: int) -> str:
    """Classify sample size into a human-readable data strength label."""
    if sample_count < 5:
        return "Insufficient"
    elif sample_count < 10:
        return "Low"
    elif sample_count < 20:
        return "Moderate"
    elif sample_count < 30:
        return "Strong"
    else:
        return "Very Strong"


def _build_pattern(pattern_id: str, title: str, description: str,
                   raw_confidence: float, data_points: int, category: str) -> Optional[Dict]:
    """Build a pattern dict with data strength and confidence penalty for small samples."""
    # Suppress patterns with too few relevant data points
    if data_points < MIN_PATTERN_SAMPLES:
        return None

    # Apply sample-size penalty: scale confidence down for small samples
    # Full confidence only at 15+ samples, linear ramp from 5 to 15
    sample_factor = min(data_points / 15.0, 1.0)
    adjusted_confidence = round(raw_confidence * sample_factor, 2)

    strength = _data_strength(data_points)

    return {
        "pattern_id": pattern_id,
        "title": title,
        "description": description,
        "confidence": adjusted_confidence,
        "data_points": data_points,
        "data_strength": strength,
        "category": category,
    }


def discover_patterns(db: Session, user_id: int) -> Dict[str, Any]:
    """
    Main entry point. Queries the user's data, runs all pattern detectors,
    and returns a structured response with only high-confidence patterns.
    """
    # Fetch last 30 days of data
    cutoff = date.today() - timedelta(days=30)
    logs = (
        db.query(BehaviorLog)
        .filter(BehaviorLog.user_id == user_id, BehaviorLog.date >= cutoff)
        .order_by(BehaviorLog.date.asc())
        .all()
    )
    preds = (
        db.query(Prediction)
        .filter(Prediction.user_id == user_id, Prediction.prediction_date >= cutoff)
        .order_by(Prediction.prediction_date.asc())
        .all()
    )

    total_days = len(logs)

    # Not enough data — return empty with a message
    if total_days < MIN_DATA_POINTS:
        return {
            "has_enough_data": False,
            "total_days_analyzed": total_days,
            "min_days_required": MIN_DATA_POINTS,
            "patterns": [],
            "message": f"At least {MIN_DATA_POINTS} days of data are needed to detect patterns. You have {total_days} day(s) so far."
        }

    # Build a date-indexed stress map from predictions
    stress_map: Dict[date, float] = {p.prediction_date: p.stress_score for p in preds}

    # Run all detectors
    all_patterns = []
    all_patterns.append(_detect_low_sleep_high_stress(logs, stress_map))
    all_patterns.append(_detect_high_screen_negative_mood(logs))
    all_patterns.append(_detect_exercise_mood_boost(logs))
    all_patterns.append(_detect_sleep_mood_correlation(logs))
    all_patterns.append(_detect_screen_sleep_impact(logs))
    all_patterns.append(_detect_exercise_stress_reduction(logs, stress_map))
    all_patterns.append(_detect_weekend_weekday_diff(logs))

    # Filter out None results and low-confidence patterns
    patterns = [p for p in all_patterns if p is not None and p["confidence"] >= MIN_CONFIDENCE]

    # Sort by confidence descending
    patterns.sort(key=lambda x: x["confidence"], reverse=True)

    return {
        "has_enough_data": True,
        "total_days_analyzed": total_days,
        "min_days_required": MIN_DATA_POINTS,
        "patterns": patterns,
        "message": f"Analyzed {total_days} days of behavioral data."
    }


# ─────────────────────────── Pattern Detectors ───────────────────────────


def _detect_low_sleep_high_stress(logs: List[BehaviorLog], stress_map: Dict[date, float]) -> Optional[Dict]:
    """Sleep < 6h on days where stress > 50."""
    low_sleep_days = [l for l in logs if l.sleep_hours < 6]
    if not low_sleep_days:
        return None

    matched = sum(1 for l in low_sleep_days if stress_map.get(l.date, 0) > 50)
    raw_confidence = matched / len(low_sleep_days)

    return _build_pattern(
        "low_sleep_high_stress",
        "Sleep Deficit \u2192 Stress Spike",
        f"Your stress tends to increase on days when your sleep drops below 6 hours. This pattern was observed on {matched} out of {len(low_sleep_days)} short-sleep days.",
        raw_confidence, len(low_sleep_days), "sleep"
    )


def _detect_high_screen_negative_mood(logs: List[BehaviorLog]) -> Optional[Dict]:
    """Screen time > 7h correlates with mood < 5."""
    high_screen_days = [l for l in logs if l.screen_time > 7]
    if not high_screen_days:
        return None

    matched = sum(1 for l in high_screen_days if l.mood < 5)
    raw_confidence = matched / len(high_screen_days)

    return _build_pattern(
        "high_screen_negative_mood",
        "Excessive Screen Time \u2192 Low Mood",
        f"On days when your screen time exceeds 7 hours, your mood tends to drop below average. Detected on {matched} of {len(high_screen_days)} high-screen days.",
        raw_confidence, len(high_screen_days), "screen_time"
    )


def _detect_exercise_mood_boost(logs: List[BehaviorLog]) -> Optional[Dict]:
    """Exercise days have noticeably higher mood than non-exercise days."""
    exercise_days = [l for l in logs if l.exercise]
    rest_days = [l for l in logs if not l.exercise]

    if not exercise_days or not rest_days:
        return None

    avg_mood_exercise = sum(l.mood for l in exercise_days) / len(exercise_days)
    avg_mood_rest = sum(l.mood for l in rest_days) / len(rest_days)

    diff = avg_mood_exercise - avg_mood_rest
    if diff <= 0:
        return None

    raw_confidence = min(diff / 3.0, 1.0)

    return _build_pattern(
        "exercise_mood_boost",
        "Exercise \u2192 Mood Improvement",
        f"Your mood averages {avg_mood_exercise:.1f}/10 on exercise days vs {avg_mood_rest:.1f}/10 on rest days \u2014 a {diff:.1f}-point boost.",
        raw_confidence, len(exercise_days) + len(rest_days), "exercise"
    )


def _detect_sleep_mood_correlation(logs: List[BehaviorLog]) -> Optional[Dict]:
    """Sleep < 6h correlates with mood < 5."""
    low_sleep_days = [l for l in logs if l.sleep_hours < 6]
    if not low_sleep_days:
        return None

    matched = sum(1 for l in low_sleep_days if l.mood < 5)
    raw_confidence = matched / len(low_sleep_days)

    return _build_pattern(
        "sleep_mood_correlation",
        "Poor Sleep \u2192 Low Mood",
        f"On {matched} of {len(low_sleep_days)} nights with less than 6 hours of sleep, your mood dropped below 5/10 the same day.",
        raw_confidence, len(low_sleep_days), "sleep"
    )


def _detect_screen_sleep_impact(logs: List[BehaviorLog]) -> Optional[Dict]:
    """Screen > 8h today correlates with sleep < 6h."""
    high_screen_days = [l for l in logs if l.screen_time > 8]
    if not high_screen_days:
        return None

    matched = sum(1 for l in high_screen_days if l.sleep_hours < 6)
    raw_confidence = matched / len(high_screen_days)

    return _build_pattern(
        "screen_time_sleep_impact",
        "High Screen Time \u2192 Sleep Disruption",
        f"When your screen time goes above 8 hours, your sleep tends to suffer. Seen on {matched} of {len(high_screen_days)} high-screen days.",
        raw_confidence, len(high_screen_days), "screen_time"
    )


def _detect_exercise_stress_reduction(logs: List[BehaviorLog], stress_map: Dict[date, float]) -> Optional[Dict]:
    """Exercise days have lower average stress than non-exercise days."""
    exercise_days = [l for l in logs if l.exercise and l.date in stress_map]
    rest_days = [l for l in logs if not l.exercise and l.date in stress_map]

    if not exercise_days or not rest_days:
        return None

    avg_stress_ex = sum(stress_map[l.date] for l in exercise_days) / len(exercise_days)
    avg_stress_rest = sum(stress_map[l.date] for l in rest_days) / len(rest_days)

    diff = avg_stress_rest - avg_stress_ex
    if diff <= 0:
        return None

    raw_confidence = min(diff / 30.0, 1.0)

    return _build_pattern(
        "exercise_stress_reduction",
        "Exercise \u2192 Stress Reduction",
        f"Your average stress is {avg_stress_ex:.0f}% on exercise days vs {avg_stress_rest:.0f}% on rest days \u2014 exercise appears to lower stress by {diff:.0f} points.",
        raw_confidence, len(exercise_days) + len(rest_days), "exercise"
    )


def _detect_weekend_weekday_diff(logs: List[BehaviorLog]) -> Optional[Dict]:
    """Detect if weekends vs weekdays have significantly different mood/sleep."""
    weekday_logs = [l for l in logs if l.date.weekday() < 5]
    weekend_logs = [l for l in logs if l.date.weekday() >= 5]

    if len(weekday_logs) < 3 or len(weekend_logs) < 2:
        return None

    avg_mood_wd = sum(l.mood for l in weekday_logs) / len(weekday_logs)
    avg_mood_we = sum(l.mood for l in weekend_logs) / len(weekend_logs)
    avg_sleep_wd = sum(l.sleep_hours for l in weekday_logs) / len(weekday_logs)
    avg_sleep_we = sum(l.sleep_hours for l in weekend_logs) / len(weekend_logs)

    mood_diff = abs(avg_mood_we - avg_mood_wd)
    sleep_diff = abs(avg_sleep_we - avg_sleep_wd)

    if mood_diff < 1.0 and sleep_diff < 1.0:
        return None

    raw_confidence = min((mood_diff + sleep_diff) / 4.0, 1.0)

    better_on = "weekends" if avg_mood_we > avg_mood_wd else "weekdays"
    description = (
        f"Your mood averages {avg_mood_we:.1f}/10 on weekends vs {avg_mood_wd:.1f}/10 on weekdays. "
        f"Sleep averages {avg_sleep_we:.1f}h on weekends vs {avg_sleep_wd:.1f}h on weekdays. "
        f"You tend to feel better on {better_on}."
    )

    return _build_pattern(
        "weekend_vs_weekday",
        "Weekend vs Weekday Pattern",
        description,
        raw_confidence, len(weekday_logs) + len(weekend_logs), "lifestyle"
    )

