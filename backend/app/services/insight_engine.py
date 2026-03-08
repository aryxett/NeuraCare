"""
AI Insight Engine
Generates human-readable wellness insights from behavioral data and predictions.
"""

from typing import Optional


def get_risk_level(stress_score: float) -> str:
    """Categorize stress score into risk levels."""
    if stress_score < 25:
        return "Low"
    elif stress_score < 50:
        return "Moderate"
    elif stress_score < 75:
        return "High"
    else:
        return "Critical"


def generate_insights(
    sleep_hours: float,
    screen_time: float,
    mood: int,
    exercise: bool,
    stress_score: float,
    recent_logs: Optional[list] = None
) -> dict:
    """
    Generate AI-driven wellness insights based on current data and historical patterns.

    Returns a dict with: insights, overall_risk, summary, recommendations
    """
    insights = []
    recommendations = []
    risk_level = get_risk_level(stress_score)

    # ── Sleep Analysis ──
    if sleep_hours < 5:
        insights.append(
            "⚠️ Critical sleep deficit detected. You're getting less than 5 hours of sleep, "
            "which significantly increases stress hormones and impairs cognitive function."
        )
        recommendations.append("Aim for 7-9 hours of sleep. Set a bedtime alarm 30 minutes before your target sleep time.")
    elif sleep_hours < 6:
        insights.append(
            "😴 Your sleep is below recommended levels. Sleep deprivation compounds daily, "
            "leading to increased irritability and reduced focus."
        )
        recommendations.append("Try reducing caffeine intake after 2 PM and establish a consistent sleep schedule.")
    elif sleep_hours >= 8:
        insights.append("✅ Excellent sleep duration! Your body is getting adequate recovery time.")
    else:
        insights.append("😐 Your sleep is adequate but could be improved for optimal wellness.")

    # ── Screen Time Analysis ──
    if screen_time > 10:
        insights.append(
            "📱 Excessive screen time detected ({:.1f}h). Prolonged screen exposure is linked to "
            "eye strain, disrupted sleep patterns, and increased anxiety.".format(screen_time)
        )
        recommendations.append("Use the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds.")
        recommendations.append("Set app timers and designate screen-free hours, especially before bed.")
    elif screen_time > 7:
        insights.append(
            "📱 Your screen time ({:.1f}h) is higher than ideal. Consider reducing non-essential usage.".format(screen_time)
        )
        recommendations.append("Try replacing 1 hour of screen time with a walk or reading a physical book.")
    elif screen_time <= 4:
        insights.append("✅ Great screen time management. Low screen exposure supports better sleep and mood.")

    # ── Mood Analysis ──
    if mood <= 3:
        insights.append(
            "🔴 Your reported mood is low ({}/10). Persistent low mood may indicate "
            "the need for additional support.".format(mood)
        )
        recommendations.append("Consider talking to someone you trust about how you're feeling.")
        recommendations.append("Practice gratitude journaling — write down 3 things you're thankful for today.")
    elif mood <= 5:
        insights.append(
            "😐 Your mood is neutral ({}/10). Small positive actions can help boost your emotional state.".format(mood)
        )
        recommendations.append("Try a 10-minute mindfulness meditation or deep breathing exercise.")
    elif mood >= 8:
        insights.append("😊 You're in a great mood ({}/10)! Keep up the positive habits.".format(mood))

    # ── Exercise Analysis ──
    if not exercise:
        insights.append(
            "🏃 No exercise logged today. Physical activity releases endorphins and is one of the "
            "most effective natural stress reducers."
        )
        recommendations.append("Even 15 minutes of brisk walking can significantly improve your mood and stress levels.")
    else:
        insights.append("💪 Great job exercising today! Physical activity is a powerful stress reducer.")

    # ── Compound Pattern Analysis ──
    if sleep_hours < 6 and screen_time > 8 and not exercise:
        insights.append(
            "🚨 PATTERN ALERT: The combination of poor sleep, high screen time, and no exercise "
            "creates a high-risk stress environment. This pattern often leads to burnout."
        )
        recommendations.insert(0, "PRIORITY: Break this negative cycle by starting with just one change — a short walk or earlier bedtime.")

    if sleep_hours < 6 and mood <= 4:
        insights.append(
            "🔗 Your low mood appears correlated with insufficient sleep. Sleep quality directly "
            "impacts emotional regulation and resilience."
        )

    # ── Historical Pattern Analysis ──
    if recent_logs and len(recent_logs) >= 3:
        recent_sleep = [log.sleep_hours for log in recent_logs[-7:]]
        recent_moods = [log.mood for log in recent_logs[-7:]]
        avg_sleep = sum(recent_sleep) / len(recent_sleep)
        avg_mood = sum(recent_moods) / len(recent_moods)

        if avg_sleep < 6:
            insights.append(
                "📊 TREND: Your average sleep over the past week is {:.1f}h. "
                "You may be experiencing accumulated fatigue.".format(avg_sleep)
            )
        if avg_mood < 5:
            insights.append(
                "📊 TREND: Your average mood over the past week is {:.1f}/10. "
                "Consider if external factors are affecting your wellbeing.".format(avg_mood)
            )

        # ── Stress Pattern Detection ──
        if len(recent_sleep) >= 3:
            # Check for decreasing sleep trend
            if all(recent_sleep[i] >= recent_sleep[i+1] for i in range(len(recent_sleep)-1)):
                 insights.append("📉 PATTERN: Your sleep has been consistently decreasing this week. This is a primary driver for rising stress levels.")
            
            # Check for increasing screen time trend
            recent_screen = [log.screen_time for log in recent_logs[-7:]]
            if len(recent_screen) >= 3 and all(recent_screen[i] <= recent_screen[i+1] for i in range(len(recent_screen)-1)):
                 insights.append("📈 PATTERN: Your screen time is on a steady upward trend. Excessive digital exposure may be draining your mental energy.")

        # Detect declining mood trends
        if len(recent_moods) >= 3:
            if all(recent_moods[i] >= recent_moods[i + 1] for i in range(min(3, len(recent_moods) - 1))):
                insights.append(
                    "📉 DECLINING TREND: Your mood has been consistently decreasing. "
                    "It may be time to reassess your daily routine."
                )

    # ── AI Micro Therapy Suggestions ──
    if risk_level in ["High", "Critical"]:
        recommendations.append("✨ THERAPY SUGGESTION: Take 5 minutes for a guided breathing exercise right now.")
        recommendations.append("✨ THERAPY SUGGESTION: Step away from all digital devices for at least 15 minutes to reset.")
    elif mood <= 4:
        recommendations.append("✨ THERAPY SUGGESTION: Write down exactly what is worrying you in your reflection journal.")

    # ── Generate Summary ──
    summary = _generate_summary(stress_score, risk_level, sleep_hours, mood, exercise)

    return {
        "insights": insights,
        "overall_risk": risk_level,
        "summary": summary,
        "recommendations": recommendations
    }


def _generate_summary(stress_score: float, risk_level: str, sleep_hours: float, mood: int, exercise: bool) -> str:
    """Generate a concise overall summary."""
    if risk_level == "Low":
        return (
            f"Your wellness indicators look good! Your stress score is {stress_score:.0f}/100 ({risk_level} risk). "
            f"Keep maintaining your current healthy habits."
        )
    elif risk_level == "Moderate":
        return (
            f"Your stress score is {stress_score:.0f}/100 ({risk_level} risk). "
            f"Some areas need attention, but overall you're managing well. "
            f"Focus on the recommendations below to improve."
        )
    elif risk_level == "High":
        return (
            f"Your stress score is {stress_score:.0f}/100 ({risk_level} risk). "
            f"Multiple factors are contributing to elevated stress. "
            f"Please prioritize self-care and consider the recommendations carefully."
        )
    else:
        return (
            f"⚠️ Your stress score is {stress_score:.0f}/100 ({risk_level} risk). "
            f"This indicates significant stress accumulation. "
            f"Immediate lifestyle adjustments are strongly recommended. "
            f"If you're feeling overwhelmed, please reach out to a mental health professional."
        )
