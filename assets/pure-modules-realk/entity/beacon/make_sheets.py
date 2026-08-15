# Assembles rendered frames into Factorio sheets and prints the Lua numbers.
#
#   python make_sheets.py <frames_dir> <mod_graphics_dir> [--no-post]
#
# Every layer is cropped independently and carries its own shift, so editing
# one of them re-renders and re-packs only that one -- the anim sheet is 64
# Cycles frames of the rings and there is no reason to redo it for an arc
# change. Layers with no frames in <frames_dir> are left alone on disk and
# their numbers carry over from sheet_numbers.txt.
#
# Between the render and the sheet sits the paint-over pass -- the step Wube
# do in Photoshop and never skip (FFF-146: duplicate the render, Multiply and
# Screen with masks, "to enforce contrast, make edges clearer, define shape of
# entities better"). It runs PER FRAME, before packing: every filter in it has
# a radius, and over an assembled sheet it would bleed each frame into its
# neighbour. Calibrated against vanilla -- the raw beacon render measures
# luminance sd 31.6 where vanilla's own beacon-bottom is 43.0.
#
# Also bakes a soft glow under the arc bolts (the 1-2 px bevel core alone
# vanishes at in-game scale) and forces the shadow to pure black + alpha,
# which is what draw_as_shadow expects.
import os
import sys
import glob

from PIL import Image, ImageFilter

def _skill_scripts(start=None):
    """Find .claude/skills/factorio-graphics/scripts by walking up.

    Not a fixed number of "..": these scripts are run headless by Blender, by
    python, and by exec() from Blender's console, and only some of those give
    __file__ a real value.
    """
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
COLS = 8
ORDER = ("base", "shadow", "anim", "arcs", "deck")

# Which paint-over preset each layer gets, and what it must not do.
#   shadow  pure black + alpha already; contrast on it is meaningless
#   arcs    an additive glow layer -- deepening its "crevices" would eat it
#   deck    carries translucent vapour, so the alpha tightening is turned off
#           (gamma 1.18 thins exactly the soft edges the effect is made of)
POST = {
    "base": dict(preset="entity"),
    "anim": dict(preset="entity"),
    "deck": dict(preset="entity", alpha_gamma=1.0),
    "shadow": None,
    "arcs": None,
}


def paint(layer, im):
    cfg = POST.get(layer)
    if cfg is None or "--no-post" in sys.argv:
        return im
    cfg = dict(cfg)
    return post.paint_over(im, cfg.pop("preset"), **cfg)


def even_box(bb):
    return imaging.even_box(bb, CANVAS, pad=2)


def union_bbox(images):
    return imaging.union_box(images, CANVAS, alpha_floor=8, pad=2)


def sheet(images, box, cols=COLS):
    return imaging.pack_sheet(images, box, cols)


def lua_shift(box):
    # util.by_pixel takes display px (= source px / 2 at scale 0.5); the
    # camera targets the entity centre, which sits at the canvas centre
    return imaging.shift_by_pixel(box, CANVAS, 0.5)


def add_arc_glow(img):
    # A tight halo that keeps the bolt readable at 32 px, plus a wide faint
    # one that reads as the air around it ionising. Applied per FRAME: run
    # over the assembled sheet it bled every burst into the cell above, which
    # in game is a ghost arc eight frames early.
    near = img.filter(ImageFilter.GaussianBlur(1.6))
    near.putalpha(near.getchannel("A").point(lambda v: int(v * 0.75)))
    far = img.filter(ImageFilter.GaussianBlur(5))
    far.putalpha(far.getchannel("A").point(lambda v: int(v * 0.45)))
    return Image.alpha_composite(Image.alpha_composite(far, near), img)


def blacken_shadow(img, base_img):
    # Vanilla shadows are hard black/alpha (measured: essentially binary).
    # Threshold kills the soft ambient-occlusion haze the catcher picks up;
    # the 1 px blur restores edge anti-aliasing. Erasing every shadow pixel
    # the building itself covers is the other half: the base draws on
    # floor-mechanics, BELOW the game's shadow plane, so any overlap makes
    # the entity darken its own surface in game (measured: 80% of the sprite
    # was self-shadowed). Only the cast shadow on open ground may remain.
    return imaging.harden_shadow(img, base_img, threshold=110, blur=1.0,
                                 base_alpha_cut=32)


