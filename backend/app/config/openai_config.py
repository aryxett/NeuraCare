from app.config import get_settings

settings = get_settings()
OPENAI_API_KEY = settings.OPENAI_API_KEY

client = OpenAI(api_key=OPENAI_API_KEY)
