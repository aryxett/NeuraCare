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
        # Rule-based fallback — designed to produce realistic scores
        # Baseline: 30 (neutral starting point for an average day)
        #
        # Sleep component: 7-8h is optimal (score 0), <5h is bad (+25), >9h is slightly negative (+5)
        if sleep_hours >= 7:
            sleep_component = max(-10, (7 - sleep_hours) * 3)   # good sleep reduces stress
        else:
            sleep_component = (7 - sleep_hours) * 7              # poor sleep increases stress
        
        # Screen time component: <3h is great (-5), 3-6h is normal (0-5), >6h is bad (+5 to +15)
        if screen_time <= 3:
            screen_component = -5
        elif screen_time <= 6:
            screen_component = (screen_time - 3) * 2             # gentle ramp
        else:
            screen_component = 6 + (screen_time - 6) * 3         # steeper after 6h
        
        # Mood component: 7-10 is great (-10 to -5), 5-6 is neutral (0), 1-4 is bad (+5 to +20)
        mood_component = (5.5 - mood) * 4
        
        # Exercise component: exercise reduces stress
        exercise_component = -8 if exercise else 5
        
        prediction = 30 + sleep_component + screen_component + mood_component + exercise_component

    # Clamp to valid range without numpy
    return float(max(0, min(100, prediction)))
