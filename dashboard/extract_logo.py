import re, base64

with open('dashboard/SmartTransit logo.svg', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

images = re.findall(r'xlink:href="data:image/png;base64,([^"]+)"', content)
print(f'Found {len(images)} images')
for i, b64 in enumerate(images):
    data = base64.b64decode(b64)
    with open(f'dashboard/extracted_logo_{i}.png', 'wb') as out:
        out.write(data)
    print(f'Image {i} saved, size {len(data)} bytes')
