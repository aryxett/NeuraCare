from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    APP_NAME: str = "Cognify AI - Cognitive Digital Twin"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True

    # Database (SQLite for local dev, PostgreSQL for production)
    DATABASE_URL: str = "sqlite:///./cognify.db"

    # JWT Authentication
    JWT_SECRET_KEY: str = "dev-secret-key-change-me"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 43200  # 30 days

    # ML Model
    ML_MODEL_PATH: str = "app/ml/model/stress_model.joblib"

    # Fitbit OAuth 2.0
    FITBIT_CLIENT_ID: str = "YOUR_CLIENT_ID"
    FITBIT_CLIENT_SECRET: str = "YOUR_CLIENT_SECRET"
    FITBIT_REDIRECT_URI: str = "http://127.0.0.1:8000/api/fitbit/callback"
    OPENAI_API_KEY: str = "your-openai-api-key"
    AZURE_OPENAI_API_KEY: str = ""
    AZURE_OPENAI_ENDPOINT: str = ""

    class Config:
        env_file = ".env"
        extra = "allow"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
