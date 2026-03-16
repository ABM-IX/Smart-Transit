import json
import re

bundle_path = r'c:\Users\araba\Desktop\SmartTransit\Rute-Map-main\dist\index.8eb82e9b.js'
try:
    with open(bundle_path, 'r', encoding='utf-8') as f:
        text = f.read()
except Exception as e:
    print(f"Error reading file: {e}")
    exit(1)

# Find all occurrences of "FeatureCollection"
idx = 0
found = 0
while True:
    idx = text.find('"FeatureCollection"', idx)
    if idx == -1: break
    
    # Track back to the start of the JSON object
    start = text.rfind('{', 0, idx)
    if start != -1:
        # Find the matching closing brace
        braces = 0
        end = -1
        in_string = False
        escape = False
        for i in range(start, len(text)):
            char = text[i]
            if char == '"' and not escape:
                in_string = not in_string
            
            if not in_string:
                if char == '{':
                    braces += 1
                elif char == '}':
                    braces -= 1
                    if braces == 0:
                        end = i + 1
                        break
            
            escape = char == '\\' and not escape
            
        if end != -1:
            chunk = text[start:end]
            try:
                parsed = json.loads(chunk)
                if 'features' in parsed:
                    filename = f'data_{found}.json'
                    with open(filename, 'w', encoding='utf-8') as out:
                        json.dump(parsed, out, indent=2)
                    print(f'Saved {filename}, features: {len(parsed["features"])}')
                    found += 1
            except json.JSONDecodeError as e:
                # Might not be valid JSON, ignore
                pass
                
    idx += len('"FeatureCollection"')

print(f"Total extracted files: {found}")
