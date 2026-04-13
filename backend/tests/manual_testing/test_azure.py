import os
import sys

from app.services.therapy_llm_service import generate_chat_title, generate_therapy_response

try:
    title = generate_chat_title('I am feeling so overwhelmed with my workload today.')
    print('TITLE:', title)
except Exception as e:
    print('TITLE ERROR:', e)

try:
    resp = generate_therapy_response('Hello can you help me')
    print('RESP:', resp)
except Exception as e:
    print('RESP ERROR:', e)
