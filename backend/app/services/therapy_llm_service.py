import httpx
from typing import List, Dict
from app.config import get_settings
from app.services.therapy_service import get_therapy_response as fallback_therapy_response

settings = get_settings()

def generate_therapy_response(user_message: str, history: List[Dict[str, str]] = None) -> str:
    """
    Generates a supportive AI therapy response using Azure OpenAI.
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
        system_prompt = "You are a supportive, empathetic, and non-judgmental AI mental wellness assistant. Your primary role is to acknowledge emotions, validate feelings, and provide brief, supportive suggestions. Avoid toxic positivity, generic motivational quotes, or dismissive language. Do NOT attempt to act as a therapist or doctor. You must NEVER provide medical diagnoses or unsafe advice. Keep responses concise and focused on the user's immediate emotional state."
        
        # Build the messages array
        messages = [{"role": "system", "content": system_prompt}]
        
        if history:
            messages.extend(history)
            
        messages.append({"role": "user", "content": user_message})

        headers = {
            "api-key": settings.AZURE_OPENAI_API_KEY,
            "Content-Type": "application/json"
        }
        
        payload = {
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 500
        }

        # Make the synchronous HTTP request
        with httpx.Client() as client:
            response = client.post(
                settings.AZURE_OPENAI_ENDPOINT,
                headers=headers,
                json=payload,
                timeout=15.0
            )
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]
            
    except Exception as e:
        print(f"Azure OpenAI LLM Error: {e}")
        # Use simple rule-based fallback if API fails
        return fallback_therapy_response(user_message)
