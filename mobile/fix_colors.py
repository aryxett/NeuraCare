import os
import re

lib_path = 'lib'

color_replacements = {
    r'\b(?:const\s+)?Color\(0xFF1A1D2A\)': 'AppTheme.elevated(context)',
    r'\b(?:const\s+)?Color\(0xFF131620\)': 'AppTheme.card(context)',
    r'\b(?:const\s+)?Color\(0xFFF0F2FF\)': 'AppTheme.textP(context)',
    r'\b(?:const\s+)?Color\(0xFF8B90A8\)': 'AppTheme.textS(context)',
    r'\b(?:const\s+)?Color\(0xFF0D1017\)': 'AppTheme.bg(context)',
    r'\b(?:const\s+)?Color\(0xFF1E2236\)': 'AppTheme.border(context)',
    r'\b(?:const\s+)?Color\(0xFF0F2D1F\)': 'AppTheme.accentGreen.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.08)',
    r'\b(?:const\s+)?Color\(0xFF2D2A0F\)': 'AppTheme.accentAmber.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.08)',
    r'\b(?:const\s+)?Color\(0xFF2D0F0F\)': 'AppTheme.accentRed.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.08)',
    r'\b(?:const\s+)?Color\(0xFF1E2540\)': 'AppTheme.accentBlue.withValues(alpha: 0.15)',
}

def process_file(filepath):
    # Don't modify app_theme.dart itself
    if "app_theme.dart" in filepath.replace('\\', '/'):
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Strip const from common widgets in case removing const from Color breaks it
    content = re.sub(r'\bconst\s+(BoxDecoration|Divider|Border|BorderSide|Icon|TextStyle|Text|Padding|Container|Center|SizedBox|Row|Column|SnackBar|CircularProgressIndicator|Material|TextFormField)\b', r'\1', content)
    
    for pattern, replacement in color_replacements.items():
        content = re.sub(pattern, replacement, content)
        
    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, _, files in os.walk(lib_path):
    for f in files:
        if f.endswith('.dart'):
            process_file(os.path.join(root, f))
