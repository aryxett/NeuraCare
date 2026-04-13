import sys
import os
sys.path.append(os.getcwd())

from app.services.therapy_llm_service import generate_therapy_response

try:
    print("Testing OpenAI LLM Service...")
    response = generate_therapy_response("Hello, I feel stressed today.")
    print(f"Response: {response}")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
