import re

with open('dashboard/SmartTransit logo.svg', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# remove metadata tag
content = re.sub(r'<metadata>.*?</metadata>', '', content, flags=re.DOTALL)
clean_svg = re.sub(r'data:image/png;base64,[^"]+', 'DATA_URI', content)
with open('dashboard/clean_structure.svg', 'w', encoding='utf-8') as out:
    out.write(clean_svg)
# Inspect elements
texts = re.findall(r'<text[^>]*>.*?</text>', clean_svg, re.DOTALL)
print('Texts:', texts)
fills = re.findall(r'fill="([^"]+)"', clean_svg)
from collections import Counter
print('Fills:', Counter(fills))
paths = re.findall(r'<path[^>]*d="([^"]+)"[^>]*>', clean_svg)
print('Paths count:', len(paths))
for i, p in enumerate(paths[:15]):
    print(f'Path {i}: {p[:80]}...')

