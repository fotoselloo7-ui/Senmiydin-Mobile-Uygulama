"""Exports the final Google Play / App Store graphics from the ChatGPT-designed marketing images.

Inputs (outside the repo, never committed):
  <ART>/chatgpt/<lang>/*.png        8 designed screenshots per language (~852x1846), in store order
  <ART>/chatgpt/senmiydin_chatgpt_bg_2_1794x876.png   abstract feature-graphic background (no text)
  <ART>/<lang>/01-home.png, 03-map.png ...            raw device screenshots (feature graphic phones)
  build/store-art/logo_cutout.png                      python tool/make_logo_cutout.py
Outputs: <ART>/final/play/<lang>/phone-01..08.png (1080x2160), feature-graphic.png (1024x500), icon-512.png
         <ART>/final/appstore/<lang>/iphone-6.9-01..08.png (1320x2868) and iphone-6.3-01..08.png (1179x2556, the required
         "iPhone with Dynamic Island (medium display)" slot), RGB, no alpha.
Run: python tool/make_store_graphics.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ART = Path("C:/Users/pc/store-screenshots")
FONT = ROOT / "assets/fonts/NunitoSans.ttf"
TAGLINE = {
    "en": ["Reconnect with the people", "you crossed paths with."],
    "tr": ["Yolun kesiştiği insanlarla", "yeniden karşılaş."],
}
FEATURE_SHOTS = ["01-home.png", "08-chat.png"]


def font(size: int, weight: str = "ExtraBold") -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT), size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def cover(im: Image.Image, w: int, h: int) -> Image.Image:
    s = max(w / im.width, h / im.height)
    r = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x, y = (r.width - w) // 2, (r.height - h) // 2
    return r.crop((x, y, x + w, y + h))


def fit_height(im: Image.Image, w: int, h: int) -> Image.Image:
    """Scale to the target height; the designed backgrounds are abstract, so a narrower image is padded left/right by
    mirroring its own edge columns (Google Play: long side <= 2x short side, so 1080x2160 is the tallest allowed)."""
    s = h / im.height
    r = im.resize((round(im.width * s), h), Image.LANCZOS)
    if r.width < w:
        total = w - r.width
        left = total // 2
        arr = np.pad(np.asarray(r), ((0, 0), (left, total - left), (0, 0)), mode="edge")
        return Image.fromarray(arr)
    x = (r.width - w) // 2
    return r.crop((x, 0, x + w, h))


def rounded(im: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def phone(shot: Image.Image, height: int) -> Image.Image:
    shot = shot.convert("RGB").crop((0, 70, shot.width, shot.height - 110))   # no Android status / nav bars
    w = round(shot.width * height / shot.height)
    screen = rounded(shot.resize((w, height), Image.LANCZOS), 22)
    border = 7
    frame = Image.new("RGBA", (w + 2 * border, height + 2 * border), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame.width - 1, frame.height - 1), 30, fill=(250, 248, 255, 255))
    frame.alpha_composite(screen, (border, border))
    return frame


def feature_graphic(lang: str) -> Image.Image:
    bg = cover(Image.open(ART / "chatgpt/senmiydin_chatgpt_bg_2_1794x876.png").convert("RGB"), 1024, 500).convert("RGBA")
    logo = Image.open(ROOT / "build/store-art/logo_cutout.png").convert("RGBA")
    lh = 215
    logo = logo.resize((round(logo.width * lh / logo.height), lh), Image.LANCZOS)
    bg.alpha_composite(logo, (58, 52))
    d = ImageDraw.Draw(bg)
    f = font(27, "Bold")
    for i, line in enumerate(TAGLINE[lang]):
        d.text((62, 300 + i * 38), line, font=f, fill=(255, 255, 255, 255))
    for k, name in enumerate(FEATURE_SHOTS):
        p = phone(Image.open(ART / lang / name), 430)
        p = p.rotate(-6 if k == 0 else 5, expand=True, resample=Image.BICUBIC)
        shadow = Image.new("RGBA", p.size, (0, 0, 0, 0))
        shadow.putalpha(p.split()[3].point(lambda v: int(v * 0.45)))
        shadow = shadow.filter(ImageFilter.GaussianBlur(14))
        x, y = (610, 52) if k == 0 else (760, 92)
        bg.alpha_composite(shadow, (x + 6, y + 14))
        bg.alpha_composite(p, (x, y))
    return bg.convert("RGB")


def main() -> None:
    for lang in ("en", "tr"):
        gen = sorted((ART / "chatgpt" / lang).glob("*.png"))
        play = ART / "final/play" / lang
        apple = ART / "final/appstore" / lang
        play.mkdir(parents=True, exist_ok=True)
        apple.mkdir(parents=True, exist_ok=True)
        for i, p in enumerate(gen[:8], 1):
            im = Image.open(p).convert("RGB")
            fit_height(im, 1080, 2160).save(play / f"phone-{i:02d}.png", optimize=True)
            fit_height(im, 1320, 2868).save(apple / f"iphone-6.9-{i:02d}.png", optimize=True)
            fit_height(im, 1179, 2556).save(apple / f"iphone-6.3-{i:02d}.png", optimize=True)
        if (ART / lang / FEATURE_SHOTS[0]).exists():
            feature_graphic(lang).save(play / "feature-graphic.png", optimize=True)
        print(lang, len(gen), "designed screenshots")
    icon = Image.open(ROOT / "assets/brand/app_icon_master.png").convert("RGBA").resize((512, 512), Image.LANCZOS)
    for lang in ("en", "tr"):
        icon.save(ART / "final/play" / lang / "icon-512.png", optimize=True)


if __name__ == "__main__":
    main()
