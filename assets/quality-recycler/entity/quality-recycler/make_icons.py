"""Turn the 512 icon render into the two mipmap strips the mod ships.

    py -3.14 make_icons.py <raw_dir> <mod_graphics_dir>

    icons/quality-recycler.png        120x64   = 64 + 32 + 16 + 8
    technology/quality-recycling.png  480x256  = 256 + 128 + 64 + 32

Two things that are not obvious and are both measured off vanilla:

* **Technology icons carry a drop shadow; item icons do not.** A tech icon
  without one reads as a sticker next to the rest of the tech tree.
* **Every resize goes through `imaging`, never `Image.resize`.** Blender writes
  straight alpha, so a naive resample averages colour across the alpha edge
  unweighted and lays a dark rind round the icon -- measured at 27-38% of
  surviving pixels more than 8/255 wrong on a 4x reduction.
"""
import os
import sys

from PIL import Image, ImageFilter


def _skill_scripts(start=None):
    d = os.path.abspath(start or globals().get("__file__") or os.getcwd())
    if os.path.isfile(d):
        d = os.path.dirname(d)
    while True:
        c = os.path.join(d, ".claude", "skills", "factorio-graphics", "scripts")
        if os.path.isdir(c):
            return c
        parent = os.path.dirname(d)
        if parent == d:
            raise RuntimeError("factorio-graphics scripts not found")
        d = parent


sys.path.insert(0, _skill_scripts())
from factorio_render import imaging, post                    # noqa: E402


def trimmed(raw, margin=6):
    """Crop to the subject and centre it. Vanilla icons run edge to edge --
    margins read as a sticker."""
    bb = imaging.bbox_above(raw, 8)
    im = raw.crop(bb)
    side = max(im.width, im.height) + margin * 2
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return out


def drop_shadow(im, offset=(11, 13), blur=7, cap=150):
    """Under the subject, from its own alpha. Technology icons only."""
    a = im.getchannel("A").point(lambda v: min(cap, v))
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    shadow.putalpha(a)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas = Image.new("RGBA", im.size, (0, 0, 0, 0))
    canvas.alpha_composite(shadow, offset)
    canvas.alpha_composite(im)
    return canvas


def main():
    raw_dir, graphics = sys.argv[1], sys.argv[2]
    raw = Image.open(os.path.join(raw_dir, "icon-raw.png")).convert("RGBA")
    # The paint-over vanilla gives every sprite, here too: the raw icon
    # measured luminance mean 49 / sd 29 / saturation 0.31 at 64 px where the
    # vanilla recycler, EM plant and foundry icons measure 79-100 / 57-64 /
    # 0.41-0.60. Lit harder in the rig and sharpened here, not one or the
    # other -- a hotter key alone flattens the crevices the icon reads by.
    subject = post.paint_over(trimmed(raw), preset="entity", saturation=1.3,
                              value=1.06, form_amount=0.30, contrast_amount=0.9,
                              crevice_amount=0.4)

    icons = os.path.join(graphics, "icons")
    tech = os.path.join(graphics, "technology")
    os.makedirs(icons, exist_ok=True)
    os.makedirs(tech, exist_ok=True)

    item = imaging.resize(subject, (64, 64))
    imaging.mipmap_strip(item, 64, levels=4).save(
        os.path.join(icons, "quality-recycler.png"))

    # inset first, so the shadow has somewhere to fall inside the 256 box
    big = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    inner = imaging.resize(subject, (222, 222))
    big.alpha_composite(inner, (12, 8))
    imaging.mipmap_strip(drop_shadow(big), 256, levels=4).save(
        os.path.join(tech, "quality-recycling.png"))

    print("[icons] %s (120x64) and %s (480x256)"
          % (os.path.join(icons, "quality-recycler.png"),
             os.path.join(tech, "quality-recycling.png")))


main()
