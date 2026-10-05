import math
from PIL import Image
import numpy as np

# Load true alpha logo
im = Image.open(r'c:\Users\araba\Desktop\SmartTransit\smart_transit_app\rive_splash\logo_true_alpha.png')
arr = np.array(im)

is_blue = (arr[:,:,3] > 100) & (arr[:,:,2] > 140) & (arr[:,:,0] < 80)
is_navy = (arr[:,:,3] > 100) & (arr[:,:,0] < 40) & (arr[:,:,1] < 50) & (arr[:,:,2] < 70)

# Artboard scale: 0.36, centered at (250, 225)
SCALE = 0.36
CX_SRC = 333.5
CY_SRC = 265.0
CX_DST = 250.0
CY_DST = 225.0

def tx(x):
    return round(CX_DST + (x - CX_SRC) * SCALE, 2)

def ty(y):
    return round(CY_DST + (y - CY_SRC) * SCALE, 2)

print('Transformed key landmarks:')
print('Pin Head:', tx(627.5), ty(43.5))
print('Pin Tip:', tx(627.5), ty(116.0))
print('Node 1 (Top):', tx(446.5), ty(114.0))
print('Node 2 (Mid):', tx(544.5), ty(315.0))
print('Node 3 (Bot):', tx(516.5), ty(468.5))
print('Bottom Start:', tx(210.0), ty(510.0))
