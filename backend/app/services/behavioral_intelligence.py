"""
Advanced Behavioral Intelligence Service

Computes 7 intelligence features from existing Phase 1-3 data:
  F1: Risk Scoring (Mental Stability, Burnout Risk, Focus Score)
  F2: Enhanced Correlation Insights (human-readable with strength)
  F3: Emerging Patterns (soft insights with >=3 points)
  F4: Behavioral Drift Detection (recent vs overall, >20% threshold)
  F5: Confidence & Data Strength (attached to every insight)
  F6: Smart Interventions (only on strong signals)
  F7: Weekly Summary (7-day narrative)

Uses ONLY existing data: BehaviorLog, Prediction, correlation_engine output.
"""

from typing import List, Dict, Any
from datetime import date, timedelta
from sqlalchemy.orm import Session
from app.models.behavior_log import BehaviorLog
from app.models.prediction import Prediction
from app.services.correlation_engine import compute_correlations


def _data_strength(count: int, language: str = "en") -> Dict[str, Any]:
    """F5: Map data point count to confidence % and strength label."""
    if language == "hi":
        if count >= 8:
            return {"confidence_pct": 85, "data_strength": "उच्च"}
        elif count >= 3:
            return {"confidence_pct": 60, "data_strength": "मध्यम"}
        else:
            return {"confidence_pct": 30, "data_strength": "कम"}
    else:
        if count >= 8:
            return {"confidence_pct": 85, "data_strength": "High"}
        elif count >= 3:
            return {"confidence_pct": 60, "data_strength": "Moderate"}
        else:
            return {"confidence_pct": 30, "data_strength": "Low"}


def _safe_avg(values: list) -> float:
    return sum(values) / len(values) if values else 0.0


def _risk_label(level: str, language: str) -> str:
    """Translate risk level labels."""
    if language != "hi":
        return level
    m = {"Low": "कम", "Moderate": "मध्यम", "High": "उच्च", "Critical": "गंभीर", "Unknown": "अज्ञात"}
    return m.get(level, level)


def _metric_name(metric: str, language: str) -> str:
    """Translate metric names."""
    if language != "hi":
        return metric
    m = {"Sleep": "नींद", "Screen Time": "स्क्रीन समय", "Mood": "मनोदशा"}
    return m.get(metric, metric)


def compute_risk_scores(logs: List[BehaviorLog], preds: List[Any], language: str = "en") -> Dict[str, Any]:
    """F1: Lightweight behavioral risk scoring from last 7 days."""
    today = date.today()
    week_ago = today - timedelta(days=7)
    recent = [l for l in logs if l.date and l.date >= week_ago]

    if not recent:
        return {
            "mental_stability": 50,
            "burnout_risk": _risk_label("Unknown", language),
            "focus_score": 50,
            "has_data": False
        }

    moods = [l.mood for l in recent]
    sleeps = [l.sleep_hours for l in recent]
    screens = [l.screen_time for l in recent]
    exercises = [1 for l in recent if l.exercise]

    avg_mood = _safe_avg(moods)
    avg_sleep = _safe_avg(sleeps)
    avg_screen = _safe_avg(screens)
    exercise_ratio = len(exercises) / len(recent) if recent else 0

    # Normalize to 0-100
    mood_norm = min(avg_mood / 10.0 * 100, 100)
    sleep_norm = min(avg_sleep / 9.0 * 100, 100)  # 9h = perfect
    screen_inv = max(100 - (avg_screen / 12.0 * 100), 0)  # lower is better
    exercise_bonus = exercise_ratio * 100

    # Mental Stability (0-100)
    mental_stability = int(
        mood_norm * 0.4 + sleep_norm * 0.3 + screen_inv * 0.2 + exercise_bonus * 0.1
    )
    mental_stability = max(0, min(100, mental_stability))

    # Focus Score (higher sleep + lower screen = better focus)
    focus_score = int(sleep_norm * 0.5 + screen_inv * 0.5)
    focus_score = max(0, min(100, focus_score))

    # Burnout Risk
    recent_stress = [p.stress_score for p in preds if p.prediction_date and p.prediction_date >= week_ago]
    avg_stress = _safe_avg(recent_stress) if recent_stress else 50

    if mental_stability < 35 or avg_stress > 70:
        burnout_risk = "High"
    elif mental_stability < 55 or avg_stress > 50:
        burnout_risk = "Moderate"
    else:
        burnout_risk = "Low"

    return {
        "mental_stability": mental_stability,
        "burnout_risk": _risk_label(burnout_risk, language),
        "focus_score": focus_score,
        "has_data": True
    }


