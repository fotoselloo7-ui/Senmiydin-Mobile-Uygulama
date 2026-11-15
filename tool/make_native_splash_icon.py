"""Builds the Android native splash icon so the system splash matches the Flutter splash (lib/screens/auth.dart).

Source: tool/source_art/splash_eyeless_full.png + pupil_left/right.png, the same layers the Flutter splash draws. The pupils are
placed exactly where the Flutter splash starts (gaze centre), so the hand-over from the system splash to the animated
splash has the same picture. Only a soft disc around the torn-paper mark is used (it must fit the 192 dp circle that
Android masks the icon to); its edge fades into the native background colour, which is the average colour of the
artwork around the mark. No new logo is drawn: every pixel comes from the approved artwork.

Outputs: android/app/src/main/res/drawable-nodpi/native_splash_icon.png (1152x1152 RGBA, 288 dp @ xxxhdpi) and prints
the launch background colour for res/values/colors.xml and lib/screens/auth.dart.

Run: python tool/make_native_splash_icon.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BRAND = ROOT / "assets/brand"
CANVAS = 1152              # 288 dp @ xxxhdpi, the Android 12 SplashScreen icon canvas
SAFE_RADIUS = 372          # the 192 dp mask circle has radius 384 px; keep a small margin
MARK_CENTER = (560, 745)   # centre of the torn-paper mark in the 1080x1920 artwork
DISC = 330                 # artwork radius that contains the paper ring and the three sparks
FEATHER = 90               # soft edge (artwork px) that fades into the background colour
WORDMARK_TOP = 997         # first artwork row that may contain the wordmark letters

# Gaze centre of the Flutter splash (SplashPage._leftPupilCenter / _rightPupilCenter at t = 0).
LEFT = dict(center=(524.0, 824.0), size=(56, 66), sclera=(515.8, 831.2, 78.5, 76.6), image="pupil_left.png")
RIGHT = dict(center=(656.0, 791.0), size=(48, 58), sclera=(648.53, 793.66, 64.9, 65.4), image="pupil_right.png")


def composite_start_frame() -> Image.Image:
    art = Image.open(ROOT / "tool/source_art/splash_eyeless_full.png").convert("RGBA")  # full-size mark (the in-app splash uses a smaller copy)
    for eye in (LEFT, RIGHT):
        cx, cy, rx, ry = eye["sclera"]
        clip = Image.new("L", art.size, 0)
        ImageDraw.Draw(clip).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
        pupil = Image.open(BRAND / eye["image"]).convert("RGBA").resize(eye["size"], Image.LANCZOS)
        layer = Image.new("RGBA", art.size, (0, 0, 0, 0))
        px, py = eye["center"]
        layer.alpha_composite(pupil, (round(px - eye["size"][0] / 2), round(py - eye["size"][1] / 2)))
        # Same as the ClipOval of the Flutter splash.
        alpha = np.minimum(np.array(layer.split()[3]), np.array(clip))
        layer.putalpha(Image.fromarray(alpha))
        art.alpha_composite(layer)
    return art


def background_color(frame: Image.Image) -> tuple:
    """Average colour of the artwork in the ring just outside the disc: what the native surface should look like."""
    rgb = np.array(frame.convert("RGB")).astype(float)
    h, w = rgb.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    dist = np.hypot(xx - MARK_CENTER[0], yy - MARK_CENTER[1])
    ring = (dist > DISC - 20) & (dist < DISC + 40) & (rgb.max(axis=2) < 170)  # skip paper, sparks and the wordmark
    return tuple(int(round(v)) for v in np.median(rgb[ring], axis=0))


def main() -> None:
    frame = composite_start_frame()
    bg = background_color(frame)
    cx, cy = MARK_CENTER
    crop = frame.crop((cx - DISC, cy - DISC, cx + DISC, cy + DISC))
    # Radial alpha: opaque inside, fading to transparent at the disc edge.
    size = crop.width
    yy, xx = np.mgrid[0:size, 0:size]
    radius = np.hypot(xx - (size - 1) / 2, yy - (size - 1) / 2)
    alpha = np.clip((DISC - radius) / FEATHER, 0.0, 1.0)
    alpha = alpha * alpha * (3 - 2 * alpha)  # smoothstep
    # The tops of the wordmark letters start just below the paper ring: cut them off (the mark is shown alone).
    art_y = yy + (cy - DISC)
    alpha = alpha * np.clip((WORDMARK_TOP - art_y) / 8.0, 0.0, 1.0)
    crop.putalpha(Image.fromarray((alpha * 255).astype(np.uint8)))
    scale = SAFE_RADIUS / DISC
    glyph = crop.resize((round(size * scale), round(size * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(glyph, ((CANVAS - glyph.width) // 2, (CANVAS - glyph.height) // 2))
    out = ROOT / "android/app/src/main/res/drawable-nodpi/native_splash_icon.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, optimize=True)
    print(out.relative_to(ROOT), canvas.size, "background", "#%02X%02X%02X" % bg)


if __name__ == "__main__":
    main()
