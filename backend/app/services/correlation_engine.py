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

def compute_correlations(db: Session, user_id: int, language: str = "en") -> List[Dict]:
    """
    Computes correlations for Sleep vs Mood, Screen Time vs Stress, Activity vs Mood.
    Requires at least 5 total data points to generate any insights.
    """
    # Fetch logs
    logs = db.query(BehaviorLog).filter(BehaviorLog.user_id == user_id).all()
    
    if len(logs) < 5:
        title = "Insufficient Data"
        expl = f"We need at least 5 days of logged data to analyze your behavioral correlations. You currently have {len(logs)}."
        conf = "Low"
        if language == "hi":
            title = "अपर्याप्त डेटा"
            expl = f"आपके व्यवहारिक सहसंबंधों का विश्लेषण करने के लिए कम से कम 5 दिनों का डेटा आवश्यक है। वर्तमान में आपके पास {len(logs)} दिन का डेटा है।"
            conf = "कम"
        return [{
            "title": title,
            "explanation": expl,
            "confidence_level": conf
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
                title = "Sleep & Mood"
                expl = f"Lower sleep (<6h) correlates with reduced mood (avg {low_sleep_avg:.1f}/10 vs {good_sleep_avg:.1f}/10)."
                if language == "hi":
                    conf = "उच्च" if num_samples >= 15 else "मध्यम"
                    title = "नींद और मनोदशा"
                    expl = f"कम नींद (<6h) खराब मूड से संबंधित है (औसत {low_sleep_avg:.1f}/10 बनाम {good_sleep_avg:.1f}/10)।"
                correlations.append({
                    "title": title,
                    "explanation": expl,
                    "confidence_level": conf
                })
            elif low_sleep_avg > good_sleep_avg + 0.5:
                # Paradoxical
                num_samples = len(sleep_groups["<6"]) + len(good_sleep)
                conf = "Moderate" if num_samples >= 10 else "Low"
                title = "Sleep & Mood Profile"
                expl = f"Paradoxically, mood averages higher ({low_sleep_avg:.1f}/10) on low sleep days."
                if language == "hi":
                    conf = "मध्यम" if num_samples >= 10 else "कम"
                    title = "नींद और मनोदशा प्रोफ़ाइल"
                    expl = f"कम नींद वाले दिनों में आपका मूड औसत से अधिक ({low_sleep_avg:.1f}/10) रहता है।"
                correlations.append({
                    "title": title,
                    "explanation": expl,
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
                title = "Screen Time & Stress"
                expl = f"High screen time (>6h) correlates with higher stress ({high_screen_avg:.0f}% vs {lower_screen_avg:.0f}%)."
                if language == "hi":
                    conf = "उच्च" if num_samples >= 15 else "मध्यम"
                    title = "स्क्रीन समय और तनाव"
                    expl = f"अत्यधिक स्क्रीन समय (>6h) उच्च तनाव ({high_screen_avg:.0f}% बनाम {lower_screen_avg:.0f}%) से जुड़ा है।"
                correlations.append({
                    "title": title,
                    "explanation": expl,
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
            title = "Activity & Mood"
            expl = f"Activity boosts your mood (avg {avg_act:.1f}/10 vs {avg_no_act:.1f}/10)."
            if language == "hi":
                conf = "उच्च" if num_samples >= 15 else "मध्यम"
                title = "गतिविधि और मनोदशा"
                expl = f"गतिविधि आपके मूड को बेहतर बनाती है (औसत {avg_act:.1f}/10 बनाम {avg_no_act:.1f}/10)।"
            correlations.append({
                "title": title,
                "explanation": expl,
                "confidence_level": conf
            })

    # 4. Social Time vs Stress
    social_stress: Dict[str, List[float]] = {"<1": [], "1-2": [], ">2": []}
    for log in logs:
        if log.date in stress_map and log.social_time is not None:
            if log.social_time < 1: social_stress["<1"].append(stress_map[log.date])
            elif log.social_time <= 2: social_stress["1-2"].append(stress_map[log.date])
            else: social_stress[">2"].append(stress_map[log.date])

    if social_stress[">2"]:
        high_soc_avg = sum(social_stress[">2"]) / len(social_stress[">2"])
        lower_soc = social_stress["<1"] + social_stress["1-2"]
        if lower_soc:
            lower_soc_avg = sum(lower_soc) / len(lower_soc)
            if high_soc_avg > lower_soc_avg + 5:
                num_samples = len(social_stress[">2"]) + len(lower_soc)
                conf = "High" if num_samples >= 15 else "Moderate"
                title = "Social Media & Stress"
                expl = f"Social media (>2h) correlates with higher stress ({high_soc_avg:.0f}% vs {lower_soc_avg:.0f}%)."
                if language == "hi":
                    conf = "उच्च" if num_samples >= 15 else "मध्यम"
                    title = "सोशल मीडिया और तनाव"
                    expl = f"सोशल मीडिया (>2h) उच्च तनाव ({high_soc_avg:.0f}% बनाम {lower_soc_avg:.0f}%) से जुड़ा है।"
                correlations.append({
                    "title": title,
                    "explanation": expl,
                    "confidence_level": conf
                })

    # 5. Productivity vs Mood
    prod_mood: Dict[str, List[float]] = {"<2": [], "2-5": [], ">5": []}
    for log in logs:
        # Avoid zeros showing as highly productive if missing logic defaults to 0
        if log.productivity_time is not None and log.productivity_time > 0:
            if log.productivity_time < 2: prod_mood["<2"].append(log.mood)
            elif log.productivity_time <= 5: prod_mood["2-5"].append(log.mood)
            else: prod_mood[">5"].append(log.mood)

    if prod_mood[">5"]:
        high_prod_avg = sum(prod_mood[">5"]) / len(prod_mood[">5"])
        lower_prod = prod_mood["<2"] + prod_mood["2-5"]
        if lower_prod:
            lower_prod_avg = sum(lower_prod) / len(lower_prod)
            if high_prod_avg > lower_prod_avg + 1.0:
                num_samples = len(prod_mood[">5"]) + len(lower_prod)
                conf = "High" if num_samples >= 15 else "Moderate"
                title = "Productivity & Mood"
                expl = f"High productivity (>5h) correlates with better mood ({high_prod_avg:.1f}/10 vs {lower_prod_avg:.1f}/10)."
                if language == "hi":
                    conf = "उच्च" if num_samples >= 15 else "मध्यम"
                    title = "उत्पादकता और मनोदशा"
                    expl = f"उच्च उत्पादकता (>5h) बेहतर मूड ({high_prod_avg:.1f}/10 बनाम {lower_prod_avg:.1f}/10) से जुड़ी है।"
                correlations.append({
                    "title": title,
                    "explanation": expl,
                    "confidence_level": conf
                })

    # If no correlations were found despite having >5 points
    if not correlations:
        title = "No Strong Correlations Yet"
        expl = "We analyzed your data but didn't find any statistically significant correlations between your sleep, screen time, activity, and your mood or stress. Keep logging to discover subtle trends!"
        conf = "None"
        if language == "hi":
            title = "अभी तक कोई स्पष्ट सहसंबंध नहीं"
            expl = "हमने आपके डेटा का विश्लेषण किया लेकिन आपकी नींद, स्क्रीन समय, गतिविधि और आपके मूड या तनाव के बीच कोई महत्वपूर्ण सहसंबंध नहीं मिला। कुछ समय और लॉग करें!"
            conf = "कोई नहीं"
        return [{
            "title": title,
            "explanation": expl,
            "confidence_level": conf
        }]

    return correlations
