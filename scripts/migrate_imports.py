import os
import re

firebase_imports = [
    re.compile(r"import\s+['\"]package:cloud_firestore/[^'\"]+['\"];?\s*"),
    re.compile(r"import\s+['\"]package:firebase_auth/[^'\"]+['\"];?\s*"),
    re.compile(r"import\s+['\"]package:firebase_storage/[^'\"]+['\"];?\s*"),
    re.compile(r"import\s+['\"]package:firebase_messaging/[^'\"]+['\"];?\s*"),
    re.compile(r"import\s+['\"]package:cloud_functions/[^'\"]+['\"];?\s*"),
    re.compile(r"import\s+['\"]package:firebase_core/[^'\"]+['\"];?\s*"),
    re.compile(r"import\s+['\"]package:a_chatz/firebase_options\.dart['\"];?\s*"),
    re.compile(r"import\s+['\"]package:a_chatz/src/core/firebase/firebase_options\.dart['\"];?\s*"),
]

updated_count = 0

for root, dirs, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            # Skip the supabase directory itself
            if os.path.join('lib', 'src', 'core', 'supabase') in path:
                continue
            with open(path, 'r', encoding='utf-8', errors='ignore') as fp:
                content = fp.read()

            new_content = content
            had_fb = False
            for pat in firebase_imports:
                if pat.search(new_content):
                    had_fb = True
                    new_content = pat.sub('', new_content)

            if had_fb:
                # Add Supabase barrel import if not already present
                if "import 'package:a_chatz/src/core/supabase/supabase.dart';" not in new_content:
                    # Put it at the top of imports
                    first_import = re.search(r"import\s+['\"]", new_content)
                    if first_import:
                        idx = first_import.start()
                        new_content = new_content[:idx] + "import 'package:a_chatz/src/core/supabase/supabase.dart';\n" + new_content[idx:]
                    else:
                        new_content = "import 'package:a_chatz/src/core/supabase/supabase.dart';\n" + new_content
                
                with open(path, 'w', encoding='utf-8') as fp:
                    fp.write(new_content)
                updated_count += 1
                print(f"Updated: {path}")

print(f"\nTotal files updated: {updated_count}")
