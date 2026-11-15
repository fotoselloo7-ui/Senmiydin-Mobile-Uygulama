"""Builds the Android native splash icon (icon only, transparent background) from the approved final splash artwork.

Source: assets/brand/splash_master.png (the final SenMiydin? splash). Only the icon part is used: the torn-paper hole,
the eyes and the three sparks; the wordmark and the purple surface are left out. The result is a 1152x1152 PNG
(288 dp at xxxhdpi, Android 12 SplashScreen icon canvas) whose artwork stays inside the 192 dp circle that Android masks
to, so the eyes are never cropped. No new logo is drawn: pixels come from the approved artwork.

Run: python tool/make_native_splash_icon.py
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/brand/splash_master.png"
CANVAS = 1152          # 288 dp @ xxxhdpi
SAFE_RADIUS = 372      # 192 dp circle = radius 384 px; keep a small margin
CROP = (200, 440, 900, 1060)  # icon region inside the 1080x1920 master (excludes the wordmark)


def main() -> None:
    rgb = np.array(Image.open(SOURCE).convert("RGB").crop(CROP))
    r, g, b = (rgb[..., i].astype(int) for i in range(3))
    # Sparks are saturated pink-lilac; paper and eye whites are near-white lilac.
    sparks = ((r > 215) & (b > 235) & (r - g > 38)).astype(np.uint8) * 255
    bright = ((rgb.min(axis=2) > 150) & (sparks == 0)).astype(np.uint8) * 255
    bright[-60:, :] = 0  # wordmark remnants at the bottom edge of the crop
    sparks[-60:, :] = 0
    sparks[300:, :] = 0   # sparks sit in the upper right; anything lower is wordmark
    sparks[:, :450] = 0
    # The torn-paper ring: keep its large pieces and fill the whole ring (the dark hole with the eyes is inside it).
    count, labels, stats, _ = cv2.connectedComponentsWithStats(bright, 8)
    keep = np.zeros_like(bright)
    for index in range(1, count):
        if stats[index, cv2.CC_STAT_AREA] > 1500:
            keep[labels == index] = 255
    points = cv2.findNonZero(keep)
    hull = cv2.convexHull(points)
    hull_mask = np.zeros_like(bright)
    cv2.fillConvexPoly(hull_mask, hull, 255)
    # The hull of the paper ring, with its corners rounded (blur + threshold) so it reads as the torn hole's outline.
    mask = cv2.GaussianBlur(hull_mask, (0, 0), 14)
    mask = (mask > 150).astype(np.uint8) * 255
    mask = cv2.erode(mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13)))
    # The three sparks keep their own shape.
    sparks = cv2.morphologyEx(sparks, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    sparks = cv2.dilate(sparks, np.ones((3, 3), np.uint8))
    mask = cv2.bitwise_or(mask, sparks)
    soft = cv2.GaussianBlur(mask, (0, 0), 1.6)
    rgba = np.dstack([rgb, soft])
    glyph = Image.fromarray(rgba, "RGBA")
    box = glyph.getbbox()
    glyph = glyph.crop(box)

    # Scale so the farthest artwork pixel from the centre stays inside the safe radius.
    alpha = np.array(glyph.split()[3]) > 40
    ys, xs = np.nonzero(alpha)
    cx, cy = (glyph.width - 1) / 2, (glyph.height - 1) / 2
    farthest = float(np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max())
    scale = SAFE_RADIUS / farthest
    glyph = glyph.resize((round(glyph.width * scale), round(glyph.height * scale)), Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    # A soft brand-purple shadow gives the white paper a readable edge on the light splash surface.
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    offset = ((CANVAS - glyph.width) // 2, (CANVAS - glyph.height) // 2)
    shade = Image.new("RGBA", glyph.size, (91, 33, 182, 255))
    shade.putalpha(glyph.split()[3].point(lambda v: int(v * 0.32)))
    shadow.alpha_composite(shade, (offset[0], offset[1] + 10))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(glyph, offset)
    out = ROOT / "android/app/src/main/res/drawable-nodpi/native_splash_icon.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, optimize=True)
    print(out.relative_to(ROOT), canvas.size, f"glyph {glyph.size}, scale {scale:.3f}")


if __name__ == "__main__":
    main()
