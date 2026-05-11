import os
import re
import sys

def parse_strings_file(file_path):
    keys = set()
    # Regex to match "key" = "value";
    # This handles escaped quotes and basic structure
    pattern = re.compile(r'^"(.+?)"\s*=\s*".*?"\s*;', re.MULTILINE)
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            # Remove comments to avoid false positives
            content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
            content = re.sub(r'//.*', '', content)
            
            matches = pattern.findall(content)
            for key in matches:
                keys.add(key)
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
    
    return keys

def main():
    # Adjust path based on execution from root
    resources_dir = "Sources/GraceAppsLibrary/Resources"
    if not os.path.exists(resources_dir):
        # Try relative to script location if called from scripts/
        resources_dir = "../Sources/GraceAppsLibrary/Resources"
        if not os.path.exists(resources_dir):
            print(f"Error: Could not find Resources directory at Sources/GraceAppsLibrary/Resources")
            sys.exit(1)
    
    lproj_dirs = [d for d in os.listdir(resources_dir) if d.endswith(".lproj")]
    
    all_translations = {}
    for lproj in sorted(lproj_dirs):
        strings_file = os.path.join(resources_dir, lproj, "Localizable.strings")
        if os.path.exists(strings_file):
            keys = parse_strings_file(strings_file)
            all_translations[lproj] = keys
            print(f"Loaded {len(keys)} keys from {lproj}")
        else:
            print(f"Warning: {strings_file} not found")

    if not all_translations:
        print("No translations found.")
        sys.exit(0)

    # Use 'en.lproj' as the reference if available, otherwise the first one
    reference_lang = "en.lproj" if "en.lproj" in all_translations else list(all_translations.keys())[0]
    reference_keys = all_translations[reference_lang]
    
    has_errors = False
    
    print(f"\n--- Comparing against {reference_lang} ---")
    
    for lang in sorted(all_translations.keys()):
        if lang == reference_lang:
            continue
        
        keys = all_translations[lang]
        missing_in_lang = reference_keys - keys
        extra_in_lang = keys - reference_keys
        
        if missing_in_lang:
            print(f"\n❌ {lang} is missing {len(missing_in_lang)} keys from {reference_lang}:")
            for k in sorted(missing_in_lang):
                print(f"  - {k}")
            has_errors = True
            
        if extra_in_lang:
            print(f"\n⚠️ {lang} has {len(extra_in_lang)} extra keys not in {reference_lang}:")
            for k in sorted(extra_in_lang):
                print(f"  - {k}")
    
    if has_errors:
        print("\nTranslation check failed.")
        sys.exit(1)
    else:
        print("\n✅ All translations are consistent.")
        sys.exit(0)

if __name__ == "__main__":
    main()
