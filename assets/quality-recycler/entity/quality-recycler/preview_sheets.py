"""Composite the packed sheets the way the ENGINE will, and look at it.

    py -3.14 preview_sheets.py <mod_graphics_dir> <out.png> [frame]

Shadow, then body, then the animation cell, then the light cell added rather
than alpha-composited -- `draw_as_glow` with `blend_mode = "additive"` is not
a normal layer, and a preview that alpha-composites it will show a glow the
game never draws. Each panel carries the 3x3 footprint in white, because the
number that matters is how far the sprite draws past its own tiles.

This is not a substitute for photographing it in the engine: module tint,
render-layer order and shadow blending only resolve there. It is the cheap
check that comes first.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
DIRS = ("N", "E", "S", "W", "flipped-N", "flipped-E", "flipped-S", "flipped-W")
PANEL = 560
PX_PER_TILE = 64
GROUND = (150, 96, 45, 255)          # Nauvis dirt; never judge a sprite on grey


def numbers():
    out = {}
    for raw in open(os.path.join(HERE, "sheet_numbers.txt")):
        if ":" not in raw:
            continue
        key, rest = raw.split(":", 1)
        shift = rest.split("shift=util.by_pixel(")[1].split(")")[0]
        d = dict(shift=tuple(float(v) for v in shift.split(",")))
        for tok in rest.split():
            if "=" in tok and not tok.startswith("shift"):
                k, v = tok.split("=", 1)
                if k in ("width", "height", "frames", "line_length"):
                    d[k] = int(v)
        out[key.strip()] = d
    return out


def cell(sheet, w, h, i, cols=8):
    r, c = divmod(i, cols)
    return sheet.crop((c * w, r * h, (c + 1) * w, (r + 1) * h))


def main():
    graphics, out_path = sys.argv[1], sys.argv[2]
    frame = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    N = numbers()
    panels = []
    for d in DIRS:
        base_path = os.path.join(graphics, "quality-recycler-%s.png" % d)
        if not os.path.exists(base_path):
            continue
        canvas = Image.new("RGBA", (PANEL, PANEL), GROUND)

        def place(img, shift):
            # shift is DISPLAY px (util.by_pixel at scale 0.5) -> source px
            x = int(PANEL / 2 + shift[0] * 2 - img.width / 2)
            y = int(PANEL / 2 + shift[1] * 2 - img.height / 2)
            canvas.alpha_composite(img, (x, y))

        for suffix, key in (("-shadow", "shadow"), ("", "base")):
            p = os.path.join(graphics, "quality-recycler-%s%s.png" % (d, suffix))
            if os.path.exists(p):
                place(Image.open(p).convert("RGBA"), N["%s %s" % (d, key)]["shift"])
        p = os.path.join(graphics, "quality-recycler-%s-anim.png" % d)
        if os.path.exists(p):
            m = N["%s anim" % d]
            place(cell(Image.open(p).convert("RGBA"), m["width"], m["height"],
                       frame % m["frames"]), m["shift"])
        p = os.path.join(graphics, "quality-recycler-%s-light.png" % d)
        if os.path.exists(p):
            m = N["%s light" % d]
            g = cell(Image.open(p).convert("RGBA"), m["width"], m["height"],
                     frame % m["frames"])
            g = g.resize((g.width * 2, g.height * 2), Image.LANCZOS)
            gx = int(PANEL / 2 + m["shift"][0] * 2 - g.width / 2)
            gy = int(PANEL / 2 + m["shift"][1] * 2 - g.height / 2)
            reg = canvas.crop((gx, gy, gx + g.width, gy + g.height))
            canvas.paste(ImageChops.add(reg.convert("RGB"),
                                        g.convert("RGB")).convert("RGBA"),
                         (gx, gy))

        half = int(1.5 * PX_PER_TILE)
        ImageDraw.Draw(canvas).rectangle(
            [(PANEL // 2 - half, PANEL // 2 - half),
             (PANEL // 2 + half, PANEL // 2 + half)], outline=(255, 255, 255, 150))
        ImageDraw.Draw(canvas).text((8, 8), d, fill=(255, 255, 255, 220))
        panels.append(canvas)

    cols = 4
    rows = (len(panels) + cols - 1) // cols
    sheet = Image.new("RGBA", (PANEL * cols, PANEL * rows), (24, 24, 26, 255))
    for i, p in enumerate(panels):
        sheet.paste(p, ((i % cols) * PANEL, (i // cols) * PANEL))
    sheet.save(out_path)
    print("[preview] %d directions -> %s" % (len(panels), out_path))


main()
