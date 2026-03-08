"""
Stress Prediction Module

Loads the trained ML model and provides prediction functionality.
Falls back to a rule-based formula if no trained model is available.
"""

try:
    import joblib
    import numpy as np
    ML_LIBS_AVAILABLE = True
except ImportError:
    ML_LIBS_AVAILABLE = False

from pathlib import Path
from app.config import get_settings

settings = get_settings()

# Global model cache
_model = None


def _load_model():
    """Load the trained model from disk."""
    global _model
    if not ML_LIBS_AVAILABLE:
        print("⚠️ ML libraries (joblib/numpy) missing. Using rule-based fallback.")
        _model = None
        return _model
        
    model_path = Path(settings.ML_MODEL_PATH)
    if model_path.exists():
        _model = joblib.load(model_path)
        print(f"✅ ML model loaded from {model_path}")
    else:
        print(f"⚠️ No trained model found at {model_path}. Using rule-based fallback.")
        _model = None
    return _model


def predict_stress(sleep_hours: float, screen_time: float, mood: int, exercise: bool) -> float:
    """
    Predict stress risk score (0-100) from behavioral inputs.

    Args:
        sleep_hours: Hours of sleep (0-24)
        screen_time: Screen time in hours (0-24)
        mood: Self-reported mood (1-10)
        exercise: Whether the user exercised (True/False)

    Returns:
        Stress risk score between 0 and 100
    """
    global _model
    if _model is None:
        _load_model()

    exercise_val = 1 if exercise else 0

    if _model is not None and ML_LIBS_AVAILABLE:
        # Use trained ML model
        features = np.array([[sleep_hours, screen_time, mood, exercise_val]])
        prediction = _model.predict(features)[0]
    else:
        # Rule-based fallback
        sleep_factor = (8 - sleep_hours) * 8
        screen_factor = (screen_time - 4) * 4
        mood_factor = (5 - mood) * 6
        exercise_factor = -12 if exercise else 8
        prediction = 50 + sleep_factor + screen_factor + mood_factor + exercise_factor

    # Clamp to valid range without numpy
    return float(max(0, min(100, prediction)))
