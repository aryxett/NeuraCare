from datetime import date, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.behavior_log import BehaviorLog
from app.models.prediction import Prediction
from app.models.profile import BehaviorProfile

def calculate_wellness_score(sleep: float, screen: float, mood: int, exercise: bool) -> int:
    """
    Calculates a composite Wellness Score (0-100).
    Sleep: max 30 points (optimal 7-9h)
    Screen Time: max 20 points (optimal < 4h)
    Mood: max 40 points (optimal 10)
    Exercise: max 10 points
    """
    sleep_score = 0
    if 7 <= sleep <= 9: sleep_score = 30
    elif 6 <= sleep < 7 or 9 < sleep <= 10: sleep_score = 20
    elif 5 <= sleep < 6: sleep_score = 10
    
    screen_score = 0
    if screen <= 4: screen_score = 20
    elif screen <= 7: screen_score = 15
    elif screen <= 10: screen_score = 5
    
    mood_score = (mood / 10) * 40
    
    exercise_score = 10 if exercise else 0
    
    return int(sleep_score + screen_score + mood_score + exercise_score)

def predict_burnout(logs: List[BehaviorLog]) -> float:
    """
    Predicts probability of burnout (0-100) based on recent trends.
    Looks for: declining sleep, increasing screen time, declining mood.
    """
    if len(logs) < 3:
        return 0.0
        
    # Declining mood weight
    moods = [l.mood for l in logs]
    mood_decline = 0
    if all(moods[i] >= moods[i+1] for i in range(len(moods)-1)):
        mood_decline = 40
    elif moods[-1] < moods[0]:
        mood_decline = 20
        
    # High screen time weight
    avg_screen = sum(l.screen_time for l in logs) / len(logs)
    screen_weight = 0
    if avg_screen > 10: screen_weight = 40
    elif avg_screen > 8: screen_weight = 20
    
    # Low sleep weight
    avg_sleep = sum(l.sleep_hours for l in logs) / len(logs)
    sleep_weight = 0
    if avg_sleep < 5: sleep_weight = 20
    elif avg_sleep < 6: sleep_weight = 10
    
    return float(min(100, mood_decline + screen_weight + sleep_weight))

def detect_triggers(logs: List[BehaviorLog], predictions: List[Prediction]) -> List[str]:
    """
    Identifies correlations between behaviors and high stress scores.
    """
    triggers = []
    if not logs or not predictions:
        return triggers
        
    # Simple correlation check: Screen time > 9 and High Stress
    high_stress_dates = [p.prediction_date for p in predictions if p.stress_score > 70]
    high_screen_dates = [l.date for l in logs if l.screen_time > 9]
    
    common = set(high_stress_dates).intersection(set(high_screen_dates))
    if len(common) >= 2:
        triggers.append("High screen time (exceeding 9 hours) is highly correlated with your peak stress levels.")
        
    # Late night activity (if we had timestamps, but we only have daily logs)
    # Check if low sleep leads to low mood next day
    for i in range(len(logs) - 1):
        if logs[i].sleep_hours < 5 and logs[i+1].mood < 4:
            triggers.append("Insufficient sleep consistently leads to a significant mood drop the following day.")
            break
            
    return triggers

def update_behavioral_profile(db: Session, user_id: int):
    """
    Builds/Updates the Cognitive Digital Twin behavioral profile.
    """
    seven_days_ago = date.today() - timedelta(days=7)
    logs = db.query(BehaviorLog).filter(BehaviorLog.user_id == user_id, BehaviorLog.date >= seven_days_ago).all()
    
    if len(logs) < 3:
        return
        
    patterns = []
    avg_sleep = sum(l.sleep_hours for l in logs) / len(logs)
    if avg_sleep < 6:
        patterns.append("Short sleeper pattern")
    
    avg_screen = sum(l.screen_time for l in logs) / len(logs)
    if avg_screen > 8:
        patterns.append("High digital engagement")
        
    exercise_count = sum(1 for l in logs if l.exercise)
    if exercise_count >= 4:
        patterns.append("Active recovery habit")
    
    # Update or create profile
    profile = db.query(BehaviorProfile).filter(BehaviorProfile.user_id == user_id).first()
    if not profile:
        profile = BehaviorProfile(user_id=user_id, patterns=", ".join(patterns))
        db.add(profile)
    else:
        profile.patterns = ", ".join(patterns)
    
    db.commit()
