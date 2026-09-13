"""Turn the 512 icon render into the two mipmap strips the mod ships.

    py -3.14 make_icons.py <raw_dir> <mod_graphics_dir>

    icons/quality-assembler.png       120x64   = 64 + 32 + 16 + 8
    technology/quality-assembly.png   480x256  = 256 + 128 + 64 + 32

Two things measured off vanilla: technology icons carry a drop shadow and
item icons do not; and every resize goes through `imaging`, never
`Image.resize`, because Blender writes straight alpha and a naive resample
lays a dark rind round the icon.
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

ICON_POST = dict(preset="entity", saturation=1.25, value=1.06, form_amount=0.30,
                 contrast_amount=0.9, crevice_amount=0.4)


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
    cfg = dict(ICON_POST)
    subject = post.paint_over(trimmed(raw), cfg.pop("preset"), **cfg)

    icons = os.path.join(graphics, "icons")
    tech = os.path.join(graphics, "technology")
    os.makedirs(icons, exist_ok=True)
    os.makedirs(tech, exist_ok=True)

    item = imaging.resize(subject, (64, 64))
    imaging.mipmap_strip(item, 64, levels=4).save(os.path.join(icons, "quality-assembler.png"))

    big = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    inner = imaging.resize(subject, (222, 222))
    big.alpha_composite(inner, (12, 8))
    imaging.mipmap_strip(drop_shadow(big), 256, levels=4).save(
        os.path.join(tech, "quality-assembly.png"))
    print("[icons] %s (120x64) and %s (480x256)"
          % (os.path.join(icons, "quality-assembler.png"),
             os.path.join(tech, "quality-assembly.png")))


if __name__ == "__main__":
    main()
