# Assembles rendered frames into Factorio spritesheets and prints the Lua.
#
#   py -3.14 make_sheets.py <frames_dir> <mod_graphics_dir> [--no-post]
#
# <frames_dir> is what render_entity.py wrote: <dir>/<layer>/f####.png.
# One set of sheets per direction, named quality-recycler-<D>-<layer>.png.
#
# Between the render and the sheet sits the paint-over -- the step Wube do in
# Photoshop and never skip (FFF-146). It runs PER FRAME, before packing: every
# filter in it has a radius and over an assembled sheet it bleeds frame N into
# frame N-1, which in game is a ghost of the next frame showing early.
#
# Each layer is cropped to its OWN union box across the loop and carries its
# own shift, so editing one re-packs only that one. The anim sheet is 64 Cycles
# frames; there is no reason to redo it for a hull change.
import glob
import os
import sys

from PIL import Image, ImageChops, ImageFilter


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


HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _skill_scripts())
sys.path.insert(0, HERE)

from factorio_render import imaging, post                   # noqa: E402
from make_look import POST as ENTITY_POST                   # noqa: E402

CANVAS = (320, 384)
COLS = 8                    # vanilla is 64 frames at line_length 8
# Eight, matching the vanilla recycler exactly: recycler-N/E/S/W plus
# recycler-flipped-N/E/S/W for `use_mirroring`. The flipped set is real
# mirrored renders, not flipped PNGs -- the light is world-fixed, so flipping
# the image would carry every highlight to the wrong side.
DIRS = ("N", "E", "S", "W", "flipped-N", "flipped-E", "flipped-S", "flipped-W")
ORDER = ("base", "shadow", "anim", "fx", "glow", "lamp")

# What each layer's paint-over must and must not do.
#   shadow  pure black + alpha already; contrast on it is meaningless
#   glow    additive into the light pass -- crevice deepening would eat it and
#           tightening its alpha chews the falloff that makes it read as light
POST_BY_LAYER = {
    "base": dict(ENTITY_POST),
    "anim": dict(ENTITY_POST),
    "fx": dict(ENTITY_POST),
    "shadow": None,
    "glow": None,
    "lamp": None,
}


def paint(layer, im):
    cfg = POST_BY_LAYER.get(layer)
    if cfg is None or "--no-post" in sys.argv:
        return im
    cfg = dict(cfg)
    return post.paint_over(im, cfg.pop("preset"), **cfg)


def frames_of(frames_dir, d, layer):
    return sorted(glob.glob(os.path.join(frames_dir, d, layer, "f*.png")))


def light_only(img, floor=14):
    """Drop what an additive layer cannot contribute.

    The glow pass renders the whole machine with the lights off, so every
    non-emissive surface comes out near-black. Under blend_mode "additive"
    those pixels add exactly zero -- but they still drag the crop box out to
    the machine's full silhouette, which would make a sheet for four violet
    pips the same size as the one for the entire body.
    """
    keep = img.convert("RGB").convert("L").point(lambda v: 255 if v >= floor else 0)
    out = img.copy()
    out.putalpha(ImageChops.multiply(img.getchannel("A"), keep))
    return out


def light_bloom(img):
    # The light sheet is what the rotor THROWS, not the rotor. A tight halo
    # would keep the pip edges crisp and read as a second set of pips pasted
    # over the first; a wide soft falloff reads as glow.
    # Tightened after compositing the four layers the way the engine will:
    # `draw_as_glow` is additive and is drawn in daylight too, so a generous
    # halo that looks right on a dark test background reads as a magenta wash
    # over the hero in play. The vanilla recycler's own lights sheet is subtle.
    wide = img.filter(ImageFilter.GaussianBlur(5.0))
    wide.putalpha(wide.getchannel("A").point(lambda v: int(v * 0.26)))
    near = img.filter(ImageFilter.GaussianBlur(1.8))
    near.putalpha(near.getchannel("A").point(lambda v: int(v * 0.44)))
    return Image.alpha_composite(Image.alpha_composite(wide, near), img)


def lua_shift(box):
    return imaging.shift_by_pixel(box, CANVAS, 0.5)


def sidecar(out_dir, stem, box, line_length=1, extra=None, shift=None):
    """The `.lua` vanilla puts beside every PNG, read by `util.sprite_load`.

    Writing these is what keeps the prototype free of sprite numbers: a
    re-render changes the crop and the shift, and nothing in `prototypes/`
    has to be touched. Vanilla does exactly this for every entity sprite.
    """
    w, h = box[2] - box[0], box[3] - box[1]
    sx, sy = shift if shift is not None else lua_shift(box)
    body = ["  width = %d," % w, "  height = %d," % h,
            "  shift = util.by_pixel(%.1f, %.1f)," % (sx, sy),
            "  line_length = %d," % line_length]
    for k, v in (extra or {}).items():
        body.append("  %s = %s," % (k, v))
    with open(os.path.join(out_dir, stem + ".lua"), "w") as fh:
        fh.write("return\n{\n" + "\n".join(body) + "\n}\n")


def line_static(name, box):
    return "%s: width=%d height=%d shift=util.by_pixel(%.1f, %.1f)" % (
        name, box[2] - box[0], box[3] - box[1], *lua_shift(box))


def line_sheet(name, box, count, img):
    return ("%s: width=%d height=%d shift=util.by_pixel(%.1f, %.1f) "
            "frames=%d line_length=%d sheet=%dx%d") % (
        name, box[2] - box[0], box[3] - box[1], *lua_shift(box),
        count, COLS, img.width, img.height)


