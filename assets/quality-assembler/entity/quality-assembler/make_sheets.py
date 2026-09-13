# Assembles rendered frames into Factorio spritesheets and writes the
# sidecars.
#
#   py -3.14 make_sheets.py <frames_dir> <mod_graphics_dir> [--no-post]
#
# <frames_dir> is what render_entity.py wrote: <layer>/f####.png. One
# elevation, so one set of sheets: quality-assembler-<layer>.png.
#
# Between the render and the sheet sits the paint-over -- the step Wube do in
# Photoshop and never skip (FFF-146). It runs PER FRAME, before packing: every
# filter in it has a radius and over an assembled sheet it bleeds frame N
# into frame N-1.
#
# Each layer is cropped to its OWN union box across the loop and carries its
# own shift, so editing one re-packs only that one. The anim and idle sheets
# share a box so the two states line up to the pixel.
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

CANVAS = (320, 352)         # must match qa_gen.CANVAS
COLS = 8                    # vanilla is 64 frames at line_length 8
STEM = "quality-assembler"

# What each layer's paint-over must and must not do.
#   shadow  pure black + alpha already; contrast on it is meaningless
#   glow    additive into the light pass -- crevice deepening would eat it and
#           tightening its alpha chews the falloff that makes it read as light
POST_BY_LAYER = {
    "base": dict(ENTITY_POST),
    "anim": dict(ENTITY_POST),
    "idle": dict(ENTITY_POST),
    "pipe": dict(ENTITY_POST),
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


def frames_of(frames_dir, layer):
    return sorted(glob.glob(os.path.join(frames_dir, layer, "f*.png")))


def light_only(img, floor=14):
    """Drop what an additive layer cannot contribute: the near-black
    non-emissive surfaces the emission pass still returns, which add nothing
    under blend_mode additive but drag the crop box out to the whole hull."""
    keep = img.convert("RGB").convert("L").point(lambda v: 255 if v >= floor else 0)
    out = img.copy()
    out.putalpha(ImageChops.multiply(img.getchannel("A"), keep))
    return out


def light_bloom(img):
    """A soft halo round what glows: the light sheet is what the window
    THROWS, not the window. Kept modest -- the engine adds it in daylight
    too, and a generous halo reads as a cyan wash over the hero in play."""
    wide = img.filter(ImageFilter.GaussianBlur(5.0))
    wide.putalpha(wide.getchannel("A").point(lambda v: int(v * 0.30)))
    near = img.filter(ImageFilter.GaussianBlur(1.8))
    near.putalpha(near.getchannel("A").point(lambda v: int(v * 0.55)))
    return Image.alpha_composite(Image.alpha_composite(wide, near), img)


def lua_shift(box):
    return imaging.shift_by_pixel(box, CANVAS, 0.5)


def sidecar(out_dir, stem, box, line_length=1, shift=None):
    """The `.lua` vanilla puts beside every PNG, read by `util.sprite_load`.
    No frame_count here: util.sprite_load reads only width, height, shift and
    line_length from a sidecar; frame_count lives in pictures.lua."""
    w, h = box[2] - box[0], box[3] - box[1]
    sx, sy = shift if shift is not None else lua_shift(box)
    body = ["  width = %d," % w, "  height = %d," % h,
            "  shift = util.by_pixel(%.1f, %.1f)," % (sx, sy),
            "  line_length = %d," % line_length]
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

    base_paths = frames_of(frames_dir, "base")
    base_painted = None
    if base_paths:
        base_raw = Image.open(base_paths[0]).convert("RGBA")
        base_painted = paint("base", base_raw)
        box = imaging.even_box(imaging.bbox_above(base_painted, 8), CANVAS, pad=2)
        stem = STEM + "-base"
        base_painted.crop(box).save(os.path.join(out_dir, stem + ".png"))
        sidecar(out_dir, stem, box)
        lines.append(line_static("base", box))

    shadow_paths = frames_of(frames_dir, "shadow")
    if shadow_paths and base_painted is not None:
        # Masked against the PAINTED base: shadows composite ABOVE
        # floor-mechanics, so any overlap with the body darkens the entity's
        # own surface in game -- invisible in the PNGs, obvious on the map.
        full = imaging.harden_shadow(
            Image.open(shadow_paths[0]).convert("RGBA"), base_painted,
            threshold=110, blur=1.0, base_alpha_cut=32)
        sbox = imaging.even_box(imaging.bbox_above(full, 8), CANVAS, pad=2)
        stem = STEM + "-shadow"
        full.crop(sbox).save(os.path.join(out_dir, stem + ".png"))
        sidecar(out_dir, stem, sbox)
        lines.append(line_static("shadow", sbox))

    # anim and idle share one box so the two states register exactly
    anim_paths, idle_paths = frames_of(frames_dir, "anim"), frames_of(frames_dir, "idle")
    if anim_paths:
        anim = [paint("anim", Image.open(p).convert("RGBA")) for p in anim_paths]
        idle = [paint("idle", Image.open(p).convert("RGBA")) for p in idle_paths]
        abox = imaging.union_box(anim + idle, CANVAS, alpha_floor=8, pad=2)
        for name, frames in (("anim", anim), ("idle", idle)):
            if not frames:
                continue
            stem = STEM + "-" + name
            img = imaging.pack_sheet(frames, abox, COLS)
            img.save(os.path.join(out_dir, stem + ".png"))
            sidecar(out_dir, stem, abox, line_length=COLS)
            lines.append(line_sheet(name, abox, len(frames), img))

    lamp_paths = frames_of(frames_dir, "lamp")
    if lamp_paths:
        lit = light_bloom(light_only(Image.open(lamp_paths[0]).convert("RGBA")))
        lbox = imaging.even_box(imaging.bbox_above(lit, 8), CANVAS, pad=2)
        stem = STEM + "-lamp"
        lit.crop(lbox).save(os.path.join(out_dir, stem + ".png"))
        sidecar(out_dir, stem, lbox)
        lines.append(line_static("lamp", lbox))

    glow_paths = frames_of(frames_dir, "glow")
    if glow_paths:
        frames = [light_bloom(light_only(Image.open(p).convert("RGBA"))) for p in glow_paths]
        gbox = imaging.union_box(frames, CANVAS, alpha_floor=8, pad=2)
        # Packed at HALF resolution and declared scale 1.0: the same display
        # pixels for a quarter of the atlas, and the layer is a 5 px gaussian
        # either way. Resized per frame, never over the packed sheet.
        w, h = gbox[2] - gbox[0], gbox[3] - gbox[1]
        half = (max(2, w // 2), max(2, h // 2))
        cells = [imaging.resize(f.crop(gbox), half) for f in frames]
        stem = STEM + "-glow"
        img = imaging.pack_sheet(cells, (0, 0, half[0], half[1]), COLS)
        img.save(os.path.join(out_dir, stem + ".png"))
        # the SHIFT is the full-resolution crop's: scale 1.0 makes each
        # half-size cell cover the same display pixels as the full-res layers
        sidecar(out_dir, stem, (0, 0, half[0], half[1]), line_length=COLS,
                shift=lua_shift(gbox))
        lines.append(("glow: width=%d height=%d shift=util.by_pixel(%.1f, %.1f) "
                      "frames=%d line_length=%d scale=1.0 sheet=%dx%d")
                     % (half[0], half[1], *lua_shift(gbox), len(cells), COLS,
                        img.width, img.height))

    for key in ("N", "S", "E", "W"):
        paths = frames_of(frames_dir, "pipe-" + key)
        if not paths:
            continue
        im = paint("pipe", Image.open(paths[0]).convert("RGBA"))
        bb = imaging.bbox_above(im, 8)
        if bb is None:
            print("[sheets] pipe-%s is EMPTY -- nothing outside the hull" % key)
            continue
        pbox = imaging.even_box(bb, CANVAS, pad=2)
        stem = STEM + "-pipe-" + key
        im.crop(pbox).save(os.path.join(out_dir, stem + ".png"))
        # The engine draws a pipe_picture centred on the tile OUTSIDE the
        # connection -- the same origin pipe covers use -- not on the entity.
        # Measured 2026-09-13: with entity-relative shifts the north stub drew
        # a full tile past the pipe as a floating hook. The frames are
        # rendered about the entity centre, so the outside tile's offset (two
        # tiles, 64 display px) comes off the shift.
        ox, oy = {"N": (0, -64), "S": (0, 64), "E": (64, 0), "W": (-64, 0)}[key]
        sx, sy = lua_shift(pbox)
        sidecar(out_dir, stem, pbox, shift=(sx - ox, sy - oy))
        lines.append("pipe-%s: width=%d height=%d shift=util.by_pixel(%.1f, %.1f) (outside-tile origin)"
                     % (key, pbox[2] - pbox[0], pbox[3] - pbox[1], sx - ox, sy - oy))

    report = "\n".join(lines)
    print(report)
    with open(os.path.join(HERE, "sheet_numbers.txt"), "w") as fh:
        fh.write(report + "\n")


main()