def compute_enhanced_correlations(db: Session, user_id: int, language: str = "en") -> List[Dict[str, Any]]:
    """F2 + F5: Enhanced correlation insights with human-readable language and confidence."""
    raw = compute_correlations(db, user_id)
    enhanced = []

    if language == "hi":
        strength_map = {"High": "मजबूत", "Moderate": "मध्यम", "Low": "हल्का", "None": "कोई स्पष्ट नहीं"}
    else:
        strength_map = {"High": "strong", "Moderate": "moderate", "Low": "slight", "None": "no clear"}

    for c in raw:
        title = c.get("title", "")
        if title in ["Insufficient Data", "No Strong Correlations Yet"]:
            continue

        conf_level = c.get("confidence_level", "Low")
        strength_word = strength_map.get(conf_level, strength_map.get("Low", "slight"))

        enhanced.append({
            "title": c["title"],
            "insight": c["explanation"],
            "strength": strength_word,
            "confidence_level": conf_level,
            **_data_strength(15 if conf_level == "High" else 5 if conf_level == "Moderate" else 2, language)
        })

    return enhanced


def compute_emerging_patterns(logs: List[BehaviorLog], preds: List[Any], language: str = "en") -> List[Dict[str, Any]]:
    """F3: Soft early observations when 3-4 data points exist."""
    if len(logs) < 3:
        return []

    patterns = []
    stress_map = {p.prediction_date: p.stress_score for p in preds}

    # Sleep vs Mood (soft)
    low_sleep_moods = [l.mood for l in logs if l.sleep_hours < 6]
    ok_sleep_moods = [l.mood for l in logs if l.sleep_hours >= 6]

    if len(low_sleep_moods) >= 1 and len(ok_sleep_moods) >= 1:
        avg_low = _safe_avg(low_sleep_moods)
        avg_ok = _safe_avg(ok_sleep_moods)
        if avg_low < avg_ok - 0.3:
            insight = "कम नींद आपकी मनोदशा को प्रभावित कर सकती है।" if language == "hi" else "Lower sleep may be affecting your mood."
            patterns.append({
                "title": "नींद और मनोदशा" if language == "hi" else "Sleep & Mood",
                "insight": insight,
                "type": "emerging",
                **_data_strength(len(logs), language)
            })

    # Screen vs Stress (soft)
    high_screen_stress = [stress_map[l.date] for l in logs if l.screen_time > 5 and l.date in stress_map]
    low_screen_stress = [stress_map[l.date] for l in logs if l.screen_time <= 5 and l.date in stress_map]

    if high_screen_stress and low_screen_stress:
        avg_high = _safe_avg(high_screen_stress)
        avg_low = _safe_avg(low_screen_stress)
        if avg_high > avg_low + 3:
            insight = "ज्यादा स्क्रीन समय से तनाव थोड़ा बढ़ सकता है।" if language == "hi" else "Higher screen time may slightly increase stress."
            patterns.append({
                "title": "स्क्रीन समय और तनाव" if language == "hi" else "Screen Time & Stress",
                "insight": insight,
                "type": "emerging",
                **_data_strength(len(logs), language)
            })

    # Exercise vs Mood (soft)
    ex_moods = [l.mood for l in logs if l.exercise]
    no_ex_moods = [l.mood for l in logs if not l.exercise]
    if ex_moods and no_ex_moods:
        if _safe_avg(ex_moods) > _safe_avg(no_ex_moods) + 0.3:
            insight = "व्यायाम वाले दिनों में मनोदशा बेहतर रहती है।" if language == "hi" else "Active days tend to correlate with slightly better mood."
            patterns.append({
                "title": "गतिविधि और मनोदशा" if language == "hi" else "Activity & Mood",
                "insight": insight,
                "type": "emerging",
                **_data_strength(len(logs), language)
            })

    return patterns


