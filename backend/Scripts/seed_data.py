"""
Seed script: Inserts 7 days of realistic behavioral data + predictions
so the dashboard charts have proper data to display.
"""
import sqlite3
from datetime import date, timedelta
import random

DB_PATH = "cognify.db"

# Realistic 7-day sample data
SAMPLE_DATA = [
    {"sleep": 5.5, "screen": 9.0, "mood": 4, "exercise": False, "stress": 78.0, "risk": "High"},
    {"sleep": 6.0, "screen": 7.5, "mood": 5, "exercise": False, "stress": 66.0, "risk": "High"},
    {"sleep": 7.5, "screen": 5.0, "mood": 7, "exercise": True,  "stress": 32.0, "risk": "Moderate"},
    {"sleep": 6.5, "screen": 8.0, "mood": 5, "exercise": False, "stress": 70.0, "risk": "High"},
    {"sleep": 8.0, "screen": 4.0, "mood": 8, "exercise": True,  "stress": 18.0, "risk": "Low"},
    {"sleep": 7.0, "screen": 6.0, "mood": 6, "exercise": True,  "stress": 38.0, "risk": "Moderate"},
    {"sleep": 6.5, "screen": 7.0, "mood": 5, "exercise": False, "stress": 62.0, "risk": "High"},
]

conn = sqlite3.connect(DB_PATH)
c = conn.cursor()

# Get all user IDs
c.execute("SELECT user_id FROM users")
users = c.fetchall()
print(f"Found {len(users)} users: {[u[0] for u in users]}")

today = date.today()

for user_id, in users:
    # Clear old logs and predictions for clean slate
    c.execute("DELETE FROM behavior_logs WHERE user_id = ?", (user_id,))
    c.execute("DELETE FROM predictions WHERE user_id = ?", (user_id,))

    for i, data in enumerate(SAMPLE_DATA):
        log_date = today - timedelta(days=6 - i)  # 6 days ago -> today

        # Insert behavior log
        c.execute("""
            INSERT INTO behavior_logs (user_id, date, sleep_hours, screen_time, mood, exercise)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (user_id, str(log_date), data["sleep"], data["screen"], data["mood"], data["exercise"]))

        # Insert prediction
        c.execute("""
            INSERT INTO predictions (user_id, stress_score, risk_level, insights, prediction_date)
            VALUES (?, ?, ?, ?, ?)
        """, (user_id, data["stress"], data["risk"],
              f"Stress score: {data['stress']}/100 ({data['risk']})",
              str(log_date)))

    print(f"✅ User {user_id}: Seeded 7 days of data ({today - timedelta(days=6)} → {today})")

conn.commit()
conn.close()

print("\n🎉 Database seeded successfully! Restart the app to see full charts.")
