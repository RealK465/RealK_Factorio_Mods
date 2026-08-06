# Generates the stencil decal atlas used by the beacon's panel materials.
#
#   python make_stencils.py
#
# 4x4 grid of white-on-transparent marks, 128 px per cell. Decals are a
# texture layer, not geometry: at 64 px/tile a stencil is ~10 px tall, so what
# matters is that writing is *there*, not that it is legible. Committed
# alongside the generator so a render never depends on regenerating it.
import os

from PIL import Image, ImageDraw, ImageFont

CELL = 128
GRID = 4
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "textures", "stencils.png")

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\consolab.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]


def font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)   # Pillow >= 10.1


def text(d, box, s, size, w=255):
    f = font(size)
    x0, y0, x1, y1 = box
    tb = d.textbbox((0, 0), s, font=f)
    d.text((x0 + (x1 - x0 - tb[2]) / 2, y0 + (y1 - y0 - tb[3]) / 2), s,
           font=f, fill=(255, 255, 255, w))


def hazard_triangle(d, cx, cy, r):
    pts = [(cx, cy - r), (cx - r * 0.92, cy + r * 0.72), (cx + r * 0.92, cy + r * 0.72)]
    d.polygon(pts, outline=(255, 255, 255, 255), width=7)
    d.rectangle((cx - 5, cy - r * 0.28, cx + 5, cy + r * 0.28), fill=(255, 255, 255, 255))
    d.ellipse((cx - 6, cy + r * 0.40, cx + 6, cy + r * 0.52), fill=(255, 255, 255, 255))


def chevrons(d, box, n=3):
    x0, y0, x1, y1 = box
    step = (x1 - x0) / (n + 1)
    for i in range(n):
        x = x0 + step * (i + 0.5)
        d.line([(x, y0), (x + step * 0.7, (y0 + y1) / 2), (x, y1)],
               fill=(255, 255, 255, 235), width=9)


def snowflake(d, cx, cy, r):
    import math
    for k in range(6):
        a = math.radians(60 * k)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        d.line([(cx, cy), (x, y)], fill=(255, 255, 255, 255), width=7)
        for s in (-1, 1):
            b = a + s * math.radians(45)
            mx, my = cx + r * 0.62 * math.cos(a), cy + r * 0.62 * math.sin(a)
            d.line([(mx, my), (mx + r * 0.3 * math.cos(b), my + r * 0.3 * math.sin(b))],
                   fill=(255, 255, 255, 255), width=5)


def bolt(d, cx, cy, r):
    d.polygon([(cx + r * 0.25, cy - r), (cx - r * 0.45, cy + r * 0.1),
               (cx - r * 0.05, cy + r * 0.1), (cx - r * 0.3, cy + r),
               (cx + r * 0.5, cy - r * 0.15), (cx + r * 0.1, cy - r * 0.15)],
              fill=(255, 255, 255, 255))


def bars(d, box):
    x0, y0, x1, y1 = box
    widths = [6, 3, 9, 3, 4, 8, 3, 6, 4]
    x = x0
    for i, w in enumerate(widths):
        if i % 2 == 0:
            d.rectangle((x, y0, x + w, y1), fill=(255, 255, 255, 220))
        x += w + 5


def label_plate(d, box):
    x0, y0, x1, y1 = box
    d.rectangle((x0, y0, x1, y1), outline=(255, 255, 255, 210), width=5)
    for i in range(3):
        y = y0 + 18 + i * 20
        d.rectangle((x0 + 14, y, x1 - 14 - i * 18, y + 7), fill=(255, 255, 255, 170))


def main():
    img = Image.new("RGBA", (CELL * GRID, CELL * GRID), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)

    def cell(col, row):
        return (col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL)

    def inset(col, row, m=18):
        x0, y0, x1, y1 = cell(col, row)
        return (x0 + m, y0 + m, x1 - m, y1 - m)

    text(d, inset(0, 0), "PM-04", 34)
    hazard_triangle(d, *[(cell(1, 0)[0] + CELL / 2), (cell(1, 0)[1] + CELL / 2)], r=44)
    chevrons(d, inset(2, 0, 26))
    bolt(d, cell(3, 0)[0] + CELL / 2, cell(3, 0)[1] + CELL / 2, 40)

    text(d, inset(0, 1), "COOLANT", 21)
    text(d, inset(1, 1), "FK-1", 44)
    text(d, inset(2, 1), "04", 74)
    bars(d, inset(3, 1, 24))

    text(d, inset(0, 2), "HV", 62)
    snowflake(d, cell(1, 2)[0] + CELL / 2, cell(1, 2)[1] + CELL / 2, 44)
    text(d, inset(2, 2), "PURGE", 24)
    label_plate(d, inset(3, 2, 20))

    text(d, inset(0, 3), "CAUTION", 21)
    text(d, inset(1, 3), "Q-CORE", 23)
    text(d, inset(2, 3), "II", 66)
    chevrons(d, inset(3, 3, 26), n=2)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("wrote", OUT, img.size)


main()