def compute_behavioral_drift(logs: List[BehaviorLog], language: str = "en") -> List[Dict[str, Any]]:
    """F4: Compare recent 3-5 days vs overall average. Trigger if >20% change."""
    if len(logs) < 5:
        return []

    sorted_logs = sorted(logs, key=lambda l: l.date if l.date else date.min)
    recent = sorted_logs[-3:]  # last 3 days
    older = sorted_logs[:-3]   # everything before

    if not older:
        return []

    drifts = []

    # Sleep drift
    recent_sleep = _safe_avg([l.sleep_hours for l in recent])
    overall_sleep = _safe_avg([l.sleep_hours for l in older])
    if overall_sleep > 0:
        sleep_change = (recent_sleep - overall_sleep) / overall_sleep
        if abs(sleep_change) > 0.20:
            if language == "hi":
                direction = "कम हुई" if sleep_change < 0 else "बढ़ी"
                pct = abs(int(sleep_change * 100))
                insight_text = f"आपकी नींद पिछले औसत की तुलना में {pct}% {direction} है।"
            else:
                direction = "decreased" if sleep_change < 0 else "increased"
                pct = abs(int(sleep_change * 100))
                insight_text = f"Your sleep has {direction} by {pct}% compared to your recent average."
            drifts.append({
                "metric": _metric_name("Sleep", language),
                "insight": insight_text,
                "change_pct": int(sleep_change * 100),
                "direction": "down" if sleep_change < 0 else "up",
                **_data_strength(len(logs), language)
            })

    # Screen time drift
    recent_screen = _safe_avg([l.screen_time for l in recent])
    overall_screen = _safe_avg([l.screen_time for l in older])
    if overall_screen > 0:
        screen_change = (recent_screen - overall_screen) / overall_screen
        if abs(screen_change) > 0.20:
            if language == "hi":
                direction = "बढ़ा" if screen_change > 0 else "कम हुआ"
                pct = abs(int(screen_change * 100))
                insight_text = f"आपका स्क्रीन समय पिछले औसत की तुलना में {pct}% {direction} है।"
            else:
                direction = "increased" if screen_change > 0 else "decreased"
                pct = abs(int(screen_change * 100))
                insight_text = f"Your screen time has {direction} by {pct}% compared to your recent average."
            drifts.append({
                "metric": _metric_name("Screen Time", language),
                "insight": insight_text,
                "change_pct": int(screen_change * 100),
                "direction": "up" if screen_change > 0 else "down",
                **_data_strength(len(logs), language)
            })

    # Mood drift
    recent_mood = _safe_avg([l.mood for l in recent])
    overall_mood = _safe_avg([l.mood for l in older])
    if overall_mood > 0:
        mood_change = (recent_mood - overall_mood) / overall_mood
        if abs(mood_change) > 0.20:
            if language == "hi":
                direction = "गिरी" if mood_change < 0 else "सुधरी"
                pct = abs(int(mood_change * 100))
                insight_text = f"आपकी मनोदशा पिछले औसत की तुलना में {pct}% {direction} है।"
            else:
                direction = "dropped" if mood_change < 0 else "improved"
                pct = abs(int(mood_change * 100))
                insight_text = f"Your mood has {direction} by {pct}% compared to your recent average."
            drifts.append({
                "metric": _metric_name("Mood", language),
                "insight": insight_text,
                "change_pct": int(mood_change * 100),
                "direction": "down" if mood_change < 0 else "up",
                **_data_strength(len(logs), language)
            })

    return drifts


