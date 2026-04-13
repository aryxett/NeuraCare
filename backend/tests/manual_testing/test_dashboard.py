"""Quick test script for the new dashboard endpoints."""
import urllib.request, json

BASE = "http://localhost:8000/api"

# 1. Login
login_req = urllib.request.Request(
    f"{BASE}/auth/login",
    data=b"username=test%40gmail.com&password=123",
    headers={"Content-Type": "application/x-www-form-urlencoded"},
)
token = json.loads(urllib.request.urlopen(login_req).read().decode())["access_token"]
auth = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
print(f"✅ Login OK")

# 2. POST /submit-daily-data
submit_req = urllib.request.Request(
    f"{BASE}/submit-daily-data",
    data=json.dumps({"sleep_hours": 6.5, "screen_time": 8.0, "mood": 5, "exercise": False}).encode(),
    headers=auth,
)
res = json.loads(urllib.request.urlopen(submit_req).read().decode())
print(f"✅ Submit: stress={res['stress_score']}, risk={res['risk_level']}")

# 3. GET /dashboard-summary
dash_req = urllib.request.Request(f"{BASE}/dashboard-summary", headers=auth)
dash = json.loads(urllib.request.urlopen(dash_req).read().decode())
print(f"✅ Dashboard: avg_sleep={dash['avg_sleep']}, avg_mood={dash['avg_mood']}, stress={dash['stress_score']}")
print(f"   weekly_sleep={dash['weekly_sleep']}")

# 4. GET /weekly-trends
trends_req = urllib.request.Request(f"{BASE}/weekly-trends", headers=auth)
trends = json.loads(urllib.request.urlopen(trends_req).read().decode())
print(f"✅ Trends: dates={trends['dates']}, sleep={trends['sleep']}, stress={trends['stress']}")

print("\n🎉 ALL ENDPOINTS WORKING!")
