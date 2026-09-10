"""Draw all seven quality glyphs, vanilla's five included.

Vanilla's quality icon is flat pips in a heavy black ring, counted by tier, anchored to the
bottom-left of a 64x64 canvas. Measured off quality-epic.png (2.1.17):

    fill radius        r = 11
    outer black radius R = 1.45 * r
    centre pitch       p = 2.45 * r  -- adjacent rings merge into one band
    fill colour            the prototype's `color` / 0.7 -- base's `normal` is literally
                           255 * 0.7, and every quality icon matches its colour at 1/0.7
    shading            none; the mid-tone pixels are antialiasing, nothing else

**This mod redraws vanilla's five as well as its own two**, because a tier that does not match
the six below it is what a player actually notices. Two things make the family hold together:

* **Every glyph fills the canvas.** Vanilla's four- and five-pip glyphs span 59x60 of the 64
  box; anything smaller reads as a different icon set. Six and seven cannot do that at r = 11
  -- six centres 27 apart do not fit in 64 px in any arrangement -- so those two drop to
  r = 8.6 and take the overlap vanilla's five-pip centre already uses.
* **Six and seven share one shape.** A hexagonal ring, with the seventh pip in the middle of
  it. Identical footprint, identical pip size, and the count still reads at a glance. Six as a
  die's two-columns-of-three was the first attempt and it was the thing that looked wrong in
  game: a tall narrow block in a row of square ones.

Run:  py make_quality_icons.py
"""

import math
import os

from PIL import Image, ImageDraw

SS = 8      # supersampling factor
SIZE = 64

# Vanilla's geometry, for the five grid arrangements.
R_FILL = 11.0
RING = 1.45          # outer black radius, as a multiple of the fill radius
PITCH = 2.45         # centre-to-centre, as a multiple of the fill radius

# Six and seven: as large as a hexagon fits, with vanilla's own overlap.
HEX_FILL = 8.6
HEX_PITCH = 2.25

OUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "..", "extra-qualities", "graphics", "icons",
)

# Icon fills. The prototype `color` is each of these times 0.7, which is how vanilla relates
# the two -- the five vanilla values below are Wube's own, read back off their icons.
FILLS = {
    # Normal is the one quality whose icon is NOT its colour over 0.7: base writes the
    # colour as 255 * 0.7 but draws the pip at 188, a light grey rather than white.
    "normal": (188, 188, 188),
    "uncommon": (62, 236, 87),
    "rare": (36, 149, 255),
    "epic": (196, 0, 255),
    "legendary": (255, 149, 0),
    "mythic": (255, 42, 58),
    "celestial": (0, 232, 255),
}

COUNTS = {
    "normal": 1, "uncommon": 2, "rare": 3, "epic": 4,
    "legendary": 5, "mythic": 6, "celestial": 7,
}


def grid(count):
    """Vanilla's arrangements for one to five pips, bottom-left anchored."""
    r = R_FILL
    outer, pitch = r * RING, r * PITCH
    x0, x1 = outer, outer + pitch
    y1 = SIZE - outer
    y0 = y1 - pitch
    corners = [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]
    base = {
        1: [(x0, y1)],
        2: [(x0, y0), (x0, y1)],
        3: [(x0, y0), (x0, y1), (x1, y1)],
        4: corners,
        5: corners,
    }[count]
    # The fifth pip sits on top of the other four, ring and all - draw it in the base layer
    # and its outline disappears under their fills, which turns vanilla's quincunx into a blob.
    top = [((x0 + x1) / 2, (y0 + y1) / 2)] if count == 5 else []
    return base, top, r, outer


def rosette(count):
    """Six on a hexagon, and seven with the middle filled."""
    r = HEX_FILL
    outer, d = r * RING, r * HEX_PITCH
    cx = SIZE / 2
    cy = SIZE - outer - d * math.sin(math.radians(60))
    pips = [
        (cx + d * math.cos(math.radians(a)), cy + d * math.sin(math.radians(a)))
        for a in range(0, 360, 60)
    ]
    # Same treatment as the five-pip quincunx: the middle one goes on top.
    return pips, ([(cx, cy)] if count == 7 else []), r, outer


def draw(name, path):
    count = COUNTS[name]
    base, top, r, outer = grid(count) if count <= 5 else rosette(count)
    fill = FILLS[name] + (255,)

    img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def circle(cx, cy, radius, colour):
        d.ellipse([(cx - radius) * SS, (cy - radius) * SS,
                   (cx + radius) * SS, (cy + radius) * SS], fill=colour)

    # Rings first, so neighbouring outlines merge into one band as vanilla's do.
    for layer in (base, top):
        for cx, cy in layer:
            circle(cx, cy, outer, (0, 0, 0, 255))
        for cx, cy in layer:
            circle(cx, cy, r, fill)

    img.resize((SIZE, SIZE), Image.LANCZOS).save(path)


def main():
    out = os.path.normpath(OUT_DIR)
    os.makedirs(out, exist_ok=True)
    for name in COUNTS:
        path = os.path.join(out, "quality-%s.png" % name)
        draw(name, path)
        print("wrote", path)


if __name__ == "__main__":
    main()
