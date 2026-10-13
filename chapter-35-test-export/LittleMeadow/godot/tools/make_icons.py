"""Makes packaging/icon.ico (Windows) and packaging/icon.icns (macOS) from packaging/icon_1024.png.

Run tools/render_icon.gd first (it draws icon.svg at 1024 pixels), then:
    python3 tools/make_icons.py
Needs Pillow.
"""
import os
import struct
from io import BytesIO

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "packaging")
SOURCE = os.path.join(OUT, "icon_1024.png")
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
ICNS_TYPES = [(b"ic07", 128), (b"ic08", 256), (b"ic09", 512), (b"ic10", 1024)]


def make_ico(image: Image.Image) -> None:
    image.save(os.path.join(OUT, "icon.ico"), format="ICO", sizes=ICO_SIZES)


def make_icns(image: Image.Image) -> None:
    chunks = b""
    for code, size in ICNS_TYPES:
        buffer = BytesIO()
        image.resize((size, size), Image.LANCZOS).save(buffer, format="PNG")
        data = buffer.getvalue()
        chunks += code + struct.pack(">I", len(data) + 8) + data
    with open(os.path.join(OUT, "icon.icns"), "wb") as handle:
        handle.write(b"icns" + struct.pack(">I", len(chunks) + 8) + chunks)


if __name__ == "__main__":
    picture = Image.open(SOURCE).convert("RGBA")
    make_ico(picture)
    make_icns(picture)
    print("wrote icon.ico and icon.icns")
