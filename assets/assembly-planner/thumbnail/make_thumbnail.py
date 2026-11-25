"""Assembly Planner's thumbnail.png: the shortcut button at 144x144.

The game's own green shortcut plate, nine-sliced up, with the shortcut's icon composed inside
it exactly as prototypes/planner/icons.lua composes it: an assembling machine 3 at 0.85 of the
icon, a requester chest at 0.55 shifted 0.38 down-right. Upcycler Planner's thumbnail was made
the same way (its .ai-support/decisions.md, Portal presentation), so the two read as a pair.

    py -3.14 assets/assembly-planner/thumbnail/make_thumbnail.py

Reads the game install the repo lives in (the folder above the repo) and writes the mod's
thumbnail.png, plus a 4x preview here (git-ignored) for looking at.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
GAME = os.path.dirname(REPO)
sys.path.insert(0, os.path.join(REPO, ".claude", "skills", "factorio-graphics", "scripts"))
from factorio_render import imaging  # noqa: E402  (alpha-correct resizing)

SIZE = 144
# slot_sized_button_green's default_graphical_set, core/prototypes/style.lua: a 17x17 cell in
# the GUI atlas with 8 px corners and a one-pixel stretchable middle.
PLATE_AT, PLATE_CELL, CORNER = (312, 792), 17, 8
MACHINE = os.path.join(GAME, "data", "base", "graphics", "icons", "assembling-machine-3.png")
CHEST = os.path.join(GAME, "data", "base", "graphics", "icons", "requester-chest.png")

# icons.lua, as fractions of one icon: size, then offset of the centre from the icon's centre.
MACHINE_SCALE, MACHINE_SHIFT = 0.85, 0.0
CHEST_SCALE, CHEST_SHIFT = 0.55, 0.38
# Margin between the plate's edge and the composed icon, in thumbnail pixels.
MARGIN = 12


def nine_slice(cell, size, corner):
    w, h = cell.size
    c = corner
    out = Image.new("RGBA", (size, size))
    mid = size - 2 * c

    def piece(box, dims):
        return cell.crop(box).resize(dims, Image.NEAREST)

    out.paste(piece((0, 0, c, c), (c, c)), (0, 0))
    out.paste(piece((w - c, 0, w, c), (c, c)), (size - c, 0))
    out.paste(piece((0, h - c, c, h), (c, c)), (0, size - c))
    out.paste(piece((w - c, h - c, w, h), (c, c)), (size - c, size - c))
    out.paste(piece((c, 0, w - c, c), (mid, c)), (c, 0))
    out.paste(piece((c, h - c, w - c, h), (mid, c)), (c, size - c))
    out.paste(piece((0, c, c, h - c), (c, mid)), (0, c))
    out.paste(piece((w - c, c, w, h - c), (c, mid)), (size - c, c))
    out.paste(piece((c, c, w - c, h - c), (mid, mid)), (c, c))
    return out


def icon(path):
    # The largest mip of a 120x64 strip is its first 64 columns.
    return Image.open(path).convert("RGBA").crop((0, 0, 64, 64))


def main():
    atlas = Image.open(os.path.join(GAME, "data", "core", "graphics", "gui-new.png")).convert("RGBA")
    x, y = PLATE_AT
    plate = nine_slice(atlas.crop((x, y, x + PLATE_CELL, y + PLATE_CELL)), SIZE, CORNER)

    # The composed box runs from the machine's top-left to the chest's bottom-right; one icon
    # unit is whatever fits that box inside the margin.
    lo = MACHINE_SHIFT - MACHINE_SCALE / 2
    hi = CHEST_SHIFT + CHEST_SCALE / 2
    unit = (SIZE - 2 * MARGIN) / (hi - lo)

    def place(img, scale, shift):
        side = round(scale * unit)
        layer = imaging.resize(img, (side, side))
        centre = MARGIN + (shift - lo) * unit
        at = round(centre - side / 2)
        plate.alpha_composite(layer, (at, at))

    place(icon(MACHINE), MACHINE_SCALE, MACHINE_SHIFT)
    place(icon(CHEST), CHEST_SCALE, CHEST_SHIFT)

    out = os.path.join(REPO, "assembly-planner", "thumbnail.png")
    plate.save(out, optimize=True)
    plate.resize((SIZE * 4, SIZE * 4), Image.NEAREST).save(os.path.join(HERE, "preview-4x.png"))
    print("wrote", out, plate.size)


if __name__ == "__main__":
    main()
