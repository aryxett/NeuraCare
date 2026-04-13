import httpx
from typing import List, Dict
from app.config import get_settings
from app.services.therapy_service import get_therapy_response as fallback_therapy_response

settings = get_settings()

def generate_chat_title(message: str) -> str:
    """
    Generate a short 3-5 word semantic title based on the first user message.
    """
    if len(message) < 5:
        return "Therapy Session"
        
    try:
        system_prompt = (
            "You are a title generator. Generate a short, semantic 3-5 word title summarizing the topic of the user's message. "
            "Remove filler words such as 'I', 'I'm', 'Can you', etc. "
            "Output ONLY the title without any quotes or extra text. Example: User: 'I feel stressed about work deadlines' -> 'Work Stress'"
        )
        
        headers = {
            "Authorization": f"Bearer {settings.AZURE_OPENAI_API_KEY}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": message[:500]}
            ],
            "temperature": 0.3,
            "max_tokens": 15
        }

        with httpx.Client() as client:
            response = client.post(
                settings.AZURE_OPENAI_ENDPOINT,
                headers=headers,
                json=payload,
                timeout=10.0
            )
            response.raise_for_status()
            data = response.json()
            title = data["choices"][0]["message"]["content"].strip(' "\'')
            return title if title else "Therapy Session"
            
    except Exception as e:
        print(f"Azure OpenAI Title Error: {e}")
        return "Therapy Session"


def generate_therapy_response(
    user_message: str, 
    history: List[Dict[str, str]] = None,
    current_mood: str = None,
    mental_state: Dict = None,
    language: str = "en"
) -> str:
    """
    Generates a supportive AI therapy response using Azure OpenAI.
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
        system_prompt = (
            "You are a supportive, empathetic, and non-judgmental AI mental wellness assistant. "
            "Your primary role is to acknowledge emotions, validate feelings, and provide supportive suggestions.\n\n"
            "Here are your strict operating rules:\n"
            "1. NO MEDICAL ADVICE: Do NOT attempt to act as a therapist or doctor. Never diagnose.\n"
            "2. NO TOXIC POSITIVITY: Avoid generic motivational quotes or dismissive language. Keep it real.\n"
            "3. EMOTIONAL CONTEXT MEMORY: If the user refers to something discussed earlier in this conversation, remember the emotional theme and bring it up supportively.\n"
            "4. MOOD AWARENESS: "
        )
        
        if current_mood:
            system_prompt += f"The user indicated their current mood today is '{current_mood}'. Gently adjust your tone to reflect this if appropriate.\n"
        else:
            system_prompt += "Adjust your tone based strictly on the user's messages.\n"
            
        system_prompt += (
            "5. AI REFLECTION PROMPTS: Occasionally (not always) end your response with a supportive reflective question used in therapy (e.g. 'What usually helps you feel better in situations like this?'). Encourage healthy self-reflection.\n"
            "Keep responses concise, natural, and focused on the user's immediate emotional state."
        )

        if mental_state:
            system_prompt += f"\n\nContext for AI: The user's recent automated mental state metrics are: {mental_state}. Use this implicitly to guide your support."

        if language == "hi":
            system_prompt += "\n\nCRITICAL INSTRUCTION: You MUST reply entirely in natural conversational Hindi. All your responses, reflections, and analyses MUST be in Hindi. Do not use English."

        # Build the messages array
        messages = [{"role": "system", "content": system_prompt}]
        
        if history:
            # Convert 'model' role to 'assistant' for Azure OpenAI compatibility
            formatted_history = []
            for msg in history:
                if msg["role"] == "model":
                    formatted_history.append({"role": "assistant", "content": msg["content"]})
                else:
                    formatted_history.append(msg)
            messages.extend(formatted_history)
            
        messages.append({"role": "user", "content": user_message})

        headers = {
            "Authorization": f"Bearer {settings.AZURE_OPENAI_API_KEY}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": "gpt-4o-mini",
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
        return fallback_therapy_response(user_message)
