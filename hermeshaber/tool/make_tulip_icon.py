#!/usr/bin/env python3
"""HermesHaber ters lale amblemi: tek kaynaktan SVG + PNG üretir.

Amblem, klasik lale siluetinin dikey olarak ters çevrilmiş halidir:
üç taç yaprağı aşağı bakar, gövde yukarı doğru uzanır.

Kullanım: python3 tool/make_tulip_icon.py
"""
from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
S = 96.0  # amblem koordinat uzayı (0..96)
MASTER = 1024  # ana raster boyutu
SS = 4  # süper örnekleme çarpanı

GOLD = (224, 184, 114)
GOLD_2 = (185, 135, 63)
DARK = (11, 15, 20)
INK = (19, 16, 9)

# --- Amblem geometrisi (96x96 kutu, y aşağı) -------------------------------
# Kapalı dış hat: taban (üstte) -> sağ dış yaprak -> çentik -> orta yaprak
# -> çentik -> sol dış yaprak -> taban.
OUTLINE = [
    ("M", (36.0, 31.0)),
    ("C", (36.0, 23.5), (60.0, 23.5), (60.0, 31.0)),      # üst taban (kaliks)
    ("C", (72.0, 41.0), (78.5, 57.0), (75.0, 75.0)),      # sağ dış yaprak dış kenarı
    ("C", (69.0, 73.0), (63.0, 69.0), (58.5, 63.5)),      # sağ çentik (içe dönüş)
    ("C", (56.5, 75.0), (53.0, 86.0), (48.0, 92.0)),      # orta yaprak sağ
    ("C", (43.0, 86.0), (39.5, 75.0), (37.5, 63.5)),      # orta yaprak sol
    ("C", (33.0, 69.0), (27.0, 73.0), (21.0, 75.0)),      # sol çentik
    ("C", (17.5, 57.0), (24.0, 41.0), (36.0, 31.0)),      # sol dış yaprak
    ("Z",),
]

# Gövde: üstte ince, tabana doğru hafif genişleyen, ucu yuvarlak.
STEM = [
    ("M", (46.4, 9.0)),
    ("C", (46.4, 6.9), (49.6, 6.9), (49.6, 9.0)),
    ("L", (49.9, 25.0)),
    ("C", (49.9, 28.2), (46.1, 28.2), (46.1, 25.0)),
    ("Z",),
]

# Yaprak ayrım çizgileri (arka plan rengiyle oyulur).
SLITS = [
    [("M", (46.4, 34.0)), ("C", (45.2, 43.0), (41.6, 53.0), (38.2, 62.0))],
    [("M", (49.6, 34.0)), ("C", (50.8, 43.0), (54.4, 53.0), (57.8, 62.0))],
]


def bezier(p0, p1, p2, p3, steps):
    out = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
        out.append((x, y))
    return out


def commands_to_points(cmds, steps=48):
    """(M/C/L/Z) komutlarını örneklenmiş nokta listesine çevirir."""
    pts = []
    cur = None
    for cmd in cmds:
        kind = cmd[0]
        if kind == "M":
            cur = cmd[1]
            pts.append(cur)
        elif kind == "L":
            cur = cmd[1]
            pts.append(cur)
        elif kind == "C":
            p1, p2, p3 = cmd[1], cmd[2], cmd[3]
            pts.extend(bezier(cur, p1, p2, p3, steps))
            cur = p3
        elif kind == "Z":
            pass
    return pts


def to_px(p, scale, offset=0.0):
    return (offset + p[0] * scale, offset + p[1] * scale)


def cmd_path_d(cmds, digits=2):
    """SVG path d metni."""
    parts = []
    for cmd in cmds:
        kind = cmd[0]
        if kind in ("M", "L"):
            parts.append(f"{kind}{cmd[1][0]:.{digits}f} {cmd[1][1]:.{digits}f}")
        elif kind == "C":
            parts.append(
                "C" + " ".join(f"{x:.{digits}f} {y:.{digits}f}" for x, y in cmd[1:])
            )
        else:
            parts.append("Z")
    return " ".join(parts)


