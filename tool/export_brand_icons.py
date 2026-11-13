import json
import shutil
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent


def ensure_branding_final_mirror() -> Path:
    branding_final = ROOT / "branding_final"
    branding_final.mkdir(parents=True, exist_ok=True)
    if (ROOT / "README_BRANDING.txt").exists():
        shutil.copy2(ROOT / "README_BRANDING.txt", branding_final / "README_BRANDING.txt")
    for sub in ["logos", "app_icons", "splash"]:
        src = ROOT / sub
        dst = branding_final / sub
        if src.exists():
            dst.mkdir(parents=True, exist_ok=True)
            for f in src.iterdir():
                if f.is_file():
                    shutil.copy2(f, dst / f.name)
    return branding_final


def build_clean_icon_masters(master_icon_path: Path):
    """
    Returns:
      - full_bleed_1024 (RGBA, 100% opaque purple corners, for iOS AppIcon, adaptive icon, apple-touch-icon)
      - rounded_1024 (RGBA, transparent outer corners with zero white halo, for favicons & legacy Android mipmaps)
      - adaptive_fg_432 (RGBA, 432x432 Android adaptive icon foreground with safe-zone sizing and seamless purple bleed)
    """
    im = Image.open(master_icon_path).convert("RGBA")
    arr = np.array(im, dtype=np.float64)

    # Crop to 932x932 bounding box of the rounded square (46..978)
    crop = arr[47:979, 46:978].copy()
    H, W, _ = crop.shape
    yy, xx = np.mgrid[0:H, 0:W]

    R = 212.0
    dx = np.maximum(np.maximum(R - xx, xx - (W - 1 - R)), 0.0)
    dy = np.maximum(np.maximum(R - yy, yy - (H - 1 - R)), 0.0)
    corner_dist = np.sqrt(dx ** 2 + dy ** 2)

    clean_sq = crop.copy()
    for cy_corner, cx_corner in [(R, R), (R, W - 1 - R), (H - 1 - R, R), (H - 1 - R, W - 1 - R)]:
        m_corner = (np.abs(xx - cx_corner) <= R + 4) & (np.abs(yy - cy_corner) <= R + 4)
        if cx_corner < W / 2:
            m_corner &= xx <= cx_corner
        else:
            m_corner &= xx >= cx_corner
        if cy_corner < H / 2:
            m_corner &= yy <= cy_corner
        else:
            m_corner &= yy >= cy_corner

        vx = xx - cx_corner
        vy = yy - cy_corner
        dist = np.sqrt(vx ** 2 + vy ** 2)
        scale = 172.0 / np.maximum(dist, 1.0)
        sx = np.clip(np.round(cx_corner + vx * scale).astype(int), 0, W - 1)
        sy = np.clip(np.round(cy_corner + vy * scale).astype(int), 0, H - 1)
        w = np.clip((dist - 172.0) / 14.0, 0.0, 1.0)[..., None]
        reconstructed = (1.0 - w) * clean_sq[..., :3] + w * clean_sq[sy, sx, :3]
        clean_sq[m_corner, :3] = reconstructed[m_corner]

    for i in range(14):
        clean_sq[i, :, :3] = clean_sq[14, :, :3]
        clean_sq[H - 1 - i, :, :3] = clean_sq[H - 15, :, :3]
        clean_sq[:, i, :3] = clean_sq[:, 14, :3]
        clean_sq[:, W - 1 - i, :3] = clean_sq[:, W - 15, :3]

    full_bleed_1024 = Image.fromarray(np.clip(clean_sq, 0, 255).astype(np.uint8)).resize(
        (1024, 1024), Image.Resampling.LANCZOS
    )

    rounded_rgba = clean_sq.copy()
    alpha_mask = np.clip((205.0 - corner_dist) / 1.5, 0.0, 1.0)
    rounded_rgba[..., 3] = alpha_mask * 255.0
    rounded_1024 = Image.fromarray(np.clip(rounded_rgba, 0, 255).astype(np.uint8)).resize(
        (1024, 1024), Image.Resampling.LANCZOS
    )

    fg_size = 432
    inner_size = 296
    pad = (fg_size - inner_size) // 2
    inner_img = full_bleed_1024.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
    inner_arr = np.array(inner_img)

    fg_arr = np.zeros((fg_size, fg_size, 4), dtype=np.uint8)
    fg_arr[pad : pad + inner_size, pad : pad + inner_size] = inner_arr
    for y in range(pad):
        fg_arr[y, pad : pad + inner_size] = inner_arr[0, :]
    for y in range(pad + inner_size, fg_size):
        fg_arr[y, pad : pad + inner_size] = inner_arr[-1, :]
    for x in range(pad):
        fg_arr[:, x] = fg_arr[:, pad]
    for x in range(pad + inner_size, fg_size):
        fg_arr[:, x] = fg_arr[:, pad + inner_size - 1]
    adaptive_fg_432 = Image.fromarray(fg_arr)

    return full_bleed_1024, rounded_1024, adaptive_fg_432


