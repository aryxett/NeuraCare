# Cognify AI — Cognitive Digital Twin for Behavioral Wellness Prediction

<p align="center">
  <strong>🧠 An AI-powered system that creates a Cognitive Digital Twin to learn your behavioral patterns and predict stress/burnout risk</strong>
</p>

---

## 🏗️ System Architecture

```
Mobile App (Flutter) ─┐
                       ├──► FastAPI Backend ──► PostgreSQL Database
Web Dashboard (React) ─┘         │
                                 ├──► ML Prediction Engine (Scikit-learn)
                                 └──► AI Insight Generator
```

## 📦 Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend API | Python, FastAPI, SQLAlchemy |
| Database | PostgreSQL |
| Machine Learning | Scikit-learn, Pandas, NumPy |
| Web Dashboard | React, TailwindCSS, Recharts |
| Mobile App | Flutter (Android) |
| Auth | JWT (python-jose + bcrypt) |
| Deployment | Docker, Docker Compose |

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Node.js 18+
- PostgreSQL 16+
- Flutter 3.2+ (for mobile)
- Docker & Docker Compose (optional)

### Option 1: Docker Compose (Recommended)

```bash
docker-compose up --build
```

This starts:
- PostgreSQL on port **5432**
- FastAPI Backend on port **8000** → [http://localhost:8000/docs](http://localhost:8000/docs)
- React Dashboard on port **3000** → [http://localhost:3000](http://localhost:3000)

### Option 2: Manual Setup

#### 1. Backend
```bash
cd backend
pip install -r requirements.txt

# Train the ML model
python -m app.ml.train

# Start the server
uvicorn app.main:app --reload --port 8000
```

#### 2. Dashboard
```bash
cd dashboard
npm install
npm run dev
```

#### 3. Mobile App
```bash
cd mobile
flutter pub get
flutter run
```

## 📡 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login → JWT token |
| GET | `/api/auth/me` | Get current user |
| POST | `/api/behavior-logs/` | Create behavior log |
| GET | `/api/behavior-logs/` | List behavior logs |
| POST | `/api/predictions/predict` | Run stress prediction |
| GET | `/api/predictions/` | List predictions |
| GET | `/api/insights/` | Get AI insights |

## 🧠 ML Model

The system trains a **Random Forest** (or Gradient Boosting) regressor on synthetic behavioral data.

**Inputs:** sleep_hours, screen_time, mood (1-10), exercise (bool)
**Output:** Stress risk score (0-100)

```bash
cd backend
python -m app.ml.train
```

## 🧪 Testing

```bash
cd backend
pytest tests/ -v
```

## 📁 Project Structure

```
├── backend/           # FastAPI + ML
│   ├── app/
│   │   ├── main.py
│   │   ├── models/    # SQLAlchemy
│   │   ├── schemas/   # Pydantic
│   │   ├── routers/   # API routes
│   │   ├── services/  # Business logic
│   │   └── ml/        # ML training & prediction
│   └── tests/
├── dashboard/         # React + TailwindCSS
│   └── src/
│       ├── pages/
│       ├── components/
│       └── services/
├── mobile/            # Flutter
│   └── lib/
│       ├── screens/
│       └── services/
└── docker-compose.yml
```

## 📄 License

MIT License
