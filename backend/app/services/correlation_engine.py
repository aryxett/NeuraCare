"""
Behavioral Correlation Engine (Phase 3)

Identifies correlations between behavioral variables and emotional outcomes.
Does not predict or use ML; uses simple statistical logic comparing averages.
"""

from typing import List, Dict, Any, Tuple
from sqlalchemy.orm import Session
from app.models.behavior_log import BehaviorLog
from app.models.prediction import Prediction

def _category_sleep(hours: float) -> str:
    if hours < 6: return "<6"
    elif hours <= 8: return "6-8"
    else: return ">8"

def _category_screen(hours: float) -> str:
    if hours < 3: return "<3"
    elif hours <= 6: return "3-6"
    else: return ">6"

def compute_correlations(db: Session, user_id: int) -> List[Dict]:
    """
    Computes correlations for Sleep vs Mood, Screen Time vs Stress, Activity vs Mood.
    Requires at least 5 total data points to generate any insights.
    """
    # Fetch logs
    logs = db.query(BehaviorLog).filter(BehaviorLog.user_id == user_id).all()
    
    if len(logs) < 5:
        return [{
            "title": "Insufficient Data",
            "explanation": f"We need at least 5 days of logged data to analyze your behavioral correlations. You currently have {len(logs)}.",
            "confidence_level": "Low"
        }]

    # Fetch predictions to get stress score map
    preds = db.query(Prediction).filter(Prediction.user_id == user_id).all()
    stress_map = {p.prediction_date: p.stress_score for p in preds}

    correlations = []

    # 1. Sleep vs Mood
    sleep_groups: Dict[str, List[float]] = {"<6": [], "6-8": [], ">8": []}
    for log in logs:
        cat = _category_sleep(log.sleep_hours)
        sleep_groups[cat].append(log.mood)
    
    # Analyze if <6 sleep has worse mood than >=6
    if sleep_groups["<6"] and (sleep_groups["6-8"] or sleep_groups[">8"]):
        low_sleep_avg = sum(sleep_groups["<6"]) / len(sleep_groups["<6"])
        
        # Combine 6-8 and >8 for comparison
        good_sleep = sleep_groups["6-8"] + sleep_groups[">8"]
        if good_sleep:
            good_sleep_avg = sum(good_sleep) / len(good_sleep)
            
            if low_sleep_avg < good_sleep_avg - 0.5:
                num_samples = len(sleep_groups["<6"]) + len(good_sleep)
                conf = "High" if num_samples >= 15 else "Moderate"
                correlations.append({
                    "title": "Sleep & Mood",
                    "explanation": f"Lower sleep duration (<6h) is associated with reduced mood levels (avg {low_sleep_avg:.1f}/10) compared to adequate sleep (avg {good_sleep_avg:.1f}/10).",
                    "confidence_level": conf
                })
            elif low_sleep_avg > good_sleep_avg + 0.5:
                # Paradoxical
                num_samples = len(sleep_groups["<6"]) + len(good_sleep)
                conf = "Moderate" if num_samples >= 10 else "Low"
                correlations.append({
                    "title": "Sleep & Mood Profile",
                    "explanation": f"Interestingly, your mood averages higher ({low_sleep_avg:.1f}/10) on days with less sleep compared to days you sleep more.",
                    "confidence_level": conf
                })

    # 2. Screen Time vs Stress
    screen_groups: Dict[str, List[float]] = {"<3": [], "3-6": [], ">6": []}
    for log in logs:
        if log.date in stress_map:
            cat = _category_screen(log.screen_time)
            screen_groups[cat].append(stress_map[log.date])
    
    if screen_groups[">6"] and (screen_groups["<3"] or screen_groups["3-6"]):
        high_screen_avg = sum(screen_groups[">6"]) / len(screen_groups[">6"])
        
        lower_screen = screen_groups["<3"] + screen_groups["3-6"]
        if lower_screen:
            lower_screen_avg = sum(lower_screen) / len(lower_screen)
            
            if high_screen_avg > lower_screen_avg + 5:
                num_samples = len(screen_groups[">6"]) + len(lower_screen)
                conf = "High" if num_samples >= 15 else "Moderate"
                correlations.append({
                    "title": "Screen Time & Stress",
                    "explanation": f"High screen time (>6h) correlates with increased stress levels (avg {high_screen_avg:.0f}%) compared to lower screen times (avg {lower_screen_avg:.0f}%).",
                    "confidence_level": conf
                })

    # 3. Activity vs Mood
    act_mood = [log.mood for log in logs if log.exercise]
    no_act_mood = [log.mood for log in logs if not log.exercise]
    
    if act_mood and no_act_mood:
        avg_act = sum(act_mood) / len(act_mood)
        avg_no_act = sum(no_act_mood) / len(no_act_mood)
        
        if avg_act > avg_no_act + 0.5:
            num_samples = len(act_mood) + len(no_act_mood)
            conf = "High" if num_samples >= 15 else "Moderate"
            correlations.append({
                "title": "Activity & Mood",
                "explanation": f"Physical activity is associated with a noticeable mood boost (avg {avg_act:.1f}/10 vs {avg_no_act:.1f}/10 on inactive days).",
                "confidence_level": conf
            })

    # If no correlations were found despite having >5 points
    if not correlations:
        return [{
            "title": "No Strong Correlations Yet",
            "explanation": "We analyzed your data but didn't find any statistically significant correlations between your sleep, screen time, activity, and your mood or stress. Keep logging to discover subtle trends!",
            "confidence_level": "None"
        }]

    return correlations
