#!/usr/bin/env python3
"""Basit bir uygulama simgesi üretir: koyu zemin, mavi daire, beyaz oynat üçgeni."""
import struct, zlib, sys

SIZE = 256

def px(x, y):
    # Koyu zemin
    r, g, b = 14, 17, 22
    cx, cy = SIZE / 2, SIZE / 2
    dx, dy = x - cx, y - cy
    dist = (dx * dx + dy * dy) ** 0.5
    # Mavi daire
    if dist <= 92:
        r, g, b = 21, 101, 192
    # Oynat üçgeni
    if dist <= 92:
        # Üçgen: tepe (cx-28, cy-40), (cx-28, cy+40), (cx+46, cy)
        tx = x - (cx - 28)
        ty = y - cy
        # yarı yükseklikte (x konumuna göre) üçgen içinde mi?
        if ty >= -40 and ty <= 40:
            edge = 40 - (ty * 40 / 40)  # 40..0
            half = edge * (86 / 80)     # taban 86 px (46+28+12)
            if tx >= 0 and tx <= 86 and abs(ty) <= (edge - 12):
                r, g, b = 255, 255, 255
    return r, g, b

def build():
    rows = []
    for y in range(SIZE):
        row = bytearray([0])
        for x in range(SIZE):
            r, g, b = px(x, y)
            row += bytes([r, g, b])
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    return png

if __name__ == "__main__":
    with open(sys.argv[1], "wb") as f:
        f.write(build())
    print("yazıldı:", sys.argv[1])
