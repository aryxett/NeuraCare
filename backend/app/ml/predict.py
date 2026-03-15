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
        # ── Rule-based fallback (no ML model on server) ──
        # Each component is individually capped to prevent saturation.
        # Baseline 25, max possible ≈ 92 (truly extreme inputs only).
        
        # Sleep (range: -8 to +22)
        # 8h+ → stress reduction, <7h → stress increase, capped at 22
        if sleep_hours >= 7:
            sleep_c = max(-8, (7 - sleep_hours) * 2.5)
        else:
            sleep_c = min(22, (7 - sleep_hours) * 5)
        
        # Screen time (range: -5 to +18)
        # <2h is great, 2-5h normal, >5h bad, capped at 18
        if screen_time <= 2:
            screen_c = -5
        elif screen_time <= 5:
            screen_c = (screen_time - 2) * 1.5
        else:
            screen_c = min(18, 4.5 + (screen_time - 5) * 2.5)
        
        # Mood (range: -10 to +16)
        # High mood (8+) reduces stress, low mood (<4) increases it
        mood_c = min(16, max(-10, (5 - mood) * 3.5))
        
        # Exercise (range: -7 to +4)
        exercise_c = -7 if exercise else 4
        
        prediction = 25 + sleep_c + screen_c + mood_c + exercise_c

    # Clamp to valid range
    return float(max(0, min(100, prediction)))