def frames_of(frames_dir, layer):
    return sorted(glob.glob(os.path.join(frames_dir, layer, "f*.png")))


def line_static(kind, box):
    return "%s: width=%d height=%d shift=util.by_pixel(%.1f, %.1f)" % (
        kind, box[2] - box[0], box[3] - box[1], *lua_shift(box))


def line_sheet(kind, box, count, img):
    return ("%s: width=%d height=%d shift=util.by_pixel(%.1f, %.1f) "
            "frames=%d line_length=%d sheet=%dx%d") % (
        kind, box[2] - box[0], box[3] - box[1], *lua_shift(box),
        count, COLS, img.width, img.height)


def load_numbers(path):
    out = {}
    if os.path.exists(path):
        for raw in open(path):
            if ":" in raw:
                k, v = raw.split(":", 1)
                out[k.strip()] = k.strip() + ":" + v.rstrip("\n")
    return out


def main():
    frames_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    numbers_path = os.path.join(HERE, "sheet_numbers.txt")
    numbers = load_numbers(numbers_path)

    base_paths = frames_of(frames_dir, "base")
    base_raw = Image.open(base_paths[0]) if base_paths else None
    if base_paths:
        painted = paint("base", base_raw)
        box = even_box(imaging.bbox_above(painted, 8))
        painted.crop(box).save(os.path.join(out_dir, "beacon-base.png"))
        numbers["base"] = line_static("base", box)
        print("  base post:", post.report(base_raw, painted))

    shadow_paths = frames_of(frames_dir, "shadow")
    if shadow_paths:
        # masking needs the base frame, not the packed sheet: it is the raw
        # canvas the shadow was rendered against. Mask against the PAINTED
        # base -- the alpha tightening moves the silhouette by a pixel and a
        # mask cut from the untightened one leaves a rim of self-shadow.
        if not base_paths:
            raise SystemExit("shadow needs the base frames to mask against")
        full = blacken_shadow(Image.open(shadow_paths[0]), paint("base", base_raw))
        box = even_box(imaging.bbox_above(full, 8))
        full.crop(box).save(os.path.join(out_dir, "beacon-shadow.png"))
        numbers["shadow"] = line_static("shadow", box)

    anim_paths = frames_of(frames_dir, "anim")
    if anim_paths:
        frames = [paint("anim", Image.open(p)) for p in anim_paths]
        box = union_bbox(frames)
        img = sheet(frames, box)
        img.save(os.path.join(out_dir, "beacon-anim.png"))
        numbers["anim"] = line_sheet("anim", box, len(frames), img)

    deck_paths = frames_of(frames_dir, "deck")
    if deck_paths:
        # The deck plant: holographic glyphs, cryo vapour and the cable
        # pulses. Plain alpha, not additive -- the vapour has to be able to
        # cover what is behind it, which an additive layer cannot do.
        frames = [paint("deck", Image.open(p)) for p in deck_paths]
        box = union_bbox(frames)
        img = sheet(frames, box)
        img.save(os.path.join(out_dir, "beacon-deck.png"))
        numbers["deck"] = line_sheet("deck", box, len(frames), img)

    arc_paths = frames_of(frames_dir, "arcs")
    if arc_paths:
        # glow first, box second -- cropping to the bare bolts would clip the
        # halo that is doing most of the work at in-game scale
        frames = [add_arc_glow(Image.open(p)) for p in arc_paths]
        box = union_bbox(frames)
        img = sheet(frames, box)
        img.save(os.path.join(out_dir, "beacon-arcs.png"))
        numbers["arcs"] = line_sheet("arcs", box, len(frames), img)

    report = "\n".join(numbers[k] for k in ORDER if k in numbers)
    print(report)
    with open(numbers_path, "w") as fh:
        fh.write(report + "\n")


main()
