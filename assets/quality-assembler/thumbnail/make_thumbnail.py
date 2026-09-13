"""Build quality-assembler/thumbnail.png from the machine's icon render.

144x144 is what doc-html/auxiliary/mod-structure.html asks for. The hero is
the same 512 render the item icon is cut from (render_icon.py -> icon-raw.png),
given the same paint-over make_icons.py applies, and set over a dark panel with
the title in Titillium Web Bold -- the game's own UI face -- the way the Pure
Modules and Quality Recycler thumbnails are built. The cast behind the machine
is the cold cyan the machine burns; the sibling recycler's is violet.

    py -3.14 make_thumbnail.py [--preview]

--preview also writes a 4x nearest-neighbour blowup beside the master, because
what goes wrong in a thumbnail is only visible at final size.
"""

import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SRC = REPO / "assets/quality-assembler/entity/quality-assembler/renders/icon/icon-raw.png"
OUT = REPO / "quality-assembler" / "thumbnail.png"
MASTER = HERE / "thumbnail-512.png"
FONT = REPO.parent / "data/core/fonts/TitilliumWeb-Bold.ttf"


def _skill_scripts():
    d = str(REPO)
    c = os.path.join(d, ".claude", "skills", "factorio-graphics", "scripts")
    if not os.path.isdir(c):
        raise RuntimeError("factorio-graphics scripts not found under " + d)
    return c


sys.path.insert(0, _skill_scripts())
sys.path.insert(0, str(REPO / "assets/quality-assembler/entity/quality-assembler"))
from factorio_render import imaging, post                    # noqa: E402
from make_icons import ICON_POST                             # noqa: E402

SIZE = 512
LINES = ("QUALITY", "ASSEMBLER")
TEXT_W = 0.80
BASELINE = 0.945
HERO_W = 0.76
HERO_CY = 0.38

PANEL = (50, 52, 56)
EDGE = (15, 16, 19)
GLOW = (60, 190, 215)

# Brushed steel pulled towards ice: lit top, dark bottom, one reflection kick.
METAL = [
    (0.00, (246, 252, 255)),
    (0.34, (160, 214, 232)),
    (0.66, (40, 96, 122)),
    (0.80, (188, 234, 246)),
    (1.00, (30, 70, 92)),
]
OUTLINE = (8, 16, 22)


def trimmed(raw, margin=6):
    bb = imaging.bbox_above(raw, 8)
    im = raw.crop(bb)
    side = max(im.width, im.height) + margin * 2
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return out


def subject():
    raw = Image.open(SRC).convert("RGBA")
    cfg = dict(ICON_POST)
    return post.paint_over(trimmed(raw), cfg.pop("preset"), **cfg)


def radial(size, inner, outer, cx, cy, radius, power=1.0):
    mask = Image.new("L", (size, size), 0)
    px = mask.load()
    for y in range(size):
        for x in range(size):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / radius
            t = min(1.0, d) ** power
            px[x, y] = int(255 * (1.0 - t))
    return Image.composite(Image.new("RGB", (size, size), inner),
                           Image.new("RGB", (size, size), outer), mask)


def metal_strip(w, h):
    strip = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        for i in range(len(METAL) - 1):
            p0, c0 = METAL[i]
            p1, c1 = METAL[i + 1]
            if p0 <= t <= p1:
                k = (t - p0) / (p1 - p0)
                strip.putpixel((0, y), tuple(int(a + (b - a) * k) for a, b in zip(c0, c1)))
                break
    return strip.resize((w, h))


def fit_font(draw, text, target_px):
    size = 8
    while size < 400:
        f = ImageFont.truetype(str(FONT), size + 1)
        if draw.textlength(text, font=f) > target_px:
            break
        size += 1
    return ImageFont.truetype(str(FONT), size)


def build(size):
    img = radial(size, PANEL, EDGE, size * 0.5, size * 0.42, size * 0.78, power=1.6).convert("RGBA")
    glow = radial(size, GLOW, (0, 0, 0), size * 0.5, size * HERO_CY, size * 0.46, power=1.3)
    glow_a = glow.convert("L").point(lambda v: int(v * 0.40))
    glow = glow.convert("RGBA")
    glow.putalpha(glow_a)
    img = Image.alpha_composite(img, glow)

    hero = subject()
    w = int(size * HERO_W)
    hero = imaging.resize(hero, (w, int(hero.height * w / hero.width)))
    x = (size - hero.width) // 2
    y = int(size * HERO_CY - hero.height / 2)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sa = hero.getchannel("A").point(lambda v: min(170, v))
    sh = Image.new("RGBA", hero.size, (0, 0, 0, 0))
    sh.putalpha(sa)
    shadow.alpha_composite(sh, (x + int(size * 0.02), y + int(size * 0.03)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.014))
    img = Image.alpha_composite(img, shadow)
    img.alpha_composite(hero, (x, y))

    scrim = Image.new("L", (1, size), 0)
    for yy in range(size):
        t = (yy / size - 0.62) / 0.38
        scrim.putpixel((0, yy), 0 if t < 0 else int(210 * t ** 1.7))
    scrim = scrim.resize((size, size))
    img = Image.composite(Image.new("RGBA", (size, size), (6, 9, 12, 255)), img, scrim)

    draw = ImageDraw.Draw(img)
    longest = max(LINES, key=lambda s: draw.textlength(s, font=ImageFont.truetype(str(FONT), 40)))
    font = fit_font(draw, longest, size * TEXT_W)
    heights = [draw.textbbox((0, 0), s, font=font)[3] - draw.textbbox((0, 0), s, font=font)[1]
               for s in LINES]
    gap = size * 0.030
    total = sum(heights) + gap * (len(LINES) - 1)

    yy = size * BASELINE - total
    tglow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(tglow)
    for s, h in zip(LINES, heights):
        top = yy - draw.textbbox((0, 0), s, font=font)[1]
        gd.text((size / 2, top), s, font=font, fill=(0, 0, 0, 235), anchor="ma")
        yy += h + gap
    tglow = tglow.filter(ImageFilter.GaussianBlur(size * 0.012))
    img = Image.alpha_composite(img, tglow)
    img = Image.alpha_composite(img, tglow)

    stroke = max(1, round(size * 0.009))
    yy = size * BASELINE - total
    for s, h in zip(LINES, heights):
        top = yy - draw.textbbox((0, 0), s, font=font)[1]
        outline = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(outline).text((size / 2, top), s, font=font, anchor="ma",
                                     fill=OUTLINE + (255,),
                                     stroke_width=stroke, stroke_fill=OUTLINE + (255,))
        img = Image.alpha_composite(img, outline)
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).text((size / 2, top), s, font=font, fill=255, anchor="ma")
        bbox = mask.getbbox()
        fill = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        fill.paste(metal_strip(size, bbox[3] - bbox[1]), (0, bbox[1]))
        fill.putalpha(mask)
        img = Image.alpha_composite(img, fill)
        yy += h + gap

    return img.convert("RGB")


def main():
    master = build(SIZE)
    master.save(MASTER)
    thumb = master.resize((144, 144), Image.LANCZOS)
    thumb.save(OUT)
    print(f"{OUT}  {thumb.size[0]}x{thumb.size[1]}  {OUT.stat().st_size / 1024:.0f} KB")
    if "--preview" in sys.argv:
        prev = HERE / "preview-4x.png"
        thumb.resize((576, 576), Image.NEAREST).save(prev)
        print(prev)


if __name__ == "__main__":
    main()
