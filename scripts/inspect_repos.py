import os, re

def inspect_file(path):
    print('=== ' + path + ' ===')
    if not os.path.exists(path):
        print("File not found")
        return
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        for i, line in enumerate(f):
            trimmed = line.strip()
            if any(trimmed.startswith(kw) for kw in ['Future', 'Stream', 'void', 'class ']) and ('(' in trimmed or 'class ' in trimmed):
                print(f'  {i+1}: {trimmed[:90]}')

inspect_file('lib/src/features/status/data/status_repository.dart')
inspect_file('lib/src/features/status/data/channel_repository.dart')
inspect_file('lib/src/features/calls/data/call_repository.dart')
inspect_file('lib/src/features/calls/data/live_repository.dart')
inspect_file('lib/src/features/moderation/data/moderation_repository.dart')
