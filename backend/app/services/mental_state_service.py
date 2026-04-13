from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from app.models.mood_log import MoodLog
from app.models.behavior_log import BehaviorLog

def calculate_mental_state_radar(db: Session, user_id: int, language: str = "en") -> dict:
    """
    Calculates mental state metrics (Mental Stability Index, Burnout Risk, Mood Stability)
    based on the user's logs over the last 7 days.
    """
    seven_days_ago = datetime.utcnow() - timedelta(days=7)
    
    # 1. Fetch data
    recent_moods = db.query(MoodLog).filter(
        MoodLog.user_id == user_id,
        MoodLog.created_at >= seven_days_ago
    ).order_by(MoodLog.created_at.asc()).all()
    
    recent_behaviors = db.query(BehaviorLog).filter(
        BehaviorLog.user_id == user_id,
        BehaviorLog.date >= seven_days_ago.date()
    ).order_by(BehaviorLog.date.asc()).all()

    # Default baseline if no data
    if not recent_moods and not recent_behaviors:
        burnout_str = "Unknown"
        mood_stab_str = "Unknown"
        if language == "hi":
            burnout_str = "अज्ञात"
            mood_stab_str = "अज्ञात"
        return {
            "mental_stability_index": 50,
            "burnout_risk_level": burnout_str,
            "mood_stability": mood_stab_str,
            "has_data": False
        }

    # 2. Analyze Moods
    mood_weights = {
        "Happy": 100, "Calm": 80, "Motivated": 90,
        "Neutral": 60, "Tired": 40,
        "Anxious": 20, "Sad": 20, "Stressed": 10, "Angry": 10
    }
    mood_scores = []
    
    for log in recent_moods:
        score = mood_weights.get(log.mood, 50)
        mood_scores.append(score)

    avg_mood_score = sum(mood_scores) / len(mood_scores) if mood_scores else 50
    
    # Measure Mood Stability (variance)
    mood_stability_str = "Stable"
    if len(mood_scores) > 2:
        variance = sum((x - avg_mood_score) ** 2 for x in mood_scores) / len(mood_scores)
        if variance > 400: # large swings
            mood_stability_str = "Fluctuating"
        elif variance < 100:
            mood_stability_str = "Highly Stable"
    
    if language == "hi":
        if mood_stability_str == "Stable": mood_stability_str = "स्थिर"
        elif mood_stability_str == "Fluctuating": mood_stability_str = "अस्थिर"
        elif mood_stability_str == "Highly Stable": mood_stability_str = "अत्यधिक स्थिर"

    # 3. Analyze Behaviors (Sleep & Screen Time)
    avg_sleep = 7.0
    avg_screen_time = 4.0
    exercise_days = 0
    if recent_behaviors:
        avg_sleep = sum(b.sleep_hours for b in recent_behaviors) / len(recent_behaviors)
        avg_screen_time = sum(b.screen_time_hours for b in recent_behaviors) / len(recent_behaviors)
        exercise_days = sum(1 for b in recent_behaviors if getattr(b, 'exercise', False))

    # 4. Calculate Mental Stability Index (0-100%)
    # Base is avg_mood_score (weighted slightly more)
    base_stability = avg_mood_score * 0.6
    
    # Sleep bonus/penalty (7-9 hours is ideal)
    sleep_factor = 20
    if avg_sleep < 5:
        sleep_factor = 0
    elif avg_sleep < 6:
        sleep_factor = 10
    
    # Screen time penalty (lower is better, assuming > 8 hrs is bad)
    screen_factor = 10
    if avg_screen_time > 8:
        screen_factor = 0
    elif avg_screen_time > 5:
        screen_factor = 5
        
    # Exercise bonus
    exercise_factor = min(10, exercise_days * 3)
    
    mental_stability_index = min(100, max(0, int(base_stability + sleep_factor + screen_factor + exercise_factor)))
    
    # 5. Determine Burnout Risk
    burnout_risk = "Low"
    if mental_stability_index < 40 and avg_sleep < 6:
        burnout_risk = "High"
    elif mental_stability_index < 60 or avg_screen_time > 7:
        burnout_risk = "Moderate"

    if language == "hi":
        if burnout_risk == "Low": burnout_risk = "कम"
        elif burnout_risk == "Moderate": burnout_risk = "मध्यम"
        elif burnout_risk == "High": burnout_risk = "उच्च"

    return {
        "mental_stability_index": mental_stability_index,
        "burnout_risk_level": burnout_risk,
        "mood_stability": mood_stability_str,
        "has_data": True
    }
