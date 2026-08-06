# Assembles the rendered wreck into the Factorio corpse sheet and prints the
# Lua numbers.
#
#   python make_remnant.py <frames_dir> <mod_graphics_dir>
#
# Unlike the entity, a remnant ships as ONE flat RGBA per variation: no vanilla
# remnant uses draw_as_shadow (checked across base and Space Age), so the ground
# shadow is composited into the colour sprite as soft grey. The ash halo is
# generated here rather than rendered -- vanilla's is a painted fringe, and a
# dilate-and-speckle of the wreck's own alpha matches it far more controllably
# than trying to render dust. It is DARK, not pale: see ASH_RGB.
#
# Both variations share one crop box, because the prototype declares one
# width/height/shift for the sheet and picks a variation with a `y` offset.
import os
import random
import sys

from PIL import Image, ImageChops, ImageFilter

CANVAS = (576, 576)
SHADOW_ALPHA = 0.42       # vanilla remnant shadows are soft mid-grey, not black
SHADOW_RGB = (26, 24, 22)
SHADOW_CUT = 100          # below this the catcher is ambient haze, not shadow
# Measured off the semi-transparent band (alpha 6..170) of the vanilla
# remnants: cryogenic plant (20,16,11), nuclear reactor (3,3,2), beacon
# (14,12,10). The soft fringe around a vanilla wreck is SCORCH AND SHADOW,
# near-black. It looks like pale dust only because a PNG viewed on a white
# background shows a dark soft edge as grey haze -- and building to that
# misreading produced a light halo that glowed around the whole silhouette
# once it was on the game's dark ground.
ASH_RGB = (21, 18, 14)
ASH_SPREAD = 7            # px the scorch reaches past the wreckage
ASH_FLOOR = 8             # alpha below this is invisible but still grows the crop
ASH_ALPHA = 0.50


def soft_shadow(img):
    # Threshold BEFORE softening. The Cycles catcher returns a faint
    # ambient-occlusion wash across the entire ground plane; left in, it
    # tints the whole tile grey and -- because it is non-zero everywhere --
    # drags the sprite crop out to the full canvas.
    a = img.getchannel("A").point(lambda v: 255 if v >= SHADOW_CUT else 0)
    a = a.filter(ImageFilter.GaussianBlur(2.0))
    a = a.point(lambda v: int(v * SHADOW_ALPHA))
    out = Image.new("RGBA", img.size, SHADOW_RGB + (0,))
    out.putalpha(a)
    return out


def scorch_fringe(img, seed):
    # Scorch and blown grit past the wreck: dilate the silhouette, drop the
    # silhouette itself back out so only the fringe remains, then break the
    # fringe up with speckle so its edge is grainy instead of a clean offset.
    rnd = random.Random(seed)
    core = img.getchannel("A").point(lambda v: 255 if v >= 24 else 0)
    spread = core.filter(ImageFilter.MaxFilter(ASH_SPREAD))
    spread = spread.filter(ImageFilter.GaussianBlur(3.0))
    fringe = ImageChops.subtract(spread, core)

    noise = Image.effect_noise(img.size, 48).point(lambda v: 255 if v > 118 else 90)
    noise = noise.filter(ImageFilter.GaussianBlur(0.6))
    a = ImageChops.multiply(fringe, noise).point(lambda v: int(v * ASH_ALPHA))

    # a scatter of individual grains further out, so the edge does not stop dead
    grains = Image.new("L", img.size, 0)
    px = grains.load()
    sp = spread.load()
    for _ in range(2600):
        x, y = rnd.randrange(img.size[0]), rnd.randrange(img.size[1])
        if sp[x, y] > 40 and core.getpixel((x, y)) == 0:
            px[x, y] = rnd.randrange(70, 190)
    grains = grains.filter(ImageFilter.GaussianBlur(1.2))
    a = ImageChops.lighter(a, grains)

    # Alpha this faint is invisible in game but still counts toward the crop
    # box, which is how a 410 px wreck turned into a 500 px sprite.
    a = a.point(lambda v: 0 if v < ASH_FLOOR else v)
    out = Image.new("RGBA", img.size, ASH_RGB + (0,))
    out.putalpha(a)
    return out


def compose(wreck_path, shadow_path, seed):
    wreck = Image.open(wreck_path).convert("RGBA")
    shadow = Image.open(shadow_path).convert("RGBA")
    out = Image.new("RGBA", wreck.size, (0, 0, 0, 0))
    out = Image.alpha_composite(out, scorch_fringe(wreck, seed))
    out = Image.alpha_composite(out, soft_shadow(shadow))
    out = Image.alpha_composite(out, wreck)
    # anything fainter than this is invisible in game and only inflates the crop
    out.putalpha(out.getchannel("A").point(lambda v: 0 if v < 4 else v))
    return out


def main():
    frames_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    variations = sorted(d for d in os.listdir(frames_dir) if d.startswith("v"))
    imgs = [compose(os.path.join(frames_dir, v, "wreck", "f0000.png"),
                    os.path.join(frames_dir, v, "shadow", "f0000.png"), i)
            for i, v in enumerate(variations)]

    bb = None
    for im in imgs:
        b = im.getbbox()
        bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]),
                                   max(bb[2], b[2]), max(bb[3], b[3]))
    x0, y0 = max(bb[0] - 2, 0), max(bb[1] - 2, 0)
    x1, y1 = min(bb[2] + 2, CANVAS[0]), min(bb[3] + 2, CANVAS[1])
    if (x1 - x0) % 2:
        x1 += 1
    if (y1 - y0) % 2:
        y1 += 1
    box = (x0, y0, x1, y1)
    w, h = x1 - x0, y1 - y0

    sheet = Image.new("RGBA", (w, h * len(imgs)))
    for i, im in enumerate(imgs):
        sheet.paste(im.crop(box), (0, i * h))
    sheet.save(os.path.join(out_dir, "pure-beacon-remnants.png"))

    # util.by_pixel takes display px (= source px / 2 at scale 0.5); the camera
    # targets the entity centre, which sits at the canvas centre
    cx = ((box[0] + box[2]) / 2 - CANVAS[0] / 2) / 2
    cy = ((box[1] + box[3]) / 2 - CANVAS[1] / 2) / 2
    report = ("remnants: width=%d height=%d shift=util.by_pixel(%.1f, %.1f) "
              "variations=%d sheet=%dx%d" % (w, h, cx, cy, len(imgs),
                                             sheet.width, sheet.height))
    print(report)
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "remnant_numbers.txt"), "w") as fh:
        fh.write(report + "\n")


main()
