# Assembles rendered frames into Factorio sheets and prints the Lua numbers.
#
#   python make_sheets.py <frames_dir> <mod_graphics_dir>
#
# Every layer is cropped independently and carries its own shift, so editing
# one of them re-renders and re-packs only that one -- the anim sheet is 64
# Cycles frames of the rings and there is no reason to redo it for an arc
# change. Layers with no frames in <frames_dir> are left alone on disk and
# their numbers carry over from sheet_numbers.txt.
#
# Also bakes a soft glow under the arc bolts (the 1-2 px bevel core alone
# vanishes at in-game scale) and forces the shadow to pure black + alpha,
# which is what draw_as_shadow expects.
import os
import sys
import glob

from PIL import Image, ImageFilter

CANVAS = (512, 640)
COLS = 8
ORDER = ("base", "shadow", "anim", "arcs", "deck")


def even_box(bb):
    if bb is None:
        raise SystemExit("no content in layer")
    x0, y0, x1, y1 = (max(bb[0] - 2, 0), max(bb[1] - 2, 0),
                      min(bb[2] + 2, CANVAS[0]), min(bb[3] + 2, CANVAS[1]))
    # even width/height so scale=0.5 stays pixel-aligned in game
    if (x1 - x0) % 2:
        x1 += 1
    if (y1 - y0) % 2:
        y1 += 1
    return (x0, y0, x1, y1)


def union_bbox(images):
    bb = None
    for im in images:
        b = im.getbbox()
        if b:
            bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]),
                                       max(bb[2], b[2]), max(bb[3], b[3]))
    return even_box(bb)


def sheet(images, box, cols=COLS):
    w, h = box[2] - box[0], box[3] - box[1]
    rows = (len(images) + cols - 1) // cols
    out = Image.new("RGBA", (w * cols, h * rows))
    for i, im in enumerate(images):
        out.paste(im.crop(box), ((i % cols) * w, (i // cols) * h))
    return out


def lua_shift(box):
    # util.by_pixel takes display px (= source px / 2 at scale 0.5); the
    # camera targets the entity centre, which sits at the canvas centre
    cx = (box[0] + box[2]) / 2 - CANVAS[0] / 2
    cy = (box[1] + box[3]) / 2 - CANVAS[1] / 2
    return cx / 2, cy / 2


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
    # the 1 px blur restores edge anti-aliasing.
    a = img.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    a = a.filter(ImageFilter.GaussianBlur(1))
    # Erase every shadow pixel the building itself covers. The base draws on
    # floor-mechanics, BELOW the game's shadow plane, so any overlap makes
    # the entity darken its own surface in game (measured: 80% of the sprite
    # was self-shadowed). Only the cast shadow on open ground may remain.
    building = base_img.getchannel("A").point(lambda v: 0 if v >= 32 else 255)
    a = Image.composite(a, Image.new("L", a.size, 0), building)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.putalpha(a)
    return out


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
    here = os.path.dirname(os.path.abspath(__file__))
    numbers_path = os.path.join(here, "sheet_numbers.txt")
    numbers = load_numbers(numbers_path)

    base_paths = frames_of(frames_dir, "base")
    if base_paths:
        box = even_box(Image.open(base_paths[0]).getbbox())
        Image.open(base_paths[0]).crop(box).save(
            os.path.join(out_dir, "beacon-base.png"))
        numbers["base"] = line_static("base", box)

    shadow_paths = frames_of(frames_dir, "shadow")
    if shadow_paths:
        # masking needs the base frame, not the packed sheet: it is the raw
        # canvas the shadow was rendered against
        if not base_paths:
            raise SystemExit("shadow needs the base frames to mask against")
        full = blacken_shadow(Image.open(shadow_paths[0]), Image.open(base_paths[0]))
        box = even_box(full.getbbox())
        full.crop(box).save(os.path.join(out_dir, "beacon-shadow.png"))
        numbers["shadow"] = line_static("shadow", box)

    anim_paths = frames_of(frames_dir, "anim")
    if anim_paths:
        frames = [Image.open(p) for p in anim_paths]
        box = union_bbox(frames)
        img = sheet(frames, box)
        img.save(os.path.join(out_dir, "beacon-anim.png"))
        numbers["anim"] = line_sheet("anim", box, len(frames), img)

    deck_paths = frames_of(frames_dir, "deck")
    if deck_paths:
        # The deck plant: holographic glyphs, cryo vapour and the cable
        # pulses. Plain alpha, not additive -- the vapour has to be able to
        # cover what is behind it, which an additive layer cannot do.
        frames = [Image.open(p) for p in deck_paths]
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
