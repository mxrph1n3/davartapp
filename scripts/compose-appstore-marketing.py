#!/usr/bin/env python3
"""Compose App Store marketing screenshots from real device captures.

- Redacts profile name/phone
- Adds branded infographic chrome (headline + subtitle)
- Exports App Store sizes: 1320×2868, 1290×2796, 1242×2688, 1179×2556
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/Users/sadism/Documents/davartapp/apps/mobile/store_assets/appstore")
SRC = ROOT / "from_device"
OUT_MARKETING = ROOT / "marketing"
UPLOAD = ROOT / "upload"

# Brand
BG = (17, 17, 17)
ACCENT = (255, 221, 45)
WHITE = (255, 255, 255)
MUTED = (180, 180, 180)
PHONE_BEZEL = (28, 28, 28)
PHONE_EDGE = (55, 55, 55)

SIZES = {
    "iphone_6.7_1320": (1320, 2868),
    "iphone_6.7": (1290, 2796),
    "iphone_6.5_1284": (1284, 2778),  # iPhone 12/13 Pro Max — ASC 6.5" slot
    "iphone_6.5": (1242, 2688),       # iPhone 11 / XS Max — ASC 6.5" slot
    "iphone_6.1": (1179, 2556),
}

SCREENS = [
    {
        "src": "02_catalog_1320x2868.png",
        "stem": "01_catalog",
        "legacy": "screenshot_01_catalog",
        "title": "Каталог для комплектации",
        "subtitle": "Мебель, плитка и материалы — с ценами и в корзину",
        "redact": False,
    },
    {
        "src": "03_project_1320x2868.png",
        "stem": "02_projects",
        "legacy": "screenshot_02_project",
        "title": "Проекты со студией",
        "subtitle": "Ваши объекты, статусы и портфолио работ",
        "redact": False,
    },
    {
        "src": "04_profile_1320x2868.png",
        "stem": "03_profile",
        "legacy": "screenshot_03_profile",
        "title": "Всё под рукой",
        "subtitle": "Заказы, избранное, поддержка и настройки",
        "redact": True,
    },
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = (
        [
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
        ]
        if bold
        else [
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        ]
    )
    if bold:
        candidates = [
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/Library/Fonts/Arial Bold.ttf",
            "/System/Library/Fonts/SFNS.ttf",
        ] + candidates
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def redact_profile(im: Image.Image) -> Image.Image:
    """Blur/cover name + phone on logged-in profile (1320×2868 capture)."""
    out = im.convert("RGBA").copy()
    # Measured on from_device/04_profile_1320x2868.png
    avatar = (70, 520, 280, 730)
    name = (300, 545, 620, 620)
    phone = (300, 615, 780, 680)
    for box in (avatar, name, phone):
        crop = out.crop(box).filter(ImageFilter.GaussianBlur(radius=34))
        w, h = crop.size
        tiny = crop.resize((max(1, w // 20), max(1, h // 20)), Image.Resampling.BILINEAR)
        crop = tiny.resize((w, h), Image.Resampling.NEAREST)
        out.paste(crop, box[:2])

    draw = ImageDraw.Draw(out)
    # Solid covers so nothing of the original PII remains
    draw.ellipse(avatar, fill=(242, 242, 242, 255))
    draw.rounded_rectangle(name, radius=14, fill=(255, 255, 255, 255))
    draw.rounded_rectangle(phone, radius=12, fill=(255, 255, 255, 255))
    # Neutral placeholders
    draw.text((138, 580), "A", font=font(78, bold=True), fill=(170, 170, 170, 255))
    draw.text((320, 560), "Клиент DAVart", font=font(42, bold=True), fill=(40, 40, 40, 255))
    draw.text((320, 630), "+7 ••• ••• •• ••", font=font(30), fill=(150, 150, 150, 255))
    return out


def wrap_text(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont, max_w: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for w in words:
        trial = f"{cur} {w}".strip()
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


FRAME_PATH = ROOT / "frames" / "iphone_pro_max_frame.png"
FRAME_META_PATH = ROOT / "frames" / "iphone_pro_max_frame.json"


def load_iphone_frame() -> tuple[Image.Image, tuple[int, int, int, int]]:
    import json

    frame = Image.open(FRAME_PATH).convert("RGBA")
    meta = json.loads(FRAME_META_PATH.read_text())
    sx0, sy0, sx1, sy1 = meta["screen"]
    return frame, (sx0, sy0, sx1, sy1)


def fit_cover(im: Image.Image, tw: int, th: int) -> Image.Image:
    scale = max(tw / im.width, th / im.height)
    nw, nh = int(round(im.width * scale)), int(round(im.height * scale))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return resized.crop((left, top, left + tw, top + th))


def compose(screen: dict, canvas_w: int, canvas_h: int) -> Image.Image:
    src = Image.open(SRC / screen["src"]).convert("RGBA")
    if screen["redact"]:
        src = redact_profile(src)

    canvas = Image.new("RGBA", (canvas_w, canvas_h), (*BG, 255))
    draw = ImageDraw.Draw(canvas)

    # Soft yellow glow at top
    glow = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse(
        (-canvas_w * 0.2, -canvas_h * 0.08, canvas_w * 1.2, canvas_h * 0.28),
        fill=(*ACCENT, 38),
    )
    canvas = Image.alpha_composite(canvas, glow)
    draw = ImageDraw.Draw(canvas)

    # Brand chip
    chip_pad_x = int(canvas_w * 0.06)
    chip_y = int(canvas_h * 0.042)
    chip_font = font(max(22, int(canvas_w * 0.032)), bold=True)
    chip_text = "DAVart"
    chip_w = int(draw.textlength(chip_text, font=chip_font) + canvas_w * 0.05)
    chip_h = int(chip_font.size * 1.55)
    chip_box = (chip_pad_x, chip_y, chip_pad_x + chip_w, chip_y + chip_h)
    draw.rounded_rectangle(chip_box, radius=999, fill=ACCENT)
    tw = draw.textlength(chip_text, font=chip_font)
    draw.text(
        (
            chip_pad_x + (chip_w - tw) / 2,
            chip_y + (chip_h - chip_font.size) / 2 - 2,
        ),
        chip_text,
        font=chip_font,
        fill=BG,
    )

    # Headline
    title_font = font(max(42, int(canvas_w * 0.078)), bold=True)
    sub_font = font(max(24, int(canvas_w * 0.038)))
    text_x = int(canvas_w * 0.06)
    text_max = int(canvas_w * 0.88)
    title_y = int(canvas_h * 0.092)
    title_lines = wrap_text(draw, screen["title"], title_font, text_max)
    y = title_y
    for line in title_lines:
        draw.text((text_x, y), line, font=title_font, fill=WHITE)
        y += int(title_font.size * 1.12)

    y += int(canvas_h * 0.012)
    for line in wrap_text(draw, screen["subtitle"], sub_font, text_max):
        draw.text((text_x, y), line, font=sub_font, fill=MUTED)
        y += int(sub_font.size * 1.25)

    y += int(canvas_h * 0.01)
    draw.rounded_rectangle(
        (text_x, y, text_x + int(canvas_w * 0.14), y + max(6, int(canvas_h * 0.004))),
        radius=4,
        fill=ACCENT,
    )

    # --- Realistic iPhone frame ---
    frame, (sx0, sy0, sx1, sy1) = load_iphone_frame()
    top_chrome = int(canvas_h * 0.245)
    bottom_pad = int(canvas_h * 0.028)
    # Leave room for physical side buttons in the frame asset
    side_pad = int(canvas_w * 0.07)
    target_h = canvas_h - top_chrome - bottom_pad
    scale = target_h / frame.height
    target_w = int(round(frame.width * scale))
    if target_w > canvas_w - side_pad * 2:
        scale = (canvas_w - side_pad * 2) / frame.width
        target_w = int(round(frame.width * scale))
        target_h = int(round(frame.height * scale))

    frame_scaled = frame.resize((target_w, target_h), Image.Resampling.LANCZOS)
    phone_x = (canvas_w - target_w) // 2
    phone_y = top_chrome + (canvas_h - top_chrome - bottom_pad - target_h) // 2

    # Soft drop shadow under device
    shadow = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle(
        (
            phone_x + int(target_w * 0.06),
            phone_y + int(target_h * 0.02),
            phone_x + target_w - int(target_w * 0.06),
            phone_y + target_h + int(target_h * 0.012),
        ),
        radius=int(target_w * 0.12),
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(8, target_w // 40)))
    canvas = Image.alpha_composite(canvas, shadow)

    # Screen rect in canvas coords
    scr_x0 = phone_x + int(round(sx0 * scale))
    scr_y0 = phone_y + int(round(sy0 * scale))
    scr_x1 = phone_x + int(round(sx1 * scale))
    scr_y1 = phone_y + int(round(sy1 * scale))
    sw, sh = scr_x1 - scr_x0, scr_y1 - scr_y0

    fitted = fit_cover(src, sw, sh)
    # Slightly round screen corners under the frame
    screen_layer = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    radius = max(18, int(min(sw, sh) * 0.055))
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), radius=radius, fill=255)
    screen_layer.paste(fitted, (scr_x0, scr_y0), mask)
    canvas = Image.alpha_composite(canvas, screen_layer)

    # Device frame on top of screenshot
    canvas.paste(frame_scaled, (phone_x, phone_y), frame_scaled)
    return canvas.convert("RGB")


def export_all() -> None:
    OUT_MARKETING.mkdir(parents=True, exist_ok=True)
    for folder in ("iphone_6.7", "iphone_6.5", "iphone_6.1"):
        (UPLOAD / folder).mkdir(parents=True, exist_ok=True)
        # clear previous upload screenshots
        for f in (UPLOAD / folder).glob("*.png"):
            if f.name.startswith("icon"):
                continue
            f.unlink()
    for short in ("6.7", "6.5", "6.1"):
        (ROOT / short).mkdir(parents=True, exist_ok=True)
        for f in (ROOT / short).glob("screenshot_*.png"):
            f.unlink()

    for screen in SCREENS:
        master = compose(screen, 1320, 2868)
        master_path = OUT_MARKETING / f"{screen['stem']}_1320x2868.png"
        master.save(master_path, format="PNG", compress_level=1)
        print("master", master_path.name, master_path.stat().st_size)

        for key, (w, h) in SIZES.items():
            im = master if (w, h) == (1320, 2868) else master.resize((w, h), Image.Resampling.LANCZOS)
            if key == "iphone_6.7_1320":
                dest = UPLOAD / "iphone_6.7" / f"{screen['stem']}_1320x2868.png"
                im.save(dest, format="PNG", compress_level=1)
            elif key == "iphone_6.7":
                dest = UPLOAD / "iphone_6.7" / f"{screen['stem']}_1290x2796.png"
                im.save(dest, format="PNG", compress_level=1)
                (ROOT / "6.7" / f"{screen['legacy']}_1290x2796.png").write_bytes(dest.read_bytes())
            elif key == "iphone_6.5_1284":
                dest = UPLOAD / "iphone_6.5" / f"{screen['stem']}_1284x2778.png"
                im.save(dest, format="PNG", compress_level=1)
                req = UPLOAD / "asc_6.5_REQUIRED"
                req.mkdir(parents=True, exist_ok=True)
                im.save(req / f"{screen['stem']}_1284x2778.png", format="PNG", compress_level=1)
            elif key == "iphone_6.5":
                dest = UPLOAD / "iphone_6.5" / f"{screen['stem']}_1242x2688.png"
                im.save(dest, format="PNG", compress_level=1)
                (ROOT / "6.5" / f"{screen['legacy']}_1242x2688.png").write_bytes(dest.read_bytes())
                req = UPLOAD / "asc_6.5_REQUIRED"
                req.mkdir(parents=True, exist_ok=True)
                im.save(req / f"{screen['stem']}_1242x2688.png", format="PNG", compress_level=1)
            elif key == "iphone_6.1":
                dest = UPLOAD / "iphone_6.1" / f"{screen['stem']}_1179x2556.png"
                im.save(dest, format="PNG", compress_level=1)
                (ROOT / "6.1" / f"{screen['legacy']}_1179x2556.png").write_bytes(dest.read_bytes())
            print(" ", dest.name)

    print("DONE", OUT_MARKETING)


if __name__ == "__main__":
    export_all()