def build_surgical_splash_layers(splash_master_path: Path):
    splash_img = Image.open(splash_master_path).convert("RGBA")
    splash_arr = np.array(splash_img, dtype=np.float64)

    X0, Y0, X1, Y1 = 400, 690, 740, 940
    crop_arr = splash_arr[Y0:Y1, X0:X1].copy()
    H, W, _ = crop_arr.shape
    yy, xx = np.mgrid[0:H, 0:W]
    orig_lum = 0.299 * crop_arr[..., 0] + 0.587 * crop_arr[..., 1] + 0.114 * crop_arr[..., 2]

    rcx, rcy, rrx, rry = 248.53, 103.66, 65.90, 66.36
    r_dx = (xx - rcx) / rrx
    r_dy = (yy - rcy) / rry
    r_rho = np.sqrt(r_dx ** 2 + r_dy ** 2)
    r_theta = np.arctan2(r_dy, r_dx)

    lcx, lcy, lrx, lry = 115.80, 141.20, 79.50, 77.60
    l_dx = (xx - lcx) / lrx
    l_dy = (yy - lcy) / lry
    l_rho = np.sqrt(l_dx ** 2 + l_dy ** 2)
    l_theta = np.arctan2(l_dy, l_dx)

    def build_clean_sclera_field(img_arr, rho, theta, px, py, prx, pry, t_top, t_bot):
        p_dist = np.sqrt(((xx - px) / prx) ** 2 + ((yy - py) / pry) ** 2)
        lum = 0.299 * img_arr[..., 0] + 0.587 * img_arr[..., 1] + 0.114 * img_arr[..., 2]

        n_bins = 220
        max_r = 1.08
        rho_bins = np.linspace(0.0, max_r, n_bins + 1)
        top_rgb = np.zeros((n_bins, 3))
        bot_rgb = np.zeros((n_bins, 3))

        for i in range(n_bins):
            r0, r1 = rho_bins[i], rho_bins[i + 1]
            rmask = (rho >= max(0.0, r0 - 0.02)) & (rho < r1 + 0.02) & (p_dist > 1.25) & (lum > 155)
            m_top = rmask & (theta >= t_top[0]) & (theta <= t_top[1])
            m_bot = rmask & (theta >= t_bot[0]) & (theta <= t_bot[1])
            if m_top.sum() > 0:
                top_rgb[i] = np.median(img_arr[m_top, :3], axis=0)
            elif i > 0:
                top_rgb[i] = top_rgb[i - 1]
            else:
                top_rgb[i] = [245, 244, 248]

            if m_bot.sum() > 0:
                bot_rgb[i] = np.median(img_arr[m_bot, :3], axis=0)
            elif i > 0:
                bot_rgb[i] = bot_rgb[i - 1]
            else:
                bot_rgb[i] = [245, 244, 248]

        kernel = np.array([0.15, 0.2, 0.3, 0.2, 0.15])
        for c in range(3):
            top_rgb[:, c] = np.convolve(np.pad(top_rgb[:, c], 2, mode="edge"), kernel, mode="valid")
            bot_rgb[:, c] = np.convolve(np.pad(bot_rgb[:, c], 2, mode="edge"), kernel, mode="valid")

        rho_idx = np.clip((rho / max_r * n_bins).astype(int), 0, n_bins - 1)
        val_top = top_rgb[rho_idx]
        val_bot = bot_rgb[rho_idx]

        t_top_mid = 0.5 * (t_top[0] + t_top[1])
        t_bot_mid = 0.5 * (t_bot[0] + t_bot[1])
        w = np.clip((theta - t_top_mid) / (t_bot_mid - t_top_mid), 0.0, 1.0)
        w = 0.5 - 0.5 * np.cos(np.pi * w)
        synth = (1.0 - w[..., None]) * val_top + w[..., None] * val_bot
        return synth, p_dist

    out = crop_arr.copy()

    r_synth, r_pdist = build_clean_sclera_field(
        out, r_rho, r_theta, px=289.2, py=94.6, prx=24.5, pry=30.0, t_top=(-1.05, -0.68), t_bot=(0.45, 0.85)
    )
    r_alpha = np.clip((1.30 - r_pdist) / 0.25, 0.0, 1.0)
    r_alpha = 0.5 - 0.5 * np.cos(np.pi * r_alpha)
    r_rim_mask = np.clip((1.012 - r_rho) / 0.012, 0.0, 1.0)
    r_weight = (r_alpha * r_rim_mask)[..., None]
    out[:, :, :3] = r_weight * r_synth + (1.0 - r_weight) * out[:, :, :3]

    l_synth, l_pdist = build_clean_sclera_field(
        out, l_rho, l_theta, px=164.2, py=123.6, prx=28.0, pry=33.6, t_top=(-1.15, -0.78), t_bot=(0.28, 0.65)
    )
    l_alpha = np.clip((1.26 - l_pdist) / 0.20, 0.0, 1.0)
    l_alpha = 0.5 - 0.5 * np.cos(np.pi * l_alpha)

    r_left_synth, _ = build_clean_sclera_field(
        out, r_rho, np.abs(r_theta), px=164.2, py=123.6, prx=28.0, pry=33.6, t_top=(2.1, 2.45), t_bot=(2.45, 2.8)
    )

    l_to_r_blend = np.clip((0.995 - l_rho) / 0.040, 0.0, 1.0)
    seam_shadow = np.exp(-(((l_rho - 0.985) / 0.022) ** 2))
    seam_color = np.array([196.0, 186.0, 216.0])

    bridge_target = l_to_r_blend[..., None] * l_synth + (1.0 - l_to_r_blend[..., None]) * r_left_synth
    bridge_target = (1.0 - 0.35 * seam_shadow[..., None]) * bridge_target + (0.35 * seam_shadow[..., None]) * seam_color

    pinch_zone = ((xx >= 177) & (yy <= 94)) | ((xx >= 192) & (yy >= 149)) | (yy <= 89)
    pinch_protect = np.where(pinch_zone, np.clip((orig_lum - 60.0) / 50.0, 0.0, 1.0), 1.0)
    l_weight = (l_alpha * pinch_protect)[..., None]
    out[:, :, :3] = l_weight * bridge_target + (1.0 - l_weight) * out[:, :, :3]

    eyeless_full_arr = splash_arr.copy()
    eyeless_full_arr[Y0:Y1, X0:X1] = np.clip(out, 0, 255)
    eyeless_full_img = Image.fromarray(eyeless_full_arr.astype(np.uint8))

    def extract_pupil_sprite(src_crop, cx, cy, rx, ry, out_w, out_h):
        x_grid = np.linspace(cx - out_w / 2.0 + 0.5, cx + out_w / 2.0 - 0.5, out_w)
        y_grid = np.linspace(cy - out_h / 2.0 + 0.5, cy + out_h / 2.0 - 0.5, out_h)
        xg, yg = np.meshgrid(x_grid, y_grid)
        x0 = np.floor(xg).astype(int)
        y0 = np.floor(yg).astype(int)
        x1 = np.clip(x0 + 1, 0, src_crop.shape[1] - 1)
        y1 = np.clip(y0 + 1, 0, src_crop.shape[0] - 1)
        wx = (xg - x0)[..., None]
        wy = (yg - y0)[..., None]
        rgb = (
            (1 - wx) * (1 - wy) * src_crop[y0, x0, :3]
            + wx * (1 - wy) * src_crop[y0, x1, :3]
            + (1 - wx) * wy * src_crop[y1, x0, :3]
            + wx * wy * src_crop[y1, x1, :3]
        )
        erho = np.sqrt(((xg - cx) / rx) ** 2 + ((yg - cy) / ry) ** 2)
        alpha = np.clip((1.02 - erho) / 0.07, 0.0, 1.0)
        rgba = np.zeros((out_h, out_w, 4), dtype=np.uint8)
        rgba[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        rgba[..., 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
        return Image.fromarray(rgba)

    pupil_left_img = extract_pupil_sprite(crop_arr, cx=163.8, cy=124.2, rx=25.2, ry=30.8, out_w=56, out_h=66)
    pupil_right_img = extract_pupil_sprite(crop_arr, cx=289.2, cy=94.6, rx=21.2, ry=26.6, out_w=48, out_h=58)

    return eyeless_full_img, pupil_left_img, pupil_right_img


def render_splash_gaze(eyeless_full_img: Image.Image, pupil_left_img: Image.Image, pupil_right_img: Image.Image, t: float) -> Image.Image:
    base = eyeless_full_img.copy()
    if t < 0:
        s = -t
        lpx = 524.0 * (1 - s) + 488.0 * s
        lpy = 824.0 * (1 - s) + 826.0 * s
        rpx = 656.0 * (1 - s) + 624.0 * s
        rpy = 791.0 * (1 - s) + 793.0 * s
    else:
        s = t
        lpx = 524.0 * (1 - s) + 562.0 * s
        lpy = 824.0 * (1 - s) + 815.0 * s
        rpx = 656.0 * (1 - s) + 688.0 * s
        rpy = 791.0 * (1 - s) + 784.0 * s

    layer_l = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer_l.paste(pupil_left_img, (int(round(lpx - pupil_left_img.width / 2)), int(round(lpy - pupil_left_img.height / 2))))
    mask_l = Image.new("L", base.size, 0)
    draw_l = ImageDraw.Draw(mask_l)
    draw_l.ellipse([515.8 - 78.5, 831.2 - 76.6, 515.8 + 78.5, 831.2 + 76.6], fill=255)
    base = Image.composite(Image.alpha_composite(base, layer_l), base, mask_l)

    layer_r = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer_r.paste(pupil_right_img, (int(round(rpx - pupil_right_img.width / 2)), int(round(rpy - pupil_right_img.height / 2))))
    mask_r = Image.new("L", base.size, 0)
    draw_r = ImageDraw.Draw(mask_r)
    draw_r.ellipse([648.53 - 64.9, 793.66 - 65.4, 648.53 + 64.9, 793.66 + 65.4], fill=255)
    base = Image.composite(Image.alpha_composite(base, layer_r), base, mask_r)
    return base


def build_native_splash_square(splash_master_path: Path, size: int = 768) -> Image.Image:
    """
    Creates a square native splash icon on #1E0245 background with the central mascot + SenMiydin? wordmark
    scaled into the central safe zone for Android 12+ SplashScreen API and iOS LaunchImage.
    """
    splash = Image.open(splash_master_path).convert("RGBA")
    # Crop central illustration (x=140..940, y=500..1500 -> 800x1000)
    central = splash.crop((140, 480, 940, 1520))
    canvas = Image.new("RGBA", (size, size), (30, 2, 69, 255))
    target_h = int(size * 0.64)
    target_w = int(target_h * central.width / central.height)
    resized = central.resize((target_w, target_h), Image.Resampling.LANCZOS)
    ox = (size - target_w) // 2
    oy = (size - target_h) // 2
    canvas.paste(resized, (ox, oy), resized)
    return canvas


def build_clean_primary_logo(logo_light_path: Path) -> Image.Image:
    """
    Removes the opaque #FEFDFE exterior background from senmiydin_logo_primary_light_2048x683.png
    while keeping the mascot's white torn paper and white sclera 100% solid opaque white.
    Preserves exact 2048x683 dimensions and aspect ratio.
    """
    im = Image.open(logo_light_path).convert("RGBA")
    arr = np.array(im, dtype=np.float64)
    H, W, _ = arr.shape
    yy, xx = np.mgrid[0:H, 0:W]

    mascot_zone = (((xx - 395.0) / 265.0) ** 2 + ((yy - 355.0) / 235.0) ** 2) <= 1.0
    mascot_purple = mascot_zone & (arr[:, :, 1] < 228)
    mascot_interior = np.zeros((H, W), dtype=bool)
    for y in range(H):
        xs = np.where(mascot_purple[y])[0]
        if len(xs) >= 2:
            mascot_interior[y, xs[0] : xs[-1] + 1] = True
    for x in range(680):
        ys = np.where(mascot_purple[:, x])[0]
        if len(ys) >= 2:
            mascot_interior[ys[0] : ys[-1] + 1, x] &= True
        else:
            mascot_interior[:, x] = False

    bg = np.array([254.0, 253.5, 254.0])
    alpha_needed = np.max((bg - arr[:, :, :3]) / bg, axis=2)
    alpha_needed = np.clip(alpha_needed, 0.0, 1.0)
    alpha_ext = np.clip((alpha_needed - 0.012) / (1.0 - 0.012), 0.0, 1.0)
    alpha = np.where(mascot_interior, 1.0, alpha_ext)

    fg_rgb = np.zeros_like(arr[:, :, :3])
    for c in range(3):
        unmult = (arr[:, :, c] - (1.0 - alpha) * bg[c]) / np.maximum(alpha, 1e-4)
        fg_rgb[:, :, c] = np.where(mascot_interior, arr[:, :, c], np.clip(unmult, 0.0, 255.0))

    out_rgba = np.zeros((H, W, 4), dtype=np.uint8)
    out_rgba[:, :, :3] = np.round(fg_rgb).astype(np.uint8)
    out_rgba[:, :, 3] = np.round(alpha * 255.0).astype(np.uint8)
    return Image.fromarray(out_rgba)


def build_og_image(clean_logo_light: Image.Image) -> Image.Image:
    """
    Creates a crisp 1200x630 OpenGraph social preview image using the final SenMiydin primary light logo.
    """
    W, H = 1200, 630
    bg = Image.new("RGBA", (W, H), (245, 247, 252, 255))
    draw = ImageDraw.Draw(bg)
    card_box = [56, 52, W - 56, H - 52]
    draw.rounded_rectangle(card_box, radius=36, fill=(255, 255, 255, 255), outline=(226, 232, 240, 255), width=2)

    logo_w = 880
    logo_h = int(round(logo_w * clean_logo_light.height / clean_logo_light.width))
    logo_resized = clean_logo_light.resize((logo_w, logo_h), Image.Resampling.LANCZOS)
    bg.alpha_composite(logo_resized, ((W - logo_w) // 2, (H - logo_h) // 2))
    return bg.convert("RGB")


def main():
    branding_final = ensure_branding_final_mirror()
    logo_light = branding_final / "logos" / "senmiydin_logo_primary_light_2048x683.png"
    logo_dark = branding_final / "logos" / "senmiydin_logo_reversed_dark_2048x683.png"
    logo_lilac = branding_final / "logos" / "senmiydin_logo_soft_lilac_2048x683.png"
    app_icon_master = branding_final / "app_icons" / "senmiydin_app_icon_master_1024.png"
    splash_master = branding_final / "splash" / "senmiydin_splash_master_1080x1920.png"

    clean_logo_light = build_clean_primary_logo(logo_light)

    # 1. Flutter assets/brand/
    assets_brand = ROOT / "assets" / "brand"
    assets_brand.mkdir(parents=True, exist_ok=True)
    clean_logo_light.save(assets_brand / "logo_primary_light.png")
    shutil.copy2(logo_dark, assets_brand / "logo_reversed_dark.png")
    shutil.copy2(logo_lilac, assets_brand / "logo_soft_lilac.png")
    shutil.copy2(splash_master, assets_brand / "splash_master.png")

    # Pre-filtered 900x300 header logo for ultra-crisp mobile rendering
    clean_logo_light.resize((900, 300), Image.Resampling.LANCZOS).save(assets_brand / "logo_header_light.png")

    full_bleed_1024, rounded_1024, adaptive_fg_432 = build_clean_icon_masters(app_icon_master)
    rounded_1024.save(assets_brand / "app_icon_master.png")

    eyeless_full_img, pupil_left_img, pupil_right_img = build_surgical_splash_layers(splash_master)
    eyeless_full_img.save(assets_brand / "splash_eyeless.png")
    pupil_left_img.save(assets_brand / "pupil_left.png")
    pupil_right_img.save(assets_brand / "pupil_right.png")

    # 2. Render 3 splash verification states
    branding_shots = ROOT / "docs" / "screenshots" / "branding"
    branding_shots.mkdir(parents=True, exist_ok=True)
    render_splash_gaze(eyeless_full_img, pupil_left_img, pupil_right_img, -1.0).save(
        branding_shots / "splash-eyes-left.png"
    )
    render_splash_gaze(eyeless_full_img, pupil_left_img, pupil_right_img, 0.0).save(
        branding_shots / "splash-eyes-center.png"
    )
    render_splash_gaze(eyeless_full_img, pupil_left_img, pupil_right_img, 1.0).save(
        branding_shots / "splash-eyes-right.png"
    )

    # 3. Android Launcher Icons & Native Splash
    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    mipmaps = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, sz in mipmaps.items():
        d = android_res / folder
        d.mkdir(parents=True, exist_ok=True)
        rounded_1024.resize((sz, sz), Image.Resampling.LANCZOS).save(d / "ic_launcher.png")

    drawable_xxxhdpi = android_res / "drawable-xxxhdpi"
    drawable_xxxhdpi.mkdir(parents=True, exist_ok=True)
    adaptive_fg_432.save(drawable_xxxhdpi / "brand_foreground.png")
    rounded_1024.resize((512, 512), Image.Resampling.LANCZOS).save(drawable_xxxhdpi / "brand_mark.png")
    native_splash_sq = build_native_splash_square(splash_master, 768)
    native_splash_sq.save(drawable_xxxhdpi / "brand_splash.png")

    # 4. iOS AppIcon.appiconset & LaunchImage.imageset
    ios_appicon = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if (ios_appicon / "Contents.json").exists():
        meta = json.loads((ios_appicon / "Contents.json").read_text(encoding="utf-8"))
        rgb_master = full_bleed_1024.convert("RGB")
        for item in meta.get("images", []):
            fn = item.get("filename")
            size_str = item.get("size", "0x0").split("x")[0]
            scale_str = item.get("scale", "1x").replace("x", "")
            if fn:
                px = int(round(float(size_str) * float(scale_str)))
                rgb_master.resize((px, px), Image.Resampling.LANCZOS).save(ios_appicon / fn)

    ios_launch = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    if ios_launch.exists():
        for fn, sz in [("LaunchImage.png", 240), ("LaunchImage@2x.png", 480), ("LaunchImage@3x.png", 720)]:
            native_splash_sq.resize((sz, sz), Image.Resampling.LANCZOS).save(ios_launch / fn)

    # 5. Web & Admin Logos, Favicons, Manifest, and OG Image
    web_dir = ROOT / "backend" / "public" / "web"
    web_dir.mkdir(parents=True, exist_ok=True)
    clean_logo_light.save(web_dir / "logo-primary-light.png")
    shutil.copy2(logo_dark, web_dir / "logo-reversed-dark.png")
    shutil.copy2(logo_lilac, web_dir / "logo-soft-lilac.png")

    for sz in [16, 32, 48, 64, 128]:
        rounded_1024.resize((sz, sz), Image.Resampling.LANCZOS).save(web_dir / f"favicon-{sz}x{sz}.png")

    full_bleed_1024.convert("RGB").resize((180, 180), Image.Resampling.LANCZOS).save(web_dir / "apple-touch-icon.png")
    rounded_1024.resize((192, 192), Image.Resampling.LANCZOS).save(web_dir / "icon-192.png")
    rounded_1024.resize((512, 512), Image.Resampling.LANCZOS).save(web_dir / "icon-512.png")
    rounded_1024.resize((512, 512), Image.Resampling.LANCZOS).save(web_dir / "brand.png")
    native_splash_sq.save(web_dir / "splash.png")

    # Multi-size favicon.ico in backend/public/favicon.ico and backend/public/web/favicon.ico
    ico_sizes = [(16, 16), (32, 32), (48, 48)]
    rounded_1024.save(ROOT / "backend" / "public" / "favicon.ico", format="ICO", sizes=ico_sizes)
    rounded_1024.save(web_dir / "favicon.ico", format="ICO", sizes=ico_sizes)

    # OpenGraph preview (1200x630)
    og_img = build_og_image(clean_logo_light)
    og_img.save(web_dir / "og.png")

    # Web Manifest
    manifest = {
        "name": "SenMiydin?",
        "short_name": "SenMiydin",
        "description": "Gördüğün ama konuşamadığın kişiyi konum ve zaman kesişmesiyle bul.",
        "start_url": "/",
        "display": "standalone",
        "background_color": "#ffffff",
        "theme_color": "#6D28D9",
        "icons": [
            {"src": "/web/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable"},
            {"src": "/web/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable"},
        ],
    }
    (ROOT / "backend" / "public" / "site.webmanifest").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("All brand icons, splash layers, favicons, and web assets exported successfully.")


if __name__ == "__main__":
    main()
