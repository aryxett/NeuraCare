import google.generativeai as genai
import app.gemini_config # Ensures API key configuration is loaded
from typing import List, Dict
from app.services.therapy_service import get_therapy_response as fallback_therapy_response

def generate_therapy_response(user_message: str, history: List[Dict[str, str]] = None) -> str:
    """
    Generates a supportive AI therapy response using Google Gemini.
    Includes the last 5 messages as context.
    Falls back to rule-based therapy if LLM fails.
    """
    if len(user_message) > 1000:
        user_message = user_message[:1000]

    # Crisis Detection Interceptor
    crisis_keywords = ["want to die", "can't go on", "hurt myself", "ending everything", "kill myself", "suicide"]
    if any(keyword in user_message.lower() for keyword in crisis_keywords):
        return (
            "I'm really sorry you're feeling this much pain. You deserve support and you're not alone. "
            "If you're able, please consider reaching out to someone you trust or a mental health professional right now. "
            "Please call 988 (US) or your local emergency services."
        )

    try:
        system_prompt = """
        You are a supportive, empathetic, and non-judgmental AI mental wellness assistant.
        Your primary role is to acknowledge emotions, validate feelings, and provide brief, supportive suggestions.
        Avoid toxic positivity, generic motivational quotes, or dismissive language.
        Do NOT attempt to act as a therapist or doctor. You must NEVER provide medical diagnoses or unsafe advice.
        Keep responses concise and focused on the user's immediate emotional state.
        """

        model = genai.GenerativeModel('gemini-1.5-flash', system_instruction=system_prompt)
        
        gemini_history = []
        if history:
            for msg in history:
                role = "user" if msg["role"] == "user" else "model"
                gemini_history.append({"role": role, "parts": [msg["content"]]})
                
        chat = model.start_chat(history=gemini_history)

        response = chat.send_message(user_message)

        return response.text
    except Exception as e:
        print(f"Gemini LLM Error: {e}")
        # Use simple rule-based fallback if Gemini fails
        return fallback_therapy_response(user_message)
