"""Generate our original MIT-licensed iWeather gradient (stdlib only)."""
from pathlib import Path
import struct
import zlib


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


width, height = 512, 12
start, end = (122, 162, 247), (247, 118, 142)
row = bytes([0]) + bytes(round(a + (b - a) * x / (width - 1))
                          for x in range(width) for a, b in zip(start, end))
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(row * height)) + chunk(b'IEND', b'')
(Path(__file__).resolve().parent.parent / 'dot_local/share/noctalia-local-plugins/iweather/gradient.png').write_bytes(png)
