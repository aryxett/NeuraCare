# NeuraCare — AI-Powered Mental Wellness & Therapy Companion

<p align="center">
  <strong>🧠 An AI-powered system that learns your behavioral patterns, predicts stress/burnout risk, and provides automated, conversational therapy sessions.</strong>
</p>

---

## 🏗️ System Architecture

```
Mobile App (Flutter) ─┐
                       ├──► FastAPI Backend ──► MongoDB Database
Web Dashboard (React) ─┘         │
                                 ├──► ML Prediction Engine (Scikit-learn)
                                 └──► GitHub Models API (Therapy & Insights)
```

## 📦 Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend API | Python, FastAPI |
| Database | MongoDB |
| Machine Learning | Scikit-learn, Pandas, NumPy |
| AI Integration | GitHub Models API (LLM for Chat & Insights) |
| Web Dashboard | React, TailwindCSS, Recharts |
| Mobile App | Flutter (Android) with custom AppTheme system |
| Deployment | Local, Docker, Render (Backend) |

## ✨ Core Features
- **Smart Dashboard**: Daily analytics with actionable insights and progress.
- **Therapy Chat**: AI-driven conversational assistant acting as an empathetic therapist.
- **Deep Analytics**: Google Fit integration overlaying sleep, exercise, and screen-time.
- **Life Patterns**: Advanced breakdown of long-term habits triggering stress loops.

## 🚀 Quick Start (Local Development)

### Prerequisites
- Python 3.11+
- Node.js 18+
- MongoDB instance (local or Atlas cluster)
- Flutter 3.2+ (for mobile)

### 1. Backend Setup

```bash
cd backend
pip install -r requirements.txt

# Create .env file and add your MongoDB Database URL + GitHub API Token
# MONGODB_URL=...
# GITHUB_MODELS_API_KEY=ghp_...

# Start the server
uvicorn app.main:app --reload --port 8000
```
*API Docs available at: [http://localhost:8000/docs](http://localhost:8000/docs)*

### 2. Mobile App Setup

```bash
cd mobile
flutter pub get

# Connect Android Physical Device or Emulator 
flutter run
```

### 3. Dashboard (Optional)

```bash
cd dashboard
npm install
npm run dev
```

## 📡 Key API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login → Token |
| GET | `/api/auth/me` | Get current user profile |
| POST | `/api/behavior-logs/` | Add a daily behavior log |
| GET | `/api/behavior-logs/` | List all historical behavior logs |
| POST | `/api/therapy/chat` | Chat with the AI therapist via GitHub Models |
| GET | `/api/insights/` | Get AI-generated long-term insights |

## 📁 Project Structure

```
├── backend/           # FastAPI + ML + LLM Services
│   ├── app/
│   │   ├── main.py
│   │   ├── models/    # MongoDB Pydantic validation
│   │   ├── schemas/   # API Schemas
│   │   ├── routers/   # API routes
│   │   ├── services/  # Business logic & LLM APIs
│   │   └── ml/        # ML training & prediction
│   └── tests/
├── dashboard/         # React + TailwindCSS Web Admin
│   └── src/
├── mobile/            # Flutter 
│   └── lib/
│       ├── core/      # AppTheme & Utils
│       ├── screens/   # Views (Chat, Insights, History, Profile)
│       └── services/  # API and Local Storage Services
└── docker-compose.yml
```

## 📄 License

MIT License
