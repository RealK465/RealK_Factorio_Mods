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

from PIL import Image, ImageChops, ImageFilter

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
ORDER = ("base", "shadow", "anim", "arcs", "deck", "glow")

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
    # draw_as_light + additive, like the arcs: it is added to the light pass,
    # so crevice deepening would eat it and tightening its alpha would chew the
    # soft falloff that makes it read as light rather than as a decal.
    "glow": None,
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


def light_only(img, floor=16):
    """Drop what an additive layer cannot contribute.

    The glow pass renders the whole moving assembly, and the rings come out
    near-black because they emit almost nothing. Under blend_mode "additive"
    those pixels add exactly zero, but they still drag the crop box out to the
    full ring silhouette -- carrying them would have made this sheet the same
    1744x1776 as the anim sheet to deliver a glow around the crystal.
    """
    keep = img.convert("RGB").convert("L").point(lambda v: 255 if v >= floor else 0)
    out = img.copy()
    out.putalpha(ImageChops.multiply(img.getchannel("A"), keep))
    return out


def light_gain(img, gain=1.75):
    """Brighten the light sheet, and ONLY the light sheet.

    The emission-only pass renders what the materials actually emit, which is
    faithful but dim -- mean (17,37,53) over the visible area. Additive into
    the light pass that reads as a crystal which is merely not-dark rather than
    one that is lit. Gaining here rather than raising the material emission is
    what lets the daytime crystal stay at the deeper blue it was tuned to:
    the two sheets come off the same render but only this one is boosted.
    """
    r, g, b, a = img.split()
    f = lambda v: min(255, int(v * gain))
    return Image.merge("RGBA", (r.point(f), g.point(f), b.point(f), a))


def add_light_bloom(img):
    # The light sheet is what the crystal THROWS, not the crystal. Reusing the
    # bolt halo here would keep the facet edges crisp and read as a second
    # crystal pasted over the first; a wide soft falloff reads as glow.
    # Tightened from 9/0.55 + 3/0.70: additive into the light pass is already
    # generous at night, and the wider halo reached well past the rings, which
    # reads as fog rather than as a lit core next to vanilla neighbours.
    wide = img.filter(ImageFilter.GaussianBlur(6.5))
    wide.putalpha(wide.getchannel("A").point(lambda v: int(v * 0.38)))
    near = img.filter(ImageFilter.GaussianBlur(2.5))
    near.putalpha(near.getchannel("A").point(lambda v: int(v * 0.58)))
    return Image.alpha_composite(Image.alpha_composite(wide, near), img)


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

    glow_paths = frames_of(frames_dir, "glow")
    if glow_paths:
        # Emission-only render of the rings and crystal, drawn with
        # draw_as_light + additive so the core keeps shining after dark --
        # vanilla's own beacon does exactly this with beacon-light.png.
        frames = [add_light_bloom(light_gain(light_only(
                      Image.open(p).convert("RGBA")))) for p in glow_paths]
        box = union_bbox(frames)
        # Packed at HALF the source resolution and declared scale = 1.0, so it
        # covers the same display pixels for a quarter of the atlas. This layer
        # is a 9 px gaussian either way -- there is no detail in it to lose --
        # and at full res it came out 4.2 MB, larger than the anim sheet it
        # only lights. Downscaled per frame, never over the packed sheet: a
        # resample across cell boundaries bleeds each frame into its neighbour.
        w, h = box[2] - box[0], box[3] - box[1]
        half = (w // 2, h // 2)
        cells = [imaging.resize(f.crop(box), half) for f in frames]
        img = imaging.pack_sheet(cells, (0, 0, half[0], half[1]), COLS)
        img.save(os.path.join(out_dir, "beacon-glow.png"))
        numbers["glow"] = ("glow: width=%d height=%d shift=util.by_pixel(%.1f, %.1f) "
                           "frames=%d line_length=%d scale=1.0 sheet=%dx%d") % (
            half[0], half[1], *lua_shift(box), len(cells), COLS, img.width, img.height)

    report = "\n".join(numbers[k] for k in ORDER if k in numbers)
    print(report)
    with open(numbers_path, "w") as fh:
        fh.write(report + "\n")


main()
