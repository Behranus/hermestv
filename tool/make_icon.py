#!/usr/bin/env python3
"""bbtv uygulama simgesi — CachyOS koyu tonları.

Koyu zemin (#0d1017), gradyanlı "C" halkası (camgöbeği → mavi → mor →
pembe, CachyOS markasındaki gibi) ve açıklıkta beyaz oynat üçgeni.
"""

from PIL import Image, ImageDraw
import math
import sys

SIZE = 512


def lerp(a, b, t):
    return a + (b - a) * t


def gradient_color(angle_deg):
    """Açıya göre gradyan rengi: 30°→camgöbeği, 120°→mavi, 210°→mor, 300°→pembe."""
    stops = [
        (30, (0, 212, 255)),   # cyan
        (120, (56, 120, 255)),  # blue
        (210, (123, 47, 255)),  # purple
        (300, (255, 0, 170)),   # magenta/pink
    ]
    for i in range(len(stops) - 1):
        a0, c0 = stops[i]
        a1, c1 = stops[i + 1]
        if a0 <= angle_deg <= a1:
            t = (angle_deg - a0) / (a1 - a0)
            return tuple(int(lerp(c0[k], c1[k], t)) for k in range(3))
    return stops[0][1]


def build(size=SIZE):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx, cy = size / 2, size / 2

    # ---- Arka plan: koyu, köşelerde hafif vinyet ----
    for y in range(size):
        for x in range(size):
            dx, dy = (x - cx) / cx, (y - cy) / cy
            dist = math.sqrt(dx * dx + dy * dy)
            # Ortada #10131b, köşelere doğru #0a0c11
            t = min(1.0, dist / 1.5)
            r = int(lerp(16, 10, t))
            g = int(lerp(19, 12, t))
            b = int(lerp(27, 17, t))
            img.putpixel((x, y), (r, g, b, 255))

    # ---- "C" halkası: 30°–330° gradyanlı kalın yay ----
    r_outer = size * 0.36
    width = size * 0.13
    box = (cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer)
    start_deg, end_deg = 32, 328
    step = 3

    # Önce hafif dış parlama (arkada kalır), sonra opak gradyan halka.
    glow = ImageDraw.Draw(img)
    glow.arc(
        [cx - r_outer - 6, cy - r_outer - 6, cx + r_outer + 6, cy + r_outer + 6],
        start_deg, end_deg, fill=(0, 212, 255, 30), width=int(width + 14),
    )
    for a in range(start_deg, end_deg, step):
        color = gradient_color(a)
        d.arc(box, a, a + step + 1, fill=color + (255,), width=int(width))

    # ---- Açıklıkta beyaz oynat üçgeni ----
    # Halkanın açık ucu sağ tarafta (0°/360°) — üçgeni açıklığa yerleştir.
    px, py = cx + r_outer - size * 0.06, cy
    half_h = size * 0.10
    tip = size * 0.16
    tri = [(px, py - half_h), (px, py + half_h), (px + tip, py)]
    d.polygon(tri, fill=(255, 255, 255, 245))

    return img


def main():
    master = build(SIZE)
    if len(sys.argv) > 1:
        master.save(sys.argv[1])
    else:
        # Tüm yoğunlukları doğrudan android res klasörlerine yaz.
        import os
        base = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..", "android", "app", "src", "main", "res",
        )
        sizes = {
            "mipmap-mdpi": 48,
            "mipmap-hdpi": 72,
            "mipmap-xhdpi": 96,
            "mipmap-xxhdpi": 144,
            "mipmap-xxxhdpi": 192,
        }
        for folder, px in sizes.items():
            path = os.path.join(base, folder, "ic_launcher.png")
            master.resize((px, px), Image.LANCZOS).save(path)
            print(f"yazıldı: {path} ({px}px)")


if __name__ == "__main__":
    main()
