"""
Stress Prediction Model Training

Trains a RandomForestClassifier on synthetic behavioral data
to predict stress risk scores (0-100).
"""

import joblib
import numpy as np
import pandas as pd
from pathlib import Path
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
from app.ml.dataset import generate_dataset

def train_model(model_dir: str = "app/ml/model"):
    """Train and save the stress prediction model using RandomForestClassifier."""
    print("=" * 60)
    print("🧠 COGNIFY AI — Phase 3: Stress Prediction ML Training")
    print("=" * 60)

    # Generate training data
    print("\n📥 Generating synthetic training data...")
    df = generate_dataset(n_samples=1000)
    print(f"   Dataset shape: {df.shape}")

    # Prepare features and target
    X = df[["sleep_hours", "screen_time", "mood", "exercise"]].values
    
    # For a Classifier to output 0-100, we round the target to integer classes
    y = np.clip(df["stress_score"].round().astype(int), 0, 100).values

    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    print(f"   Training set: {X_train.shape[0]} samples")
    print(f"   Test set: {X_test.shape[0]} samples")

    # Train Random Forest Classifier
    print("\n🌲 Training RandomForestClassifier...")
    rf_model = RandomForestClassifier(
        n_estimators=50,
        max_depth=10,
        min_samples_split=5,
        random_state=42
    )
    rf_model.fit(X_train, y_train)
    rf_predictions = rf_model.predict(X_test)

    # Evaluate model
    print("\n📊 Model Evaluation:")
    print("-" * 50)
    
    # We can measure accuracy, though since it's 101 classes, exact accuracy might be lower 
    # but the predictions will be close. To show practical accuracy, we can look at MAE of the classes.
    acc = accuracy_score(y_test, rf_predictions)
    mae = np.mean(np.abs(y_test - rf_predictions))
    
    print(f"   ├── Exact Class Accuracy: {acc:.4f}")
    print(f"   └── Mean Absolute Error:  {mae:.2f} points (out of 100)")

    feature_names = ["sleep_hours", "screen_time", "mood", "exercise"]
    importances = rf_model.feature_importances_
    print("\n📈 Feature Importances:")
    for name, imp in sorted(zip(feature_names, importances), key=lambda x: x[1], reverse=True):
        bar = "█" * int(imp * 40)
        print(f"   {name:15s} {imp:.3f} {bar}")

    # Save model
    model_path = Path(model_dir)
    model_path.mkdir(parents=True, exist_ok=True)
    save_path = model_path / "stress_model.joblib"
    joblib.dump(rf_model, save_path)
    print(f"\n💾 Model saved to: {save_path}")
    print("=" * 60)
    print("✅ Training complete!")

    return rf_model

if __name__ == "__main__":
    train_model()
