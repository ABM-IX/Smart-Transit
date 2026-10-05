import numpy as np
from PIL import Image

im = Image.open(r'c:\Users\araba\Desktop\SmartTransit\smart_transit_app\rive_splash\logo_true_alpha.png')
arr = np.array(im)

# Blue mask excluding speed lines (x < 250, y > 250 and y < 400)
is_blue = (arr[:,:,3] > 100) & (arr[:,:,2] > 140) & (arr[:,:,0] < 80)
circuit_mask = is_blue.copy()
# Clear speed lines
circuit_mask[260:390, 0:250] = False
# Clear pin
circuit_mask[0:130, 580:667] = False

# Landmark points on the circuit:
# Start at bottom: (200, 513)
# Bottom sweep: (300, 515), (400, 512), Node 3: (516.5, 468.5)
# Bottom-right turn: (600, 450), (630, 410), (620, 360)
# Middle turn: (580, 335), Node 2: (544.5, 315)
# Spine: (480, 260), (420, 220), (350, 190), (250, 175), (200, 160)
# Top-left turn: (180, 140), (200, 95), (280, 68), (360, 68)
# Node 1: (446.5, 114) connects to top track at (446.5, 68)
# Top track to Pin: (500, 68), (560, 68), Pin Tip: (627.5, 68 -> 116)

print('Centerline definition ready.')
