# Crops the socket sprite renders into the module_visualisations set.
#
#   python make_slots.py <frames_dir> <mod_graphics_dir>
#
# Produces -mask-box / -mask-lights / -lights (the last is a blurred halo of
# the light strips, for draw_as_light). They share one crop box so they share
# one shift; the prototype offsets per slot by 32 display px per tile of
# socket spacing.
#
# There is deliberately no empty-slot sprite: the base sprite already draws
# the ports, and a second copy drawn on top covered part of the front lip.
#
# The two -mask- files are apply_module_tint layers, and a tint mask has two
# separate requirements that are easy to satisfy only one of:
#
#   luminance  the mask is MULTIPLIED by the tint, so a flat sprite can only
#              ever produce a flat patch of colour. It has to be a shaded
#              greyscale render spanning a real range -- vanilla's
#              beacon-module-mask-box spans 0-255 with a mean near 141.
#   alpha      FFF-218: "unless you are doing something extremely specific,
#              the colour mask values should always be at 0.5 Alpha... The
#              Alpha is black magic, keep it at 0.5 please", with the stated
#              condition that both the mask and the area under it are
#              desaturated -- which holds here. At full alpha the mask
#              REPLACES the pixel and the machine's own shading is lost
#              underneath a coloured decal; at 0.5 it modulates and the form
#              shows through. Measured on vanilla's own beacon masks:
#              mask-box median alpha 106 (max 253, nothing at 255), the more
#              emissive mask-lights median 182. Ours measured median 255 with
#              76% of pixels fully opaque before this scaling existed.
#
# beacon-module-lights.png is NOT a tint mask -- it is draw_as_light, which
# the engine composites into the light layer -- so it keeps its own alpha.
import os
import sys

from PIL import Image, ImageFilter


def _skill_scripts(start=None):
    """Find .claude/skills/factorio-graphics/scripts by walking up."""
    d = os.path.abspath(start or globals().get("__file__") or os.getcwd())
    if os.path.isfile(d):
        d = os.path.dirname(d)
    while True:
        c = os.path.join(d, ".claude", "skills", "factorio-graphics", "scripts")
        if os.path.isdir(c):
            return c
        parent = os.path.dirname(d)
        if parent == d:
            raise RuntimeError("factorio-graphics scripts not found above " + str(start))
        d = parent


HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _skill_scripts())

from factorio_render import imaging, post

CANVAS = (512, 640)

# alpha multipliers, chosen to land on the vanilla medians above
MASK_ALPHA = {"box": 0.50, "lights": 0.75}


def as_tint_mask(im, alpha_scale):
    """Shade it harder, then take the alpha down to tint-mask strength."""
    im = post.paint_over(im, "entity", saturation=1.0, alpha_gamma=1.0)
    a = im.getchannel("A").point(lambda v: int(v * alpha_scale))
    out = im.copy()
    out.putalpha(a)
    return out


def main():
    frames_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    imgs = {}
    for layer in ("slot-box", "slot-lights"):
        imgs[layer] = Image.open(os.path.join(frames_dir, layer, "f0000.png"))

    bb = None
    for im in imgs.values():
        b = imaging.bbox_above(im, 8)
        bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]),
                                   max(bb[2], b[2]), max(bb[3], b[3]))
    x0, y0, x1, y1 = bb[0] - 4, bb[1] - 4, bb[2] + 4, bb[3] + 4
    if (x1 - x0) % 2:
        x1 += 1
    if (y1 - y0) % 2:
        y1 += 1
    box = (x0, y0, x1, y1)

    mask_box = as_tint_mask(imgs["slot-box"].crop(box), MASK_ALPHA["box"])
    mask_box.save(os.path.join(out_dir, "beacon-module-mask-box.png"))

    strips = imgs["slot-lights"].crop(box)
    as_tint_mask(strips, MASK_ALPHA["lights"]).save(
        os.path.join(out_dir, "beacon-module-mask-lights.png"))

    # draw_as_light: full alpha, and no paint-over -- a light sprite is not a
    # surface, so crevice darkening on it means nothing
    halo = strips.filter(ImageFilter.GaussianBlur(3))
    halo.putalpha(halo.getchannel("A").point(lambda v: min(255, int(v * 1.4))))
    Image.alpha_composite(halo, strips).save(
        os.path.join(out_dir, "beacon-module-lights.png"))

    for name in ("beacon-module-mask-box", "beacon-module-mask-lights"):
        print("  %s: %s" % (name, imaging.stats(
            Image.open(os.path.join(out_dir, name + ".png")))))

    cx = (x0 + x1) / 2 - CANVAS[0] / 2
    cy = (y0 + y1) / 2 - CANVAS[1] / 2
    report = ("slots: width=%d height=%d ref_shift=util.by_pixel(%.1f, %.1f)"
              % (x1 - x0, y1 - y0, cx / 2, cy / 2))
    print(report)
    with open(os.path.join(HERE, "slot_numbers.txt"), "w") as fh:
        fh.write(report + "\n")


main()
