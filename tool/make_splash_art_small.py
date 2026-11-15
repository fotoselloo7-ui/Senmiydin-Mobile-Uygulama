"""Makes the smaller-logo splash artwork (assets/brand/splash_eyeless.png) from tool/source_art/splash_eyeless_full.png.

The approved artwork is untouched except that the logo group (torn-paper mark + wordmark) is scaled down around the
mark centre; the vacated area is rebuilt from the artwork's own smooth background. Pupils/sclera coordinates in
lib/screens/auth.dart are transformed with the same scale (SplashPage._logoScale / _logoCenter).

Run: python tool/make_splash_art_small.py [scale]   (default 0.74)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SCALE = float(sys.argv[1]) if len(sys.argv) > 1 else 0.74
M = (560.0, 745.0)                      # mark centre (artwork px) = scaling centre
LOGO = (120, 360, 960, 1250)            # x0, y0, x1, y1 of the logo group (artwork px)
FEATHER = 56

src = Image.open(ROOT / "tool/source_art/splash_eyeless_full.png").convert("RGB")
a = np.asarray(src).astype(np.float32)
H, W, _ = a.shape
x0, y0, x1, y1 = LOGO

# 1) clean background: harmonic (Laplace) fill of the logo box from the artwork around it, so it matches on all four
#    sides and stays smooth. Solved on a 1/8 grid, then upsampled and feathered into the artwork.
D = 8
ex0, ey0, ex1, ey1 = x0 - FEATHER, y0 - FEATHER, x1 + FEATHER, y1 + FEATHER
small = np.asarray(src.resize((W // D, H // D), Image.BOX)).astype(np.float32)
hx0, hy0, hx1, hy1 = ex0 // D, ey0 // D, ex1 // D, ey1 // D
fill = small.copy()
for c in range(3):
    # initial guess: linear blend of the row ends, then relax towards the Laplace solution
    g = fill[hy0 - 1:hy1 + 1, hx0 - 1:hx1 + 1, c].copy()
    inner = np.s_[1:-1, 1:-1]
    g[inner] = g[1:-1, :1].mean() if False else g[inner]
    for _ in range(6000):
        g[inner] = 0.25 * (g[:-2, 1:-1] + g[2:, 1:-1] + g[1:-1, :-2] + g[1:-1, 2:])
    fill[hy0 - 1:hy1 + 1, hx0 - 1:hx1 + 1, c] = g
fill_up = np.asarray(Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(np.float32)
alpha = np.zeros((H, W), np.float32)
alpha[ey0:ey1, ex0:ex1] = 1.0
ramp = np.linspace(0, 1, FEATHER)
alpha[ey0:ey0 + FEATHER, ex0:ex1] *= ramp[:, None]
alpha[ey1 - FEATHER:ey1, ex0:ex1] *= ramp[::-1][:, None]
alpha[ey0:ey1, ex0:ex0 + FEATHER] *= ramp[None, :]
alpha[ey0:ey1, ex1 - FEATHER:ex1] *= ramp[::-1][None, :]
base = a * (1 - alpha[..., None]) + fill_up * alpha[..., None]

# 2) logo cut-out (alpha from the difference to the rebuilt background), scaled about the mark centre and composited
px0, py0, px1, py1 = x0 - 20, y0 - 20, x1 + 20, y1 + 20
diff = np.abs(a - fill_up).max(axis=2)
cut = np.clip((diff - 38.0) / 42.0, 0.0, 1.0)          # 0 on the glow, 1 on paper / letters / eyes
cut = np.asarray(Image.fromarray((cut * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255.0
# the mark's soft shadow and the dark eye cores are close to the background: keep the whole mark disc opaque
yy, xx = np.mgrid[0:H, 0:W]
disc = (((xx - 565.0) ** 2 / 165.0 ** 2 + (yy - 790.0) ** 2 / 125.0 ** 2) <= 1.0).astype(np.float32)
disc = np.asarray(Image.fromarray((disc * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14))).astype(np.float32) / 255.0
cut = np.maximum(cut, disc)
cut_img = Image.fromarray((cut[py0:py1, px0:px1] * 255).astype(np.uint8))
rgb = Image.fromarray(a[py0:py1, px0:px1].astype(np.uint8))
nw, nh = round(rgb.width * SCALE), round(rgb.height * SCALE)
rgb = rgb.resize((nw, nh), Image.LANCZOS)
cut_img = cut_img.resize((nw, nh), Image.LANCZOS)
tx = round(M[0] + (px0 - M[0]) * SCALE)
ty = round(M[1] + (py0 - M[1]) * SCALE)
pa = np.asarray(cut_img).astype(np.float32) / 255.0
# feather the disc edge so its soft shadow melts into the background
out = base.copy()
region = out[ty:ty + nh, tx:tx + nw]
out[ty:ty + nh, tx:tx + nw] = region * (1 - pa[..., None]) + np.asarray(rgb).astype(np.float32) * pa[..., None]
Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(ROOT / "assets/brand/splash_eyeless.png", optimize=True)
print("scale", SCALE, "logo box now", tx, ty, tx + nw, ty + nh)
