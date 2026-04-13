import urllib.request
import json

BASE = "http://localhost:8000"

def run_tests():
    print("Testing POST /predict-stress...")
    
    payload = {
        "sleep_hours": 6.5,
        "screen_time": 8.0,
        "mood": 5,
        "exercise": False
    }
    
    req_submit = urllib.request.Request(
        f"{BASE}/predict-stress",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"}
    )
    res_submit = urllib.request.urlopen(req_submit)
    print("Prediction Result:", res_submit.read().decode())
    
if __name__ == "__main__":
    run_tests()
