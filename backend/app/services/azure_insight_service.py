import httpx
from typing import List, Dict, Optional
from app.config import get_settings

settings = get_settings()

def generate_azure_insights(
    sleep_hours: float,
    screen_time: float,
    mood: int,
    exercise: bool,
    stress_score: float,
    recent_logs: Optional[List] = None
) -> Dict[str, any]:
    """
    Generates empathetic, data-driven wellness insights using Azure OpenAI.
    Analyzes behavioral data to provide personalized summaries and recommendations.
    """
    
    # Prepare data summary for the AI
    data_context = (
        f"Today's Stats:\n"
        f"- Sleep: {sleep_hours} hours\n"
        f"- Screen Time: {screen_time} hours\n"
        f"- Mood: {mood}/10\n"
        f"- Exercise: {'Yes' if exercise else 'No'}\n"
        f"- AI Stress Score: {stress_score}/100\n"
    )
    
    if recent_logs:
        history_summary = "\nPast 7 Days History:\n"
        for log in recent_logs[-7:]:
            history_summary += f"- {log.date}: Sleep {log.sleep_hours}h, Screen {log.screen_time}h, Mood {log.mood}/10, Exercise: {'Yes' if log.exercise else 'No'}\n"
        data_context += history_summary

    try:
        system_prompt = (
            "You are a sophisticated AI Wellness Analyst for 'Cognify AI'. Your goal is to analyze behavioral data "
            "(sleep, screen time, mood, exercise, stress) and provide deeply empathetic, insightful, and supportive feedback. "
            "Your tone should be consistent with a gentle therapy assistant. "
            "Structure your response as a JSON object with two fields:\n"
            "1. 'summary': A concise (2-3 sentences) overall assessment of the user's wellbeing today.\n"
            "2. 'ai_insights': An array of 2-3 specific observations about their behavioral patterns (e.g., 'Your high screen time seems to coincide with lower mood late in the day').\n"
            "3. 'recommendations': An array of 2-3 actionable, supportive recommendations (e.g., 'Try a 5-minute digital detox before bed').\n"
            "Avoid generic advice. Focus on the relationship between their data points."
        )

        headers = {
            "api-key": settings.AZURE_OPENAI_API_KEY,
            "Content-Type": "application/json"
        }
        
        payload = {
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Analyze this wellness data and respond ONLY with the JSON format specified:\n\n{data_context}"}
            ],
            "temperature": 0.7,
            "max_tokens": 1000,
            "response_format": {"type": "json_object"}
        }

        with httpx.Client() as client:
            response = client.post(
                settings.AZURE_OPENAI_ENDPOINT,
                headers=headers,
                json=payload,
                timeout=20.0
            )
            response.raise_for_status()
            data = response.json()
            import json
            content = data["choices"][0]["message"]["content"]
            result = json.loads(content)
            
            # Ensure all keys exist
            if "ai_insights" not in result: result["ai_insights"] = []
            if "recommendations" not in result: result["recommendations"] = []
            if "summary" not in result: result["summary"] = "No summary available."
            
            return result
            
    except Exception as e:
        print(f"Azure AI Insight Error: {e}")
        return None
