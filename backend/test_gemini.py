import os
import sys

from app.services.therapy_llm_service import generate_chat_title, generate_therapy_response

title = generate_chat_title('I am feeling so overwhelmed with my workload today.')
print('TITLE:', title)

resp = generate_therapy_response('Hello can you help me')
print('RESP:', resp)
