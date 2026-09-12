"""Build quality-recycler/thumbnail.png from the machine's icon render.

144x144 is what doc-html/auxiliary/mod-structure.html asks for. The hero is the
same 512 render the item icon is cut from (render_icon.py -> icon-raw.png), given
the same paint-over make_icons.py applies, and set over a dark panel with the
title in Titillium Web Bold -- the game's own UI face -- the way the Pure
Modules thumbnail is built.

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
SRC = REPO / "assets/quality-recycler/entity/quality-recycler/renders/icon/icon-raw.png"
OUT = REPO / "quality-recycler" / "thumbnail.png"
MASTER = HERE / "thumbnail-512.png"
# REPO.parent is the dev install this repo sits in; no other install is consulted.
FONT = REPO.parent / "data/core/fonts/TitilliumWeb-Bold.ttf"


def _skill_scripts():
    d = str(REPO)
    c = os.path.join(d, ".claude", "skills", "factorio-graphics", "scripts")
    if not os.path.isdir(c):
        raise RuntimeError("factorio-graphics scripts not found under " + d)
    return c


sys.path.insert(0, _skill_scripts())
from factorio_render import imaging, post                    # noqa: E402

SIZE = 512
LINES = ("QUALITY", "RECYCLER")
TEXT_W = 0.76       # width of the longer line, as a fraction of the image
BASELINE = 0.945    # bottom of the last line, as a fraction of height
HERO_W = 0.74       # the machine's width, as a fraction of the image
HERO_CY = 0.37      # the machine's centre, as a fraction of height

# Panel greys from the game's own GUI, with a violet cast behind the machine:
# quality's colour, and the colour every lamp on this machine burns.
PANEL = (52, 50, 54)
EDGE = (16, 15, 18)
GLOW = (150, 70, 220)

# Brushed steel pulled towards lilac. Few stops on purpose: cap height at
# 144 px is about 15 px, and a long ramp averages to flat grey in the
# downsample. Lit top, dark bottom, one reflection kick.
METAL = [
    (0.00, (250, 246, 255)),
    (0.34, (198, 168, 228)),
    (0.66, (92, 58, 132)),
    (0.80, (214, 190, 240)),
    (1.00, (66, 40, 100)),
]
OUTLINE = (14, 8, 22)


def trimmed(raw, margin=6):
    bb = imaging.bbox_above(raw, 8)
    im = raw.crop(bb)
    side = max(im.width, im.height) + margin * 2
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return out


def subject():
    raw = Image.open(SRC).convert("RGBA")
    # the item icon's own paint-over, so the thumbnail and the icon match
    return post.paint_over(trimmed(raw), preset="entity", saturation=1.3,
                           value=1.06, form_amount=0.30, contrast_amount=0.9,
                           crevice_amount=0.4)


def radial(size, inner, outer, cx, cy, radius, power=1.0):
    """Two-colour radial gradient, built as a mask so it stays smooth."""
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
    # the panel: mid grey falling to near-black at the corners
    img = radial(size, PANEL, EDGE, size * 0.5, size * 0.42, size * 0.78, power=1.6).convert("RGBA")
    # a violet glow where the machine will sit, so it lifts off the panel
    glow = radial(size, GLOW, (0, 0, 0), size * 0.5, size * HERO_CY, size * 0.46, power=1.3)
    glow_a = glow.convert("L").point(lambda v: int(v * 0.42))
    glow = glow.convert("RGBA")
    glow.putalpha(glow_a)
    img = Image.alpha_composite(img, glow)

    # the machine, with a soft shadow from its own alpha
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

    # bottom scrim so the title reads over the machine's skirt
    scrim = Image.new("L", (1, size), 0)
    for yy in range(size):
        t = (yy / size - 0.62) / 0.38
        scrim.putpixel((0, yy), 0 if t < 0 else int(210 * t ** 1.7))
    scrim = scrim.resize((size, size))
    img = Image.composite(Image.new("RGBA", (size, size), (8, 6, 12, 255)), img, scrim)

    draw = ImageDraw.Draw(img)
    longest = max(LINES, key=lambda s: draw.textlength(s, font=ImageFont.truetype(str(FONT), 40)))
    font = fit_font(draw, longest, size * TEXT_W)
    heights = [draw.textbbox((0, 0), s, font=font)[3] - draw.textbbox((0, 0), s, font=font)[1]
               for s in LINES]
    gap = size * 0.030
    total = sum(heights) + gap * (len(LINES) - 1)

    # glow behind the text, twice, so it survives the pale rotor cap
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
    print(f"{MASTER}  master")
    if "--preview" in sys.argv:
        p = HERE / "preview-4x.png"
        thumb.resize((576, 576), Image.NEAREST).save(p)
        print(f"{p}  preview")


if __name__ == "__main__":
    main()
