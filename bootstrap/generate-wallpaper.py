#!/usr/bin/env python3
"""Generate the original MIT-licensed fallback wallpaper; no third-party images."""
from pathlib import Path
import math
import struct
import zlib

WIDTH, HEIGHT = 1280, 800


def chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))


def render():
    rows = bytearray()
    for y in range(HEIGHT):
        rows.append(0)  # PNG filter: none
        for x in range(WIDTH):
            blue = math.exp(-((x / WIDTH - .82) ** 2 + (y / HEIGHT - .2) ** 2) * 5)
            purple = math.exp(-((x / WIDTH - .15) ** 2 + (y / HEIGHT - .95) ** 2) * 7)
            rows.extend((int(22 + blue * 16 + purple * 20), int(24 + blue * 28 + purple * 8), int(35 + blue * 48 + purple * 30)))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', WIDTH, HEIGHT, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b'')


if __name__ == '__main__':
    target = Path(__file__).resolve().parent.parent / 'dot_local/share/desktop-assets/wallpaper.png'
    target.write_bytes(render())
    print(target)
