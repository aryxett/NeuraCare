import os
file_path = r'app/services/insight_engine.py'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

emojis_with_space = ['⚠️ ', '😴 ', '✅ ', '😐 ', '📱 ', '🔴 ', '😊 ', '🏃 ', '💪 ', '🚨 ', '🔗 ', '📊 ', '📉 ', '📈 ', '✨ ']
for e in emojis_with_space:
    content = content.replace(e, '')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
