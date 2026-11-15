"""Exports the approved logo (torn-paper mark + wordmark) as a transparent PNG for store graphics.

Same cut-out as make_splash_art_small.py, at full size. Output: build/store-art/logo_cutout.png (not committed).
Run: python tool/make_logo_cutout.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
M = (560.0, 745.0)
LOGO = (120, 360, 960, 1250)
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


# pupils at the gaze centre (same layers the Flutter splash draws), clipped to the eye whites
from PIL import ImageDraw
BR = ROOT / "assets/brand"
rgba = src.convert("RGBA")
for centre, size, sclera, img in (
    ((524.0, 824.0), (56, 66), (515.8, 831.2, 78.5, 76.6), "pupil_left.png"),
    ((656.0, 791.0), (48, 58), (648.53, 793.66, 64.9, 65.4), "pupil_right.png"),
):
    cx, cy, rx, ry = sclera
    clip = Image.new("L", rgba.size, 0)
    ImageDraw.Draw(clip).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    pupil = Image.open(BR / img).convert("RGBA").resize(size, Image.LANCZOS)
    layer = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    layer.alpha_composite(pupil, (round(centre[0] - size[0] / 2), round(centre[1] - size[1] / 2)))
    layer.putalpha(Image.fromarray(np.minimum(np.array(layer.split()[3]), np.array(clip))))
    rgba.alpha_composite(layer)
a_orig = a
a = np.asarray(rgba.convert("RGB")).astype(np.float32)

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
px0, py0, px1, py1 = x0 + 10, y0 + 10, x1 - 10, y1   # box: mark + wordmark + swoosh
alpha_img = Image.fromarray((cut[py0:py1, px0:px1] * 255).astype(np.uint8))
rgb = Image.fromarray(a[py0:py1, px0:px1].astype(np.uint8)).convert("RGBA")
rgb.putalpha(alpha_img)
bbox = rgb.getbbox()
out = ROOT / "build/store-art/logo_cutout.png"
out.parent.mkdir(parents=True, exist_ok=True)
rgb.crop(bbox).save(out)
print(out, rgb.crop(bbox).size)
