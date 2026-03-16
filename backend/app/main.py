"""
Cognify AI — Cognitive Digital Twin for Behavioral Wellness Prediction

Main FastAPI Application
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.config import get_settings
from app.database import engine, Base
from app.logging_config import setup_logging, get_logger
from app.routers import auth, behavior, predictions, insights, dashboard, daily_log, ml_predict, analytics, fitbit, therapy
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from app.security_middleware import (
    RateLimitMiddleware,
    http_exception_handler,
    validation_exception_handler,
    general_exception_handler
)

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown events."""
    # Initialize logging
    setup_logging(debug=settings.DEBUG)
    logger = get_logger("startup")

    # Startup: Create database tables
    logger.info("🚀 Starting Cognify AI Backend...")
    Base.metadata.create_all(bind=engine)
    logger.info("✅ Database tables created/verified")

    # Auto-migrate: add is_pinned column if it doesn't exist
    from sqlalchemy import inspect as sa_inspect, text
    insp = sa_inspect(engine)
    if 'chat_conversations' in insp.get_table_names():
        cols = [c['name'] for c in insp.get_columns('chat_conversations')]
        if 'is_pinned' not in cols:
            with engine.connect() as conn:
                conn.execute(text("ALTER TABLE chat_conversations ADD COLUMN is_pinned BOOLEAN DEFAULT FALSE"))
                conn.commit()
            logger.info("✅ Added is_pinned column to chat_conversations")
    
    logger.info(f"📦 Database: {settings.DATABASE_URL.split('://')[0]}")

    # Pre-load ML model
    from app.ml.predict import _load_model
    _load_model()
    logger.info("🧠 ML model initialization complete")

    yield

    # Shutdown
    logger.info("👋 Shutting down Cognify AI Backend...")


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "AI-powered Cognitive Digital Twin that learns your behavioral patterns "
        "and predicts stress/burnout risk. Track sleep, mood, screen time, and "
        "exercise to receive personalized wellness insights."
    ),
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security & Rate Limiting Middleware
app.add_middleware(RateLimitMiddleware)

from app.routers import auth, behavior, predictions, insights, dashboard, daily_log, ml_predict, analytics, fitbit, therapy, chat

# Include Routers
app.include_router(auth.router)
app.include_router(behavior.router)
app.include_router(predictions.router)
app.include_router(insights.router)
app.include_router(dashboard.router)
app.include_router(daily_log.router)
app.include_router(ml_predict.router)
app.include_router(analytics.router)
app.include_router(fitbit.router)
app.include_router(therapy.router)
app.include_router(chat.router)


@app.get("/", tags=["Health"])
async def root():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "message": "Cognify AI Backend is running 🧠"
    }


@app.get("/api/health", tags=["Health"])
async def health_check():
    """Detailed health check with database verification."""
    from app.database import SessionLocal
    from sqlalchemy import text
    db_status = "connected"
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
    except Exception as e:
        import logging
        logging.getLogger("cognify").error(f"Health check DB error: {e}")
        db_status = "disconnected"

    return {
        "status": "healthy" if db_status == "connected" else "degraded",
        "database": db_status,
        "database_type": settings.DATABASE_URL.split("://")[0],
        "ml_model": "loaded",
        "version": settings.APP_VERSION
    }

# Register global exception handlers
app.add_exception_handler(StarletteHTTPException, http_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(Exception, general_exception_handler)