def main():
    frames_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    lines = []

    for d in DIRS:
        base_paths = frames_of(frames_dir, d, "base")
        if not base_paths:
            continue
        base_raw = Image.open(base_paths[0]).convert("RGBA")
        base_painted = paint("base", base_raw)
        box = imaging.even_box(imaging.bbox_above(base_painted, 8), CANVAS, pad=2)
        stem = "quality-recycler-%s" % d
        base_painted.crop(box).save(os.path.join(out_dir, stem + ".png"))
        sidecar(out_dir, stem, box)
        lines.append(line_static("%s base" % d, box))

        shadow_paths = frames_of(frames_dir, d, "shadow")
        if shadow_paths:
            # Masked against the PAINTED base, not the raw one: the alpha
            # tightening moves the silhouette by a pixel, and a mask cut from
            # the untightened version leaves a rim of self-shadow. Shadows
            # composite ABOVE floor-mechanics, so any overlap with the body
            # darkens the entity's own surface in game -- invisible in the
            # PNGs, obvious on the map.
            full = imaging.harden_shadow(
                Image.open(shadow_paths[0]).convert("RGBA"), base_painted,
                threshold=110, blur=1.0, base_alpha_cut=32)
            sbox = imaging.even_box(imaging.bbox_above(full, 8), CANVAS, pad=2)
            stem = "quality-recycler-%s-shadow" % d
            full.crop(sbox).save(os.path.join(out_dir, stem + ".png"))
            sidecar(out_dir, stem, sbox)
            lines.append(line_static("%s shadow" % d, sbox))

        anim_paths = frames_of(frames_dir, d, "anim")
        if anim_paths:
            frames = [paint("anim", Image.open(p).convert("RGBA")) for p in anim_paths]
            abox = imaging.union_box(frames, CANVAS, alpha_floor=8, pad=2)
            stem = "quality-recycler-%s-anim" % d
            img = imaging.pack_sheet(frames, abox, COLS)
            img.save(os.path.join(out_dir, stem + ".png"))
            # No frame_count here: util.sprite_load reads only width,
            # height, shift and line_length from a sidecar and takes the rest
            # from its options table, so a frame_count written here is
            # silently ignored and the layer loads as one frame. It lives in
            # prototypes/recycler/pictures.lua, exactly as vanilla's does.
            sidecar(out_dir, stem, abox, line_length=COLS)
            lines.append(line_sheet("%s anim" % d, abox, len(frames), img))

        fx_paths = frames_of(frames_dir, d, "fx")
        if fx_paths:
            frames = [paint("fx", Image.open(p).convert("RGBA")) for p in fx_paths]
            fbox = imaging.union_box(frames, CANVAS, alpha_floor=8, pad=2)
            stem = "quality-recycler-%s-fx" % d
            img = imaging.pack_sheet(frames, fbox, COLS)
            img.save(os.path.join(out_dir, stem + ".png"))
            sidecar(out_dir, stem, fbox, line_length=COLS)
            lines.append(line_sheet("%s fx" % d, fbox, len(frames), img))

        lamp_paths = frames_of(frames_dir, d, "lamp")
        if lamp_paths:
            lit = light_bloom(light_only(
                Image.open(lamp_paths[0]).convert("RGBA")))
            lbox = imaging.even_box(imaging.bbox_above(lit, 8), CANVAS, pad=2)
            stem = "quality-recycler-%s-lamp" % d
            lit.crop(lbox).save(os.path.join(out_dir, stem + ".png"))
            sidecar(out_dir, stem, lbox)
            lines.append(line_static("%s lamp" % d, lbox))

        glow_paths = frames_of(frames_dir, d, "glow")
        if glow_paths:
            frames = [light_bloom(light_only(Image.open(p).convert("RGBA")))
                      for p in glow_paths]
            gbox = imaging.union_box(frames, CANVAS, alpha_floor=8, pad=2)
            # Packed at HALF resolution and declared scale 1.0: it covers the
            # same display pixels for a quarter of the atlas, and the layer is
            # a 5 px gaussian either way so there is no detail to lose.
            # Resized per frame, never over the packed sheet -- a resample
            # across cell boundaries bleeds each frame into its neighbour.
            w, h = gbox[2] - gbox[0], gbox[3] - gbox[1]
            half = (max(2, w // 2), max(2, h // 2))
            cells = [imaging.resize(f.crop(gbox), half) for f in frames]
            stem = "quality-recycler-%s-light" % d
            img = imaging.pack_sheet(cells, (0, 0, half[0], half[1]), COLS)
            img.save(os.path.join(out_dir, stem + ".png"))
            # the half-size cells carry their own width/height, and scale 1.0
            # makes them cover the same display pixels as the full-res layers
            # The cells are half-size but the SHIFT is the full-resolution
            # crop's, because scale 1.0 makes each cell cover the same display
            # pixels. Deriving it from the half box instead puts the glow 69 px
            # left and 81 px up -- that is the offset of the box from the
            # canvas centre, which is not what this layer is measured against.
            sidecar(out_dir, stem, (0, 0, half[0], half[1]), line_length=COLS,
                    shift=lua_shift(gbox))
            lines.append(
                ("%s light: width=%d height=%d shift=util.by_pixel(%.1f, %.1f) "
                 "frames=%d line_length=%d scale=1.0 sheet=%dx%d")
                % (d, half[0], half[1], *lua_shift(gbox), len(cells), COLS,
                   img.width, img.height))

    report = "\n".join(lines)
    print(report)
    with open(os.path.join(HERE, "sheet_numbers.txt"), "w") as fh:
        fh.write(report + "\n")


main()
