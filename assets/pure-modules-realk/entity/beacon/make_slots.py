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
import os
import sys

from PIL import Image, ImageFilter

CANVAS = (512, 640)


def main():
    frames_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    imgs = {}
    for layer in ("slot-box", "slot-lights"):
        imgs[layer] = Image.open(os.path.join(frames_dir, layer, "f0000.png"))

    bb = None
    for im in imgs.values():
        b = im.getbbox()
        bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]),
                                   max(bb[2], b[2]), max(bb[3], b[3]))
    x0, y0, x1, y1 = bb[0] - 4, bb[1] - 4, bb[2] + 4, bb[3] + 4
    if (x1 - x0) % 2:
        x1 += 1
    if (y1 - y0) % 2:
        y1 += 1
    box = (x0, y0, x1, y1)

    imgs["slot-box"].crop(box).save(os.path.join(out_dir, "beacon-module-mask-box.png"))
    strips = imgs["slot-lights"].crop(box)
    strips.save(os.path.join(out_dir, "beacon-module-mask-lights.png"))
    halo = strips.filter(ImageFilter.GaussianBlur(3))
    halo.putalpha(halo.getchannel("A").point(lambda v: min(255, int(v * 1.4))))
    Image.alpha_composite(halo, strips).save(os.path.join(out_dir, "beacon-module-lights.png"))

    cx = (x0 + x1) / 2 - CANVAS[0] / 2
    cy = (y0 + y1) / 2 - CANVAS[1] / 2
    report = ("slots: width=%d height=%d ref_shift=util.by_pixel(%.1f, %.1f)"
              % (x1 - x0, y1 - y0, cx / 2, cy / 2))
    print(report)
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "slot_numbers.txt"), "w") as fh:
        fh.write(report + "\n")


main()
