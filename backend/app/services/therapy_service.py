import random

def analyze_sentiment(text: str) -> dict:
    """
    Analyzes text to return sentiment score and emotion classification.
    Returns: {'sentiment': float, 'emotion': str}
    """
    text = text.lower()
    
    # Emotion Keywords
    emotions = {
        "happy": ["happy", "great", "good", "excited", "wonderful", "joy", "peaceful", "calm", "love"],
        "stressed": ["overwhelmed", "stressed", "anxious", "pressure", "tired", "exhausted", "panic", "worry", "busy"],
        "sad": ["sad", "down", "unhappy", "lonely", "miss", "hurt", "crying", "depressed", "hopeless"],
        "neutral": ["okay", "fine", "normal", "average", "busy", "regular"]
    }
    
    scores = {emotion: 0 for emotion in emotions}
    for emotion, keywords in emotions.items():
        for word in keywords:
            if word in text:
                scores[emotion] += 1
                
    # Determine primary emotion
    detected_emotion = max(scores, key=scores.get)
    if scores[detected_emotion] == 0:
        detected_emotion = "neutral"
        
    # Simple sentiment score mapping
    sentiment_map = {
        "happy": 0.8,
        "neutral": 0.1,
        "stressed": -0.4,
        "sad": -0.6
    }
    
    return {
        "sentiment": sentiment_map.get(detected_emotion, 0.0),
        "emotion": detected_emotion
    }

def get_therapy_response(user_input: str) -> str:
    """
    Generates a supportive therapy-style response.
    """
    analysis = analyze_sentiment(user_input)
    emotion = analysis["emotion"]
    
    responses = {
        "happy": [
            "I'm so glad to hear you're feeling positive today! What do you think contributed to this good mood?",
            "That's wonderful! It's important to acknowledge these moments of joy. Keep up the great energy!",
            "It sounds like you're in a great space. How can you carry this feeling with you into tomorrow?"
        ],
        "stressed": [
            "It sounds like you're under a lot of pressure right now. Remember to take a deep breath. Would you like to try a 2-minute breathing exercise?",
            "Overwhelmed feelings are tough. Let's try to break things down into smaller steps. What's one small thing you can control right now?",
            "I hear how much is on your mind. It's okay to step away for a few minutes to clear your head. Your well-being comes first."
        ],
        "sad": [
            "I'm sorry you're feeling down. It's perfectly okay to not be okay. I'm here to listen.",
            "That sounds really difficult. Please be kind to yourself today. Is there one small thing that usually brings you comfort?",
            "I'm here for you. Sometimes just acknowledging these feelings is the first step toward feeling a bit lighter."
        ],
        "neutral": [
            "I'm here to listen. How has your day been overall?",
            "Thank you for sharing that with me. What's on your mind right now?",
            "I see. Is there anything specific you'd like to talk about or explore further?"
        ]
    }
    
    # Add a therapeutic suggestion if stressed
    response = random.choice(responses.get(emotion, responses["neutral"]))
    
    if emotion == "stressed":
        suggestions = [
            "suggestion: Take a 3 minute breathing break.",
            "suggestion: Step away from screens for 10 minutes.",
            "suggestion: Write down what is worrying you."
        ]
        response += "\n\n" + random.choice(suggestions)
        
    return response
