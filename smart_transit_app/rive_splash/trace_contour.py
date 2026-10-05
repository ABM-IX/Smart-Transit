import numpy as np
from PIL import Image

def get_contours(mask):
    padded = np.pad(mask, 1, mode='constant', constant_values=False)
    h, w = padded.shape
    visited = np.zeros_like(padded, dtype=bool)
    contours = []
    
    dirs = [(-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1)]
    
    for r in range(1, h - 1):
        for c in range(1, w - 1):
            if padded[r, c] and not padded[r, c - 1] and not visited[r, c]:
                contour = []
                curr = (r, c)
                b_dir = 6
                
                while True:
                    contour.append((curr[0] - 1, curr[1] - 1))
                    visited[curr[0], curr[1]] = True
                    
                    found = False
                    start_dir = (b_dir + 2) % 8
                    for i in range(8):
                        d_idx = (start_dir + i) % 8
                        nr = curr[0] + dirs[d_idx][0]
                        nc = curr[1] + dirs[d_idx][1]
                        if 0 <= nr < h and 0 <= nc < w and padded[nr, nc]:
                            b_dir = (d_idx + 4) % 8
                            curr = (nr, nc)
                            found = True
                            break
                    if not found or curr == (r, c):
                        break
                if len(contour) > 20:
                    contours.append(contour)
    return contours

def simplify_dp(pts, tol):
    if len(pts) <= 2:
        return pts
    pts = np.array(pts)
    start = pts[0]
    end = pts[-1]
    
    line_vec = end - start
    line_len = np.hypot(line_vec[0], line_vec[1])
    if line_len == 0:
        dists = np.hypot(pts[:,0] - start[0], pts[:,1] - start[1])
    else:
        # 2D cross product
        dists = np.abs(line_vec[0] * (pts[:,1] - start[1]) - line_vec[1] * (pts[:,0] - start[0])) / line_len
        
    idx = np.argmax(dists)
    max_d = dists[idx]
    
    if max_d > tol:
        left = simplify_dp(pts[:idx+1], tol)
        right = simplify_dp(pts[idx:], tol)
        return list(left[:-1]) + list(right)
    else:
        return [list(start), list(end)]

im = Image.open(r'c:\Users\araba\Desktop\SmartTransit\smart_transit_app\rive_splash\logo_true_alpha.png')
arr = np.array(im)

is_pin = (arr[:,:,3] > 100) & (arr[:,:,2] > 140) & (arr[:,:,0] < 80)
pin_mask = np.zeros_like(is_pin)
# Pin is x > 580, y < 130
pin_mask[0:130, 580:667] = is_pin[0:130, 580:667]

pin_contours = get_contours(pin_mask)
print(f'Found {len(pin_contours)} pin contours')
for i, c in enumerate(pin_contours):
    simplified = simplify_dp(c, 1.5)
    print(f'Pin Contour {i}: {len(c)} points -> {len(simplified)} points simplified')