def build_svg(with_background: bool, fg: str, bg: str = "#0b0f14") -> str:
    head = cmd_path_d(OUTLINE)
    stem = cmd_path_d(STEM)
    slits = "".join(
        f'<path d="{cmd_path_d(s)}" fill="none" stroke="{"%s" % bg}" '
        f'stroke-width="2.4" stroke-linecap="round"/>'
        for s in SLITS
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" role="img" aria-label="HermesHaber ters lale amblemi">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{GOLD_HEX}"/>
      <stop offset="1" stop-color="{GOLD2_HEX}"/>
    </linearGradient>
  </defs>
  {'<rect width="96" height="96" rx="22" fill="' + bg + '"/>' if with_background else ''}
  <path d="{head}" fill="url(#g)"/>
  <path d="{stem}" fill="url(#g)"/>
  {slits}
</svg>
"""


GOLD_HEX = "#e0b872"
GOLD2_HEX = "#b9873f"


def render(size: int, transparent: bool, color=GOLD, slits=True) -> Image.Image:
    big = size * SS
    scale = big / S
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    mask = Image.new("L", (big, big), 0)
    md = ImageDraw.Draw(mask)
    md.polygon([to_px(p, scale) for p in commands_to_points(OUTLINE)], fill=255)
    md.polygon(
        [to_px(p, scale) for p in commands_to_points(STEM, steps=24)], fill=255
    )

    if slits:
        for slit in SLITS:
            pts = [to_px(p, scale) for p in commands_to_points(slit, steps=32)]
            md.line(pts, fill=0, width=max(2, int(round(big * 0.024))), joint="curve")

    # Altın dikey gradyan (üst açık, alt koyu).
    grad = Image.new("RGBA", (big, big))
    gd = ImageDraw.Draw(grad)
    for y in range(big):
        t = y / max(1, big - 1)
        c = tuple(int(color[i] * (1 - t) + GOLD_2[i] * t) for i in range(3))
        gd.line([(0, y), (big, y)], fill=(*c, 255))
    img.paste(grad, (0, 0), mask)
    return img.resize((size, size), Image.LANCZOS)


def tile(size: int) -> Image.Image:
    """Koyu zemin + altın lale (uygulama simgesi)."""
    img = Image.new("RGBA", (size, size), (*DARK, 255))
    mark = render(int(size * 0.68), transparent=True)
    # Amblem simgenin ortasına yerleşsin.
    off = (size - mark.width) // 2
    img.alpha_composite(mark, (off, off))
    return img


def main() -> None:
    out = ROOT / "public" / "icons"
    out.mkdir(parents=True, exist_ok=True)
    app_assets = ROOT / "app" / "assets"
    app_assets.mkdir(parents=True, exist_ok=True)

    # SVG kaynakları
    (out / "tulip.svg").write_text(build_svg(True, GOLD_HEX), encoding="utf-8")
    (out / "tulip-mark.svg").write_text(build_svg(False, GOLD_HEX), encoding="utf-8")

    # Web simgeleri
    render(512, transparent=True).save(out / "tulip-512.png")
    render(180, transparent=True).save(out / "apple-touch-icon.png")
    render(96, transparent=True).save(out / "tulip-96.png")
    tile(512).save(out / "icon-512.png")
    tile(192).save(out / "icon-192.png")
    tile(32).save(out / "favicon-32.png")
    render(32, transparent=True).save(out / "favicon.png")

    # Flutter varlıkları
    render(1024, transparent=True).save(app_assets / "tulip_gold.png")
    render(1024, transparent=True, color=INK).save(app_assets / "tulip_ink.png")

    # Android başlatıcı simgeleri
    mdpi = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, size in mdpi.items():
        target = (
            ROOT
            / "app"
            / "android"
            / "app"
            / "src"
            / "main"
            / "res"
            / f"mipmap-{density}"
            / "ic_launcher.png"
        )
        target.parent.mkdir(parents=True, exist_ok=True)
        tile(size).save(target)

    print("üretildi:")
    for p in sorted(list(out.iterdir()) + list(app_assets.glob("tulip_*.png"))):
        print(f"  {p.relative_to(ROOT)} {p.stat().st_size} bayt")


if __name__ == "__main__":
    main()
