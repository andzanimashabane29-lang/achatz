import os, re

files_map = {}

for root, dirs, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8', errors='ignore') as fp:
                lines = fp.readlines()
            fb_items = []
            for i, line in enumerate(lines):
                for match in ['FirebaseFirestore', 'FirebaseAuth', 'FirebaseStorage', 'FirebaseFunctions', 'FirebaseMessaging', 'cloud_firestore', 'firebase_auth', 'firebase_storage', 'firebase_messaging']:
                    if match in line:
                        fb_items.append(f"{match} (line {i+1})")
            if fb_items:
                files_map[path] = fb_items

print(f"Total files with Firebase: {len(files_map)}\n")
for path in sorted(files_map.keys()):
    print(f"{path}:")
    # print up to 3 distinct mentions
    distinct = list(set([x.split()[0] for x in files_map[path]]))
    print(f"   mentions: {', '.join(distinct)} (total occurrences: {len(files_map[path])})")
