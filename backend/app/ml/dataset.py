"""
Synthetic Dataset Generator for Stress Prediction Model

Generates realistic behavioral data with correlations between
sleep, screen time, mood, exercise, and stress levels.
"""

import pandas as pd
import numpy as np
from pathlib import Path


def generate_dataset(n_samples: int = 5000, seed: int = 42) -> pd.DataFrame:
    """
    Generate a synthetic dataset with realistic correlations.

    Features:
    - sleep_hours (0-12): Hours of sleep
    - screen_time (0-16): Screen time in hours
    - mood (1-10): Self-reported mood
    - exercise (0/1): Whether the person exercised

    Target:
    - stress_score (0-100): Computed stress risk score
    """
    np.random.seed(seed)

    # Generate base features
    sleep_hours = np.clip(np.random.normal(7, 1.5, n_samples), 2, 12)
    screen_time = np.clip(np.random.normal(6, 3, n_samples), 0.5, 16)
    mood = np.clip(np.random.normal(6, 2, n_samples), 1, 10).astype(int)
    exercise = np.random.binomial(1, 0.45, n_samples)  # 45% exercise

    # Create realistic correlations
    # People who sleep less tend to have higher screen time
    screen_time = np.where(
        sleep_hours < 5,
        screen_time + np.random.normal(2, 0.5, n_samples),
        screen_time
    )
    screen_time = np.clip(screen_time, 0.5, 16)

    # People who exercise tend to have better mood
    mood = np.where(
        exercise == 1,
        np.clip(mood + np.random.randint(0, 2, n_samples), 1, 10),
        mood
    )

    # Calculate stress score with realistic formula
    # Higher sleep → lower stress
    # Higher screen time → higher stress
    # Higher mood → lower stress
    # Exercise → lower stress
    sleep_factor = (8 - sleep_hours) * 8           # Range: approx -32 to 48
    screen_factor = (screen_time - 4) * 4          # Range: approx -14 to 48
    mood_factor = (5 - mood) * 6                   # Range: approx -30 to 24
    exercise_factor = np.where(exercise == 1, -12, 8)  # Exercise reduces stress
    noise = np.random.normal(0, 5, n_samples)      # Random noise

    stress_score = 50 + sleep_factor + screen_factor + mood_factor + exercise_factor + noise
    stress_score = np.clip(stress_score, 0, 100).round(1)

    df = pd.DataFrame({
        "sleep_hours": sleep_hours.round(1),
        "screen_time": screen_time.round(1),
        "mood": mood,
        "exercise": exercise,
        "stress_score": stress_score
    })

    return df


def save_dataset(df: pd.DataFrame, path: str = "app/ml/data/training_data.csv"):
    """Save the dataset to a CSV file."""
    filepath = Path(path)
    filepath.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(filepath, index=False)
    print(f"✅ Dataset saved to {filepath} ({len(df)} samples)")
    print(f"\n📊 Dataset Statistics:")
    print(df.describe().round(2))
    return filepath


if __name__ == "__main__":
    df = generate_dataset(5000)
    save_dataset(df)
