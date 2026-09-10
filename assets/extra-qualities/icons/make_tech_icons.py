"""Turn the four 512 die renders into what the mod ships.

    py make_tech_icons.py <raw_dir> [<mod_dir>]

    <mod>/graphics/technology/mythic-quality.png      480x256 = 256 + 128 + 64 + 32
    <mod>/graphics/technology/celestial-quality.png   480x256
    <mod>/thumbnail.png                               144x144

Three things measured off vanilla rather than chosen:

* **Technology icons carry a drop shadow; item icons do not.** Vanilla's soft fringe under
  the die sits at mean alpha 120, RGB (23,21,20).
* **Every resize goes through `imaging`, never `Image.resize`.** Blender writes straight
  alpha, so a naive resample averages colour across the alpha edge and lays a dark rind
  round the icon.
* **The paint-over is not optional.** Wube hand-work contrast and edges over every render;
  the raw dies measure luminance sd 47 against vanilla's 52-56.
"""

import os
import sys

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))


def _skill_scripts(start=None):
    d = os.path.abspath(start or HERE)
    while True:
        c = os.path.join(d, ".claude", "skills", "factorio-graphics", "scripts")
        if os.path.isdir(c):
            return c
        parent = os.path.dirname(d)
        if parent == d:
            raise RuntimeError("factorio-graphics scripts not found")
        d = parent


sys.path.insert(0, _skill_scripts())
from factorio_render import imaging, post                     # noqa: E402

# All four, vanilla's epic and legendary included - the mod overrides those two so the
# whole quality line is one die rather than two mods' worth.
TECH = ["epic-quality", "legendary-quality", "mythic-quality", "celestial-quality"]


def trimmed(raw, margin=4):
    """Crop to the subject and square it up. Vanilla icons run edge to edge."""
    im = raw.crop(imaging.bbox_above(raw, 8))
    side = max(im.width, im.height) + margin * 2
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return out


def drop_shadow(im, offset=(11, 13), blur=7, cap=150):
    a = im.getchannel("A").point(lambda v: min(cap, v))
    shadow = Image.new("RGBA", im.size, (18, 17, 15, 0))
    shadow.putalpha(a)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas = Image.new("RGBA", im.size, (0, 0, 0, 0))
    canvas.alpha_composite(shadow, offset)
    canvas.alpha_composite(im)
    return canvas


def main():
    raw_dir = sys.argv[1]
    mod = sys.argv[2] if len(sys.argv) > 2 else os.path.normpath(
        os.path.join(HERE, "..", "..", "..", "extra-qualities"))
    tech_dir = os.path.join(mod, "graphics", "technology")
    os.makedirs(tech_dir, exist_ok=True)

    subjects = {}
    for tech in TECH:
        raw = Image.open(os.path.join(raw_dir, "%s-raw.png" % tech)).convert("RGBA")
        # The stock icon preset overshoots on a subject this smooth: it took the dies
        # to luminance sd 67 where vanilla's measure 52-56 and gates.contrast caps at 56.
        subject = post.paint_over(trimmed(raw), preset="icon",
                                  form_amount=0.26, contrast_amount=0.20,
                                  crevice_amount=0.22, saturation=1.05)
        subjects[tech] = subject

        # Inset first, so the shadow has somewhere to fall inside the 256 box.
        big = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        big.alpha_composite(imaging.resize(subject, (224, 224)), (12, 8))
        out = os.path.join(tech_dir, "%s.png" % tech)
        imaging.mipmap_strip(drop_shadow(big), 256, levels=4).save(out)
        print("[tech]", out, "480x256")

    # thumbnail.png: the cracked die in front, the mythic one behind it, so the portal
    # tile says "two new tiers" rather than "a die".
    thumb = Image.new("RGBA", (144, 144), (0, 0, 0, 0))
    thumb.alpha_composite(imaging.resize(subjects["mythic-quality"], (86, 86)), (2, 6))
    thumb.alpha_composite(imaging.resize(subjects["celestial-quality"], (116, 116)), (26, 24))
    thumb_path = os.path.join(mod, "thumbnail.png")
    thumb.save(thumb_path)
    print("[thumb]", thumb_path, "144x144")


main()
