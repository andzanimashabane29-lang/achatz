import os
import re

collections = set()
firebase_imports = set()
firebase_apis = {}

coll_pattern = re.compile(r"\.collection\(['\"]([^'\"]+)['\"]\)")
import_pattern = re.compile(r"import\s+['\"]package:(firebase[^'\"]+|cloud_firestore[^'\"]*)['\"]")

files_with_firebase = []

for root, dirs, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8', errors='ignore') as fp:
                content = fp.read()
                has_fb = False
                for m in coll_pattern.finditer(content):
                    collections.add(m.group(1))
                    has_fb = True
                for m in import_pattern.finditer(content):
                    firebase_imports.add(m.group(1))
                    has_fb = True
                if 'Firebase' in content or 'firestore' in content or 'FirebaseAuth' in content:
                    has_fb = True
                if has_fb:
                    files_with_firebase.append(path)

print(f"Total files referencing Firebase: {len(files_with_firebase)}")
print("\nFirebase Collections used:")
for c in sorted(collections):
    print(f"  - {c}")

print("\nFirebase packages imported:")
for imp in sorted(firebase_imports):
    print(f"  - {imp}")
