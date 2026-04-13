import urllib.request
import urllib.parse
import json

url = 'https://cognify-ai-jgmj.onrender.com/api/auth/login'
data = urllib.parse.urlencode({'username': '123@gmail.com', 'password': 'password'}).encode('utf-8')
req = urllib.request.Request(url, data=data)
try:
    with urllib.request.urlopen(req) as response:
        print(response.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code}")
    print(e.read().decode('utf-8'))
except Exception as e:
    print(f"Error: {e}")
