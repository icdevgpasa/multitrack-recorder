#!/usr/bin/env python3
"""Frames raw app screens into App Store screenshots (iPhone 6.9", 1320x2868).

    flutter test screenshots/app_screens_test.dart   # -> screenshots/raw/<locale>/
    python3 tool/frame_screenshots.py                # -> fastlane/screenshots/<locale>/

Needs Pillow (pip3 install pillow). Fonts: Roboto from the Flutter SDK.
"""
import os
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "screenshots" / "raw"
OUT = ROOT / "fastlane" / "screenshots"
W, H = 1320, 2868

CAPTIONS = {
    "en-US": {
        "01_studio": ("Your pocket\nmultitrack studio", "Guitar, bass, vocals. Every take in time."),
        "02_recording": ("Overdub while\nyou listen", "Record the next track over the ones you have."),
        "03_export": ("Export the mix\nor every track", "M4A, 24-bit WAV and stems for your DAW."),
        "04_songs": ("All your songs\nin one place", "No account, no ads. It stays on your phone."),
    },
    "pl": {
        "01_studio": ("Studio wielościeżkowe\nw kieszeni", "Gitara, bas, wokal. Każde nagranie równo w czasie."),
        "02_recording": ("Nagrywaj,\nsłuchając reszty", "Dogrywaj kolejne ścieżki do tego, co już masz."),
        "03_export": ("Eksportuj miks\nlub każdą ścieżkę", "M4A, WAV 24-bit i osobne ślady do DAW."),
        "04_songs": ("Wszystkie utwory\nw jednym miejscu", "Bez konta i reklam. Nagrania zostają w telefonie."),
    },
}

ACCENT = {
    "01_studio": (124, 92, 255),
    "02_recording": (255, 59, 92),
    "03_export": (0, 209, 193),
    "04_songs": (255, 178, 56),
}


def font_dir() -> Path:
    root = os.environ.get("FLUTTER_ROOT")
    if not root:
        flutter = shutil.which("flutter")
        if not flutter:
            raise SystemExit("flutter not on PATH (needed for the Roboto font)")
        root = str(Path(os.path.realpath(flutter)).parent.parent)
    d = Path(root) / "bin" / "cache" / "artifacts" / "material_fonts"
    if not d.exists():
        subprocess.run(["flutter", "precache"], check=False)
    return d


def background(accent):
    top, mid, bottom = (21, 16, 51), (11, 12, 22), (7, 19, 26)
    col = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / H
        a, b, k = (top, mid, t * 2) if t < 0.5 else (mid, bottom, (t - 0.5) * 2)
        col.putpixel((0, y), tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)))
    img = col.resize((W, H))
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    ImageDraw.Draw(glow).ellipse((W * 0.1, H * 0.32, W * 0.9, H * 0.8), fill=accent)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    return Image.blend(img, glow, 0.28)


def rounded(im, r):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *im.size), r, fill=255)
    out = im.copy()
    out.putalpha(mask)
    return out


def frame(raw: Path, title: str, sub: str, accent, fonts: Path) -> Image.Image:
    bold = ImageFont.truetype(str(fonts / "Roboto-Bold.ttf"), 112)
    reg = ImageFont.truetype(str(fonts / "Roboto-Regular.ttf"), 52)
    img = background(accent).convert("RGBA")
    d = ImageDraw.Draw(img)

    y = 150
    d.multiline_text((W / 2, y), title, font=bold, fill=(236, 238, 255),
                     anchor="ma", align="center", spacing=18)
    y += d.multiline_textbbox((W / 2, y), title, font=bold, anchor="ma", spacing=18)[3] - y + 44
    d.text((W / 2, y), sub, font=reg, fill=(176, 180, 214), anchor="ma")

    # The whole screen, rounded like the device, below the caption.
    y0 = 700
    scale = (H - y0 - 90) / H
    shot = Image.open(raw).convert("RGB").resize((int(W * scale), int(H * scale)), Image.LANCZOS)
    sw, sh = shot.size
    x0 = (W - sw) // 2
    bezel = 18
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x0 - bezel, y0 - bezel + 30, x0 + sw + bezel, y0 + sh + bezel + 30), 120, fill=(0, 0, 0, 170))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(40)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x0 - bezel, y0 - bezel, x0 + sw + bezel, y0 + sh + bezel), 120,
                        fill=(24, 26, 40), outline=(*accent, 160), width=4)
    img.alpha_composite(rounded(shot, 104), (x0, y0))
    return img.convert("RGB")


def main():
    fonts = font_dir()
    for locale, caps in CAPTIONS.items():
        out = OUT / locale
        out.mkdir(parents=True, exist_ok=True)
        for i, (name, (title, sub)) in enumerate(caps.items(), 1):
            raw = RAW / locale / f"{name}.png"
            if not raw.exists():
                raise SystemExit(f"missing {raw}: run flutter test screenshots/app_screens_test.dart first")
            # deliver orders by file name; the 6.9" size is detected from the pixels.
            dst = out / f"{i}_iphone69_{name}.png"
            frame(raw, title, sub, ACCENT[name], fonts).save(dst, optimize=True)
            print(dst.relative_to(ROOT))


if __name__ == "__main__":
    main()
