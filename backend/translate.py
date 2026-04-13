import json

def translate_insight_file():
    target_path = r"d:\Projects\Cognify AI\backend\app\services\insight_engine.py"
    with open(target_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # We will redefine the fallback generation by inserting a Hindi map, but we'll do it using regex or simple replace
    if "def _translate_if_hindi(text_list, language):" not in content:
        translation_code = '''
def _translate_if_hindi(texts, language):
    if language != "hi": return texts
    m = {
        "Critical sleep deficit detected. You're getting less than 5 hours of sleep, which significantly increases stress hormones and impairs cognitive function.": "अत्यधिक कम नींद पाई गई। आप 5 घंटे से भी कम सो रहे हैं, जो तनाव बढ़ाता है और मानसिक क्षमता को कमजोर करता है।",
        "Aim for 7-9 hours of sleep. Set a bedtime alarm 30 minutes before your target sleep time.": "7-9 घंटे की नींद लेने का लक्ष्य रखें। सोने के समय से 30 मिनट पहले का अलार्म सेट करें।",
        "Your sleep is below recommended levels. Sleep deprivation compounds daily, leading to increased irritability and reduced focus.": "आपकी नींद अनुशंसित स्तर से कम है। अपर्याप्त नींद से चिड़चिड़ापन बढ़ता है और ध्यान कम होता है।",
        "Try reducing caffeine intake after 2 PM and establish a consistent sleep schedule.": "दोपहर 2 बजे के बाद कैफीन कम करें और सोने का नियमित समय बनाएं।",
        "Excellent sleep duration! Your body is getting adequate recovery time.": "बेहतरीन नींद! आपके शरीर को आराम करने और ठीक होने का पूरा समय मिल रहा है।",
        "Your sleep is adequate but could be improved for optimal wellness.": "आपकी नींद पर्याप्त है, लेकिन बेहतर स्वास्थ्य के लिए इसे और बेहतर किया जा सकता है।",
        "Use the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds.": "20-20-20 नियम का प्रयोग करें: हर 20 मिनट पर, 20 फीट दूर किसी चीज को 20 सेकंड के लिए देखें।",
        "Set app timers and designate screen-free hours, especially before bed.": "ऐप टाइमर सेट करें और विशेष रूप से सोने से पहले स्क्रीन-मुक्त समय तय करें।",
        "Try replacing 1 hour of screen time with a walk or reading a physical book.": "1 घंटे का स्क्रीन समय सैर या किताब पढ़ने से बदलें।",
        "Great screen time management. Low screen exposure supports better sleep and mood.": "स्क्रीन समय का शानदार प्रबंधन! कम स्क्रीन समय बेहतर नींद और मनोदशा का समर्थन करता है।",
        "Consider talking to someone you trust about how you're feeling.": "आप कैसा महसूस कर रहे हैं, इसके बारे में किसी भरोसेमंद व्यक्ति से बात करने पर विचार करें।",
        "Practice gratitude journaling — write down 3 things you're thankful for today.": "आभार पत्रिका लिखें - आज की 3 चीजों को लिखें जिनके लिए आप आभारी हैं।",
        "Try a 10-minute mindfulness meditation or deep breathing exercise.": "10 मिनट का ध्यान या गहरी सांस लेने का व्यायाम करें।",
        "Even 15 minutes of brisk walking can significantly improve your mood and stress levels.": "15 मिनट की तेज सैर भी आपके मूड को काफी हद तक सुधार सकती है।",
        "Great job exercising today! Physical activity is a powerful stress reducer.": "आज व्यायाम करने के लिए बढ़िया! शारीरिक गतिविधि एक शक्तिशाली तनाव कम करने वाला उपाय है।",
        "PRIORITY: Break this negative cycle by starting with just one change — a short walk or earlier bedtime.": "प्राथमिकता: केवल एक बदलाव (छोटी सैर या जल्दी सोना) से इस नकारात्मक चक्र को तोड़ें।",
        "Your low mood appears correlated with insufficient sleep. Sleep quality directly impacts emotional regulation and resilience.": "आपका खराब मूड अपर्याप्त नींद से जुड़ा है। नींद की गुणवत्ता सीधे भावनात्मक नियंत्रण को प्रभावित करती है।",
        "PATTERN: Your sleep has been consistently decreasing this week. This is a primary driver for rising stress levels.": "पैटर्न: इस सप्ताह आपकी नींद लगातार कम हो रही है, जिससे तनाव बढ़ रहा है।",
        "PATTERN: Your screen time is on a steady upward trend. Excessive digital exposure may be draining your mental energy.": "पैटर्न: आपका स्क्रीन समय लगातार बढ़ रहा है। अत्यधिक डिजिटल उपयोग आपकी मानसिक ऊर्जा को खत्म कर सकता है।",
        "DECLINING TREND: Your mood has been consistently decreasing. It may be time to reassess your daily routine.": "गिरावट: आपकी मनोदशा लगातार कम हो रही है। अपनी दिनचर्या का पुनर्मूल्यांकन करने का समय आ गया है।",
        "THERAPY SUGGESTION: Take 5 minutes for a guided breathing exercise right now.": "सुझाव: अभी 5 मिनट के लिए गहरी सांस लेने का व्यायाम करें।",
        "THERAPY SUGGESTION: Step away from all digital devices for at least 15 minutes to reset.": "सुझाव: कम से कम 15 मिनट के लिए सभी डिजिटल उपकरणों से दूर रहें।",
        "THERAPY SUGGESTION: Write down exactly what is worrying you in your reflection journal.": "सुझाव: अपनी डायरी में ठीक-ठीक लिखें कि आपको कौन सी बात परेशान कर रही है।"
    }
    
    # We try exact match first, then dynamic matching for templated strings
    res = []
    for t in texts:
        if t in m: res.append(m[t])
        elif "Excessive screen time detected" in t:
            res.append(f"अत्यधिक स्क्रीन समय पाया गया ({t.split('(')[1].split('h')[0]} घंटे)। इससे आँखों पर जोर, नींद में दिक्कत और चिंता बढ़ती है।")
        elif "Your screen time (" in t:
            res.append(f"आपका स्क्रीन समय ({t.split('(')[1].split('h')[0]} घंटे) आदर्श से अधिक है। कृपया इसे कम करें।")
        elif "Your reported mood is low (" in t:
            res.append(f"आपका मूड काफी खराब है ({t.split('(')[1].split(')')[0]})। लंबे समय तक ऐसा रहना अतिरिक्त समर्थन की आवश्यकता को दर्शा सकता है।")
        elif "Your mood is neutral (" in t:
            res.append(f"आपका मूड सामान्य है ({t.split('(')[1].split(')')[0]})। कुछ सकारात्मक कार्यों से आपकी भावनात्मक स्थिति बेहतर हो सकती है।")
        elif "You're in a great mood (" in t:
            res.append(f"आप बहुत अच्छे मूड में हैं ({t.split('(')[1].split(')')[0]})! इन सकारात्मक आदतों को बनाए रखें।")
        elif "No exercise logged today." in t:
            res.append("आज कोई व्यायाम नहीं किया गया। शारीरिक गतिविधि प्राकृतिक रूप से तनाव कम करती है।")
        elif "PATTERN ALERT: The combination of poor sleep" in t:
            res.append("अलर्ट: कम नींद, ज्यादा स्क्रीन और व्यायाम की कमी एक उच्च-तनाव लाती है जो बर्नआउट का कारण बन सकता है।")
        elif "TREND: Your average sleep over the past week is" in t:
            res.append(f"रुझान: पिछले सप्ताह आपकी औसत नींद {t.split('is ')[1].split('h')[0]} घंटे है। आप थकावट महसूस कर सकते हैं।")
        elif "TREND: Your average mood over the past week is" in t:
            res.append(f"रुझान: पिछले सप्ताह आपका औसत मूड {t.split('is ')[1].split('/')[0]}/10 रहा। विचार करें क्या बाहरी कारक आपको प्रभावित कर रहे हैं।")
        else: res.append(t)
    return res
'''
        content = content.replace("def _generate_summary", translation_code + "\ndef _generate_summary")

    # Add the translation wrapper to the returned dictionary
    content = content.replace(
        '''    return {
        "insights": insights,
        "overall_risk": risk_level,
        "summary": summary,
        "recommendations": recommendations
    }''',
        '''    return {
        "insights": _translate_if_hindi(insights, language),
        "overall_risk": get_risk_level(stress_score) if language != "hi" else {"Low": "कम", "Moderate": "मध्यम", "High": "उच्च", "Critical": "गंभीर"}.get(risk_level, risk_level),
        "summary": summary,
        "recommendations": _translate_if_hindi(recommendations, language)
    }'''
    )

    if "_generate_summary(stress_score: float, risk_level: str, sleep_hours: float, mood: int, exercise: bool, language: str = 'en') -> str:" not in content:
        content = content.replace(
            "def _generate_summary(stress_score: float, risk_level: str, sleep_hours: float, mood: int, exercise: bool) -> str:",
            "def _generate_summary(stress_score: float, risk_level: str, sleep_hours: float, mood: int, exercise: bool, language: str = 'en') -> str:"
        ).replace(
            "summary = _generate_summary(stress_score, risk_level, sleep_hours, mood, exercise)",
            "summary = _generate_summary(stress_score, risk_level, sleep_hours, mood, exercise, language)"
        )

        content = content.replace(
            '''    if risk_level == "Low":
        return (
            f"Your wellness indicators look good! Your stress score is {stress_score:.0f}/100 ({risk_level} risk). "
            f"Keep maintaining your current healthy habits."
        )''',
            '''    if risk_level == "Low" or risk_level == "कम":
        if language == "hi": return f"आपके स्वास्थ्य संकेतक अच्छे हैं! आपका तनाव {stress_score:.0f}/100 (कम जोखिम) है। अपनी स्वस्थ आदतें बनाए रखें।"
        return (
            f"Your wellness indicators look good! Your stress score is {stress_score:.0f}/100 (Low risk). "
            f"Keep maintaining your current healthy habits."
        )'''
        ).replace(
            '''    elif risk_level == "Moderate":
        return (
            f"Your stress score is {stress_score:.0f}/100 ({risk_level} risk). "
            f"Some areas need attention, but overall you're managing well. "
            f"Focus on the recommendations below to improve."
        )''',
            '''    elif risk_level == "Moderate" or risk_level == "मध्यम":
        if language == "hi": return f"आपका तनाव {stress_score:.0f}/100 (मध्यम जोखिम) है। कुछ क्षेत्रों पर ध्यान देने की आवश्यकता है, लेकिन कुल मिलाकर आप अच्छा कर रहे हैं। नीचे दिए सुझावों पर ध्यान दें।"
        return (
            f"Your stress score is {stress_score:.0f}/100 (Moderate risk). "
            f"Some areas need attention, but overall you're managing well. "
            f"Focus on the recommendations below to improve."
        )'''
        ).replace(
            '''    elif risk_level == "High":
        return (
            f"Your stress score is {stress_score:.0f}/100 ({risk_level} risk). "
            f"Multiple factors are contributing to elevated stress. "
            f"Please prioritize self-care and consider the recommendations carefully."
        )''',
            '''    elif risk_level == "High" or risk_level == "उच्च":
        if language == "hi": return f"आपका तनाव {stress_score:.0f}/100 (उच्च जोखिम) है। कई कारण तनाव बढ़ा रहे हैं। कृपया आत्म-देखभाल को प्राथमिकता दें और सुझावों पर सावधानी से विचार करें।"
        return (
            f"Your stress score is {stress_score:.0f}/100 (High risk). "
            f"Multiple factors are contributing to elevated stress. "
            f"Please prioritize self-care and consider the recommendations carefully."
        )'''
        ).replace(
            '''    else:
        return (
            f"Your stress score is {stress_score:.0f}/100 ({risk_level} risk). "
            f"This indicates significant stress accumulation. "
            f"Immediate lifestyle adjustments are strongly recommended. "
            f"If you're feeling overwhelmed, please reach out to a mental health professional."
        )''',
            '''    else:
        if language == "hi": return f"आपका तनाव {stress_score:.0f}/100 (गंभीर जोखिम) है। यह महत्वपूर्ण तनाव संचय को दर्शाता है। जीवनशैली में तत्काल बदलाव करें। अधिक परेशानी हो तो विशेषज्ञ से बात करें।"
        return (
            f"Your stress score is {stress_score:.0f}/100 (Critical risk). "
            f"This indicates significant stress accumulation. "
            f"Immediate lifestyle adjustments are strongly recommended. "
            f"If you're feeling overwhelmed, please reach out to a mental health professional."
        )'''
        )

    with open(target_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("Patched insight_engine.py successfully.")

translate_insight_file()
