import os
import re

lib_path = 'lib'
replacements = {
    'AppTheme.bgCard': 'AppTheme.card(context)',
    'AppTheme.bgElevated': 'AppTheme.elevated(context)',
    'AppTheme.borderSubtle': 'AppTheme.border(context)',
    'AppTheme.textPrimary': 'AppTheme.textP(context)',
    'AppTheme.textSecondary': 'AppTheme.textS(context)',
    'AppTheme.textMuted': 'AppTheme.textM(context)',
    'AppTheme.cardDecoration': 'AppTheme.cardDecorationFor(context)'
}

def process_file(filepath):
    # Don't modify app_theme.dart itself
    if "app_theme.dart" in filepath.replace('\\', '/'):
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Check if this file even has any target AppTheme properties
    has_target = False
    for k in replacements.keys():
        if k in content:
            has_target = True
            break
            
    if not has_target: return
    
    # VERY IMPORTANT: Only remove const from the lines that actually use our context-aware AppTheme 
    # to avoid breaking other const widget trees as much as possible.
    # Actually, a safer approach is to strip `const ` from ANY widget that *contains* AppTheme. textPrimary/etc
    # This regex removes `const ` if the following bracketed structure contains an AppTheme 
    # But it's too complex. 
    
    # We will do a simple stripping for all common widgets IN FILES that contain AppTheme 
    # Since we might break `const Padding(child: BoxDecoration(...))`, let's just strip ALL const keywords 
    # that are right before common Flutter widget constructors in the entire file. It will cause lint warnings, 
    # but it will compile correctly unless there's a const Map/List.
    content = re.sub(r'\bconst\s+(BoxDecoration|Divider|Border|BorderSide|Icon|TextStyle|Text|Padding|Container|Center|SizedBox|Row|Column)\b', r'\1', content)
    
    for k, v in replacements.items():
        content = content.replace(k, v)
        
    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, _, files in os.walk(lib_path):
    for f in files:
        if f.endswith('.dart'):
            process_file(os.path.join(root, f))
