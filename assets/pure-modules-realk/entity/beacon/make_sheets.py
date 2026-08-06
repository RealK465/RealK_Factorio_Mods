# Assembles rendered frames into Factorio sheets and prints the Lua numbers.
#
#   python make_sheets.py <frames_dir> <mod_graphics_dir>
#
# anim and arcs share one crop box so they share one shift; base and shadow
# are cropped individually. Also bakes a soft glow under the arc bolts (the
# 1-2 px bevel core alone vanishes at in-game scale) and forces the shadow
# to pure black + alpha, which is what draw_as_shadow expects.
import os
import sys
import glob

from PIL import Image, ImageFilter

CANVAS = (512, 640)
COLS = 8


def union_bbox(paths):
    bb = None
    for p in paths:
        b = Image.open(p).getbbox()
        if b:
            bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]),
                                       max(bb[2], b[2]), max(bb[3], b[3]))
    if bb is None:
        raise SystemExit("no content found in " + str(paths[:1]))
    x0, y0, x1, y1 = (max(bb[0] - 2, 0), max(bb[1] - 2, 0),
                      min(bb[2] + 2, CANVAS[0]), min(bb[3] + 2, CANVAS[1]))
    # even width/height so scale=0.5 stays pixel-aligned in game
    if (x1 - x0) % 2:
        x1 += 1
    if (y1 - y0) % 2:
        y1 += 1
    return (x0, y0, x1, y1)


def sheet(paths, box, cols=COLS):
    w, h = box[2] - box[0], box[3] - box[1]
    rows = (len(paths) + cols - 1) // cols
    out = Image.new("RGBA", (w * cols, h * rows))
    for i, p in enumerate(paths):
        out.paste(Image.open(p).crop(box), ((i % cols) * w, (i // cols) * h))
    return out


def lua_shift(box):
    # util.by_pixel takes display px (= source px / 2 at scale 0.5); the
    # camera targets the entity centre, which sits at the canvas centre
    cx = (box[0] + box[2]) / 2 - CANVAS[0] / 2
    cy = (box[1] + box[3]) / 2 - CANVAS[1] / 2
    return cx / 2, cy / 2


def add_arc_glow(img):
    glow = img.filter(ImageFilter.GaussianBlur(4))
    glow.putalpha(glow.getchannel("A").point(lambda v: int(v * 0.65)))
    return Image.alpha_composite(glow, img)


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
    paths = sorted(glob.glob(os.path.join(frames_dir, layer, "f*.png")))
    if not paths:
        raise SystemExit("no frames for layer " + layer)
    return paths


def main():
    frames_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    lines = []

    base_paths = frames_of(frames_dir, "base")
    shadow_paths = frames_of(frames_dir, "shadow")
    anim_paths = frames_of(frames_dir, "anim")
    arc_paths = frames_of(frames_dir, "arcs")

    base_box = union_bbox(base_paths)
    move_box = union_bbox(anim_paths + arc_paths)

    base = Image.open(base_paths[0]).crop(base_box)
    base.save(os.path.join(out_dir, "beacon-base.png"))
    lines.append("base:   width=%d height=%d shift=util.by_pixel(%.1f, %.1f)"
                 % (base_box[2] - base_box[0], base_box[3] - base_box[1], *lua_shift(base_box)))

    shadow_full = blacken_shadow(Image.open(shadow_paths[0]), Image.open(base_paths[0]))
    b = shadow_full.getbbox() or (0, 0, *CANVAS)
    shadow_box = (max(b[0] - 2, 0), max(b[1] - 2, 0),
                  min(b[2] + 2, CANVAS[0]), min(b[3] + 2, CANVAS[1]))
    if (shadow_box[2] - shadow_box[0]) % 2:
        shadow_box = (shadow_box[0], shadow_box[1], shadow_box[2] + 1, shadow_box[3])
    if (shadow_box[3] - shadow_box[1]) % 2:
        shadow_box = (shadow_box[0], shadow_box[1], shadow_box[2], shadow_box[3] + 1)
    shadow_full.crop(shadow_box).save(os.path.join(out_dir, "beacon-shadow.png"))
    lines.append("shadow: width=%d height=%d shift=util.by_pixel(%.1f, %.1f)"
                 % (shadow_box[2] - shadow_box[0], shadow_box[3] - shadow_box[1], *lua_shift(shadow_box)))

    anim = sheet(anim_paths, move_box)
    anim.save(os.path.join(out_dir, "beacon-anim.png"))
    arcs = sheet(arc_paths, move_box)
    arcs = add_arc_glow(arcs)
    arcs.save(os.path.join(out_dir, "beacon-arcs.png"))
    lines.append("anim/arcs: width=%d height=%d shift=util.by_pixel(%.1f, %.1f) frames=%d line_length=%d sheet=%dx%d"
                 % (move_box[2] - move_box[0], move_box[3] - move_box[1], *lua_shift(move_box),
                    len(anim_paths), COLS, anim.width, anim.height))

    report = "\n".join(lines)
    print(report)
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "sheet_numbers.txt"), "w") as fh:
        fh.write(report + "\n")


main()
