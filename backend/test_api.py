import urllib.request
try:
    with urllib.request.urlopen('http://127.0.0.1:8000/api/analytics/behavioral-intelligence?user_id=1') as response:
        print(response.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print('HTTP ERROR:', e.code)
    print(e.read().decode('utf-8'))