def compute_smart_interventions(risk_scores: Dict, drifts: List[Dict], language: str = "en") -> List[Dict[str, Any]]:
    """F6: Trigger suggestions only on strong signals."""
    interventions = []

    if risk_scores.get("burnout_risk") in ["High", "उच्च"]:
        suggestion = "आपका बर्नआउट खतरा बढ़ा हुआ है। स्क्रीन से ब्रेक लें और आज रात नींद को प्राथमिकता दें।" if language == "hi" else "Your burnout risk is elevated. Consider taking a break from screens and prioritizing sleep tonight."
        interventions.append({
            "priority": "high",
            "suggestion": suggestion,
            **_data_strength(10, language)
        })

    if risk_scores.get("focus_score", 100) < 40:
        suggestion = "आपका ध्यान स्कोर कम है। स्क्रीन समय कम करें और कम से कम 7 घंटे सोने की कोशिश करें।" if language == "hi" else "Your focus score is low. Try reducing screen time and getting at least 7 hours of sleep."
        interventions.append({
            "priority": "moderate",
            "suggestion": suggestion,
            **_data_strength(10, language)
        })

    for drift in drifts:
        if drift.get("direction") == "up" and ("Screen Time" in drift.get("metric", "") or "स्क्रीन" in drift.get("metric", "")):
            suggestion = "आपका स्क्रीन समय सामान्य से ज्यादा है। बीच-बीच में ब्रेक लें।" if language == "hi" else "Your screen time is higher than usual. Consider taking regular breaks."
            interventions.append({
                "priority": "moderate",
                "suggestion": suggestion,
                **_data_strength(8, language)
            })
            break

    for drift in drifts:
        if drift.get("direction") == "down" and ("Sleep" in drift.get("metric", "") or "नींद" in drift.get("metric", "")):
            suggestion = "आपकी नींद हाल ही में कम हो रही है। एक निश्चित सोने का समय तय करें।" if language == "hi" else "Your sleep has been declining recently. Try setting a consistent bedtime."
            interventions.append({
                "priority": "moderate",
                "suggestion": suggestion,
                **_data_strength(8, language)
            })
            break

    return interventions


