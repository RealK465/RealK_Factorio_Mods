"""Build pure-modules-realk/thumbnail.png from the Aquilo beacon screenshot.

144x144 is what doc-html/auxiliary/mod-structure.html asks for. The source is a
portrait screenshot, so it is cropped square around the platform first; the text
sits on the bare stone floor below the machine, which is why the crop is offset
upward rather than centred on the platform.

    python make_thumbnail.py [--preview]

--preview also writes 4x PNGs beside the output so the small result can be
judged without squinting.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

REPO = Path(__file__).resolve().parents[3]
SRC = REPO / "pure-modules-realk" / "images" / "beacon-on-aquilo.jpg"
OUT = REPO / "pure-modules-realk" / "thumbnail.png"
MASTER = Path(__file__).resolve().parent / "thumbnail-512.png"

# Titillium Web is Factorio's own UI face — the game ships it in data/core/fonts.
FONT = Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\core\fonts\TitilliumWeb-Bold.ttf"
)

# Square crop on the source, measured off the platform (x 95-390, y 58-465).
# Pushed up so the machine sits high and the bare stone floor carries the text.
CROP = (22, 30, 462, 470)

# Brushed-steel ramp, pulled cool to echo the beacon's crystal. Applied down each
# line separately, so both read as metal rather than one line getting the
# highlight and the other the shadow. Stops are (position, RGB).
#
# Deliberately few stops: cap height at 144px is ~15px, so a full 7-stop chrome
# ramp averages back to flat pale blue in the downsample. Lit-top to dark-bottom
# plus a single reflection kick is all that survives.
METAL = [
    (0.00, (244, 250, 255)),
    (0.34, (146, 186, 220)),
    (0.66, (56,  92, 132)),
    (0.80, (186, 216, 240)),  # one reflection kick — the only band small enough to keep
    (1.00, (48,  80, 116)),
]
OUTLINE = (10, 20, 32)

SIZE = 512          # master is built here, then downsampled to 144
LINES = ("PURE", "MODULES")
# One size for both lines, fitted to the LONGER one. Fitting each line to the
# same width instead blows "PURE" up to four huge letters and buries the beacon.
TEXT_W = 0.74       # width of the longest line, as a fraction of the image
BASELINE = 0.935    # bottom of the last line, as a fraction of height


def metal_strip(w, h):
    """Vertical brushed-steel gradient, one line tall."""
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
    """Largest font size whose rendered width fits target_px."""
    size = 8
    while size < 400:
        f = ImageFont.truetype(str(FONT), size + 1)
        if draw.textlength(text, font=f) > target_px:
            break
        size += 1
    return ImageFont.truetype(str(FONT), size)


def build(size):
    img = Image.open(SRC).convert("RGB").crop(CROP).resize((size, size), Image.LANCZOS)

    # Bottom-up scrim so the text reads over both stone and snow. Built as a
    # mask and composited, rather than drawn, so the falloff stays smooth.
    scrim = Image.new("L", (1, size), 0)
    for y in range(size):
        t = (y / size - 0.58) / 0.42
        scrim.putpixel((0, y), 0 if t < 0 else int(195 * t**1.8))
    scrim = scrim.resize((size, size))
    img = Image.composite(Image.new("RGB", (size, size), (8, 12, 20)), img, scrim)

    img = img.convert("RGBA")
    draw = ImageDraw.Draw(img)

    longest = max(LINES, key=lambda s: len(s))
    font = fit_font(draw, longest, size * TEXT_W)
    fonts = [font] * len(LINES)
    heights = [draw.textbbox((0, 0), s, font=f)[3] - draw.textbbox((0, 0), s, font=f)[1]
               for s, f in zip(LINES, fonts)]
    gap = size * 0.030
    total = sum(heights) + gap * (len(LINES) - 1)
    y = size * BASELINE - total

    # Glow behind the text, so it survives the pale snow at the frame edges.
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for s, f, h in zip(LINES, fonts, heights):
        top = y - draw.textbbox((0, 0), s, font=f)[1]
        gd.text((size / 2, top), s, font=f, fill=(0, 0, 0, 235), anchor="ma")
        y += h + gap
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.012))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, glow)

    # Dark outline first, then the steel gradient poured through the glyph mask.
    # Pillow cannot fill text with a gradient directly, so the glyphs are rendered
    # into an L mask and used as the alpha for a gradient strip.
    stroke = max(1, round(size * 0.009))
    y = size * BASELINE - total
    for s, f, h in zip(LINES, fonts, heights):
        top = y - draw.textbbox((0, 0), s, font=f)[1]

        outline = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(outline).text((size / 2, top), s, font=f, anchor="ma",
                                     fill=OUTLINE + (255,),
                                     stroke_width=stroke, stroke_fill=OUTLINE + (255,))
        img = Image.alpha_composite(img, outline)

        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).text((size / 2, top), s, font=f, fill=255, anchor="ma")
        bbox = mask.getbbox()
        fill = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        fill.paste(metal_strip(size, bbox[3] - bbox[1]), (0, bbox[1]))
        fill.putalpha(mask)
        img = Image.alpha_composite(img, fill)

        y += h + gap

    return img.convert("RGB")


def main():
    master = build(SIZE)
    master.save(MASTER)
    thumb = master.resize((144, 144), Image.LANCZOS)
    thumb.save(OUT)
    print(f"{OUT}  {thumb.size[0]}x{thumb.size[1]}  {OUT.stat().st_size / 1024:.0f} KB")
    print(f"{MASTER}  master")

    if "--preview" in sys.argv:
        p = Path(__file__).resolve().parent / "preview-4x.png"
        thumb.resize((576, 576), Image.NEAREST).save(p)
        print(f"{p}  preview")


if __name__ == "__main__":
    main()