def compute_weekly_summary(logs: List[BehaviorLog], language: str = "en") -> Dict[str, Any]:
    """F7: 7-day summary narrative."""
    today = date.today()
    week_ago = today - timedelta(days=7)
    recent = [l for l in logs if l.date and l.date >= week_ago]

    if not recent:
        msg = "साप्ताहिक सारांश बनाने के लिए पर्याप्त डेटा नहीं है।" if language == "hi" else "Not enough data to generate a weekly summary yet."
        return {"summary": msg, "has_data": False}

    avg_mood = _safe_avg([l.mood for l in recent])
    avg_sleep = _safe_avg([l.sleep_hours for l in recent])
    avg_screen = _safe_avg([l.screen_time for l in recent])
    exercise_days = sum(1 for l in recent if l.exercise)
    total_days = len(recent)

    # Determine trends
    sorted_recent = sorted(recent, key=lambda l: l.date)
    moods = [l.mood for l in sorted_recent]
    sleeps = [l.sleep_hours for l in sorted_recent]
    screens = [l.screen_time for l in sorted_recent]

    def trend_word(values):
        if len(values) < 2:
            return "stable"
        first_half = _safe_avg(values[:len(values)//2])
        second_half = _safe_avg(values[len(values)//2:])
        diff = second_half - first_half
        if abs(diff) < 0.3:
            return "stable"
        return "improving" if diff > 0 else "declining"

    mood_trend = trend_word(moods)
    sleep_trend = trend_word(sleeps)
    screen_trend = trend_word(screens)

    # Build summary sentence
    if language == "hi":
        mood_word = {"improving": "सुधर रही", "declining": "गिर रही", "stable": "स्थिर"}[mood_trend]
        parts = [f"पिछले {total_days} दिनों में, आपकी मनोदशा {mood_word} है (औसत {avg_mood:.1f}/10)"]

        sleep_word = {"improving": "सुधर रही", "declining": "गिर रही", "stable": "स्थिर"}[sleep_trend]
        parts.append(f"नींद {sleep_word} है (औसत {avg_sleep:.1f} घंटे)")

        screen_word = {"improving": "बढ़ रहा", "declining": "कम हो रहा", "stable": "स्थिर"}[screen_trend]
        parts.append(f"और स्क्रीन समय {screen_word} है (औसत {avg_screen:.1f} घंटे)")

        if exercise_days > 0:
            parts.append(f"आपने {total_days} में से {exercise_days} दिन व्यायाम किया।")
    else:
        parts = []
        parts.append(f"Over the past {total_days} days, your mood has been {mood_trend} (avg {avg_mood:.1f}/10)")

        if sleep_trend == "declining":
            parts.append(f"sleep is declining (avg {avg_sleep:.1f}h)")
        elif sleep_trend == "improving":
            parts.append(f"sleep is improving (avg {avg_sleep:.1f}h)")
        else:
            parts.append(f"sleep has remained steady (avg {avg_sleep:.1f}h)")

        if screen_trend == "improving":
            # For screen, "improving" means increasing which is bad
            parts.append(f"and screen time is increasing (avg {avg_screen:.1f}h)")
        elif screen_trend == "declining":
            parts.append(f"and screen time is decreasing (avg {avg_screen:.1f}h)")
        else:
            parts.append(f"and screen time is stable (avg {avg_screen:.1f}h)")

        if exercise_days > 0:
            parts.append(f"You exercised on {exercise_days} out of {total_days} days.")

    summary = ", ".join(parts[:3]) + ". " + (parts[3] if len(parts) > 3 else "")

    return {
        "summary": summary.strip(),
        "avg_mood": round(avg_mood, 1),
        "avg_sleep": round(avg_sleep, 1),
        "avg_screen": round(avg_screen, 1),
        "exercise_days": exercise_days,
        "total_days": total_days,
        "mood_trend": mood_trend,
        "sleep_trend": sleep_trend,
        "screen_trend": screen_trend,
        "has_data": True,
        **_data_strength(total_days, language)
    }


def compute_stress_forecast(logs: List[BehaviorLog], language: str = "en") -> Dict[str, Any]:
    """Phase 5: Cognitive Stress Simulator. Predicts tomorrow's stress level based on recent trends."""
    if len(logs) < 5:
        msg = "सटीक तनाव अनुमान के लिए पर्याप्त डेटा इकट्ठा हो रहा है (कम से कम 5 दिन)।" if language == "hi" else "Collecting enough data (min 5 days) to generate accurate stress predictions."
        return {
            "has_data": False,
            "message": msg
        }
        
    sorted_logs = sorted(logs, key=lambda l: l.date if l.date else date.min)
    recent = sorted_logs[-5:]  # Use last 5 logs for the recent window
    
    # Step 1: Identify Recent Behavior Window
    recent_sleep = _safe_avg([l.sleep_hours for l in recent])
    recent_screen = _safe_avg([l.screen_time for l in recent])
    recent_mood = _safe_avg([l.mood for l in recent])
    
    # Step 2 & 3: Apply Weighted Influence Model (Sleep 40%, Screen 30%, Mood 30%)
    sleep_risk = max(0, min(100, (8.0 - recent_sleep) * 25))
    screen_risk = max(0, min(100, (recent_screen - 2.0) * 16.6))
    mood_risk = max(0, min(100, (10.0 - recent_mood) * 16.6))
    
    # Step 4: Generate Stress Prediction Score
    predicted_score = int((sleep_risk * 0.40) + (screen_risk * 0.30) + (mood_risk * 0.30))
    predicted_score = max(0, min(100, predicted_score))
    
    if predicted_score <= 30:
        risk_level = "Low"
    elif predicted_score <= 70:
        risk_level = "Moderate"
    else:
        risk_level = "High"
        
    # Step 5: Confidence Calculation
    total_days = len(logs)
    if total_days >= 10:
        confidence = "High"
        conf_pct = 85
    elif total_days >= 6:
        confidence = "Moderate"
        conf_pct = 65
    else:
        confidence = "Low"
        conf_pct = 40
        
    # Step 6: Generate Natural Language Insights
    insights = []
    if language == "hi":
        if sleep_risk > 50:
            insights.append("हाल की नींद की कमी से तनाव बढ़ने की संभावना है।")
        elif sleep_risk < 20:
            insights.append("बेहतर नींद के पैटर्न से कल तनाव कम होने की संभावना है।")
            
        if screen_risk > 50:
            insights.append("स्क्रीन समय के रुझान से दिमागी थकान बढ़ रही है।")
        elif screen_risk < 20:
            insights.append("कम स्क्रीन समय तनाव के अनुमान को कम रखने में मदद कर रहा है।")
            
        if mood_risk > 50:
            insights.append("गिरती मनोदशा के रुझान तनाव के प्रति अधिक संवेदनशीलता बताते हैं।")
            
        if not insights:
            insights.append("आपके संतुलित व्यवहार पैटर्न कल के लिए स्थिर तनाव स्तर दर्शाते हैं।")
    else:
        if sleep_risk > 50:
            insights.append("Your recent sleep deficit is likely to increase stress.")
        elif sleep_risk < 20:
            insights.append("Improved sleep patterns suggest a potential reduction in stress tomorrow.")
            
        if screen_risk > 50:
            insights.append("Screen time trends show rising cognitive load.")
        elif screen_risk < 20:
            insights.append("Lower screen time is contributing to a lower predicted stress level.")
            
        if mood_risk > 50:
            insights.append("Declining mood trends indicate higher emotional vulnerability to stress.")
            
        if not insights:
            insights.append("Your balanced behavioral trends suggest stable and optimal stress levels tomorrow.")
        
    # Step 7: Scenario-Based Simulation (What If)
    what_if = ""
    if language == "hi":
        if sleep_risk >= screen_risk and recent_sleep < 7.5:
            improved_sleep_risk = max(0, min(100, (8.0 - 7.5) * 25))
            improved_score = int((improved_sleep_risk * 0.40) + (screen_risk * 0.30) + (mood_risk * 0.30))
            what_if = f"नींद को 7.5 घंटे तक बढ़ाने से भविष्य का तनाव {improved_score}% तक कम हो सकता है।"
        elif recent_screen > 3.0:
            improved_screen_risk = max(0, min(100, (3.0 - 2.0) * 16.6))
            improved_score = int((sleep_risk * 0.40) + (improved_screen_risk * 0.30) + (mood_risk * 0.30))
            what_if = f"स्क्रीन समय 3 घंटे तक कम करने से भविष्य का तनाव {improved_score}% तक कम हो सकता है।"
        else:
            what_if = "अपनी मौजूदा आदतें बनाए रखने से तनाव लगातार कम रहेगा।"
    else:
        if sleep_risk >= screen_risk and recent_sleep < 7.5:
            improved_sleep_risk = max(0, min(100, (8.0 - 7.5) * 25))
            improved_score = int((improved_sleep_risk * 0.40) + (screen_risk * 0.30) + (mood_risk * 0.30))
            what_if = f"Improving sleep to 7.5 hours may reduce your future stress to {improved_score}%."
        elif recent_screen > 3.0:
            improved_screen_risk = max(0, min(100, (3.0 - 2.0) * 16.6))
            improved_score = int((sleep_risk * 0.40) + (improved_screen_risk * 0.30) + (mood_risk * 0.30))
            what_if = f"Reducing screen time to 3 hours may drop your future stress to {improved_score}%."
        else:
            what_if = "Maintaining your current habits will likely keep stress consistently low."

    return {
        "has_data": True,
        "predicted_score": predicted_score,
        "risk_level": _risk_label(risk_level, language),
        "confidence": _risk_label(confidence, language),
        "confidence_pct": conf_pct if 'conf_pct' in locals() else 0,
        "insights": insights[:3],
        "what_if": what_if
    }


def compute_full_intelligence(db: Session, user_id: int, language: str = "en") -> Dict[str, Any]:
    """Master function: computes all 7 features in one pass."""
    logs = db.query(BehaviorLog).filter(BehaviorLog.user_id == user_id).all()
    preds = db.query(Prediction).filter(Prediction.user_id == user_id).all()

    data_points = len(logs)

    # F1: Risk Scores
    risk_scores = compute_risk_scores(logs, preds, language)

    # F2 + F5: Enhanced Correlations (only if >= 5 data points)
    enhanced_correlations = compute_enhanced_correlations(db, user_id, language) if data_points >= 5 else []

    # F3: Emerging Patterns (3-4 data points, or as supplement)
    emerging_patterns = compute_emerging_patterns(logs, preds, language) if data_points >= 3 else []

    # F4: Behavioral Drift (>= 5 data points)
    drifts = compute_behavioral_drift(logs, language) if data_points >= 5 else []

    # F6: Smart Interventions
    interventions = compute_smart_interventions(risk_scores, drifts, language)

    # F7: Weekly Summary
    weekly_summary = compute_weekly_summary(logs, language)

    # Phase 5: Cognitive Stress Simulator
    stress_forecast = compute_stress_forecast(logs, language)

    return {
        "data_points": data_points,
        "risk_scores": risk_scores,
        "enhanced_correlations": enhanced_correlations,
        "emerging_patterns": emerging_patterns,
        "behavioral_drifts": drifts,
        "smart_interventions": interventions,
        "weekly_summary": weekly_summary,
        "stress_forecast": stress_forecast
    }
