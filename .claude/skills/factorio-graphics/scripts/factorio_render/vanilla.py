"""Put your sprite next to a real vanilla one, on real ground, at real zoom.

The first line of the skill's final checklist is "opened a real vanilla PNG
and compared side by side at the same zoom", and until this module existed
there was nothing in the repo that did it -- the comparison was left to
memory, which is exactly how a sprite ends up twice the visual weight of the
entity it is meant to sit beside without anyone noticing.

What it does that opening two PNGs cannot:

* composites an entity's *layers* at their prototype shifts and scale, so you
  are looking at what the game draws rather than at one file of several;
* puts both on the terrain colour they will actually sit on -- dark structure
  on Nauvis dirt hides and reveals completely different mistakes than the
  same sprite on white or on a transparency checker;
* renders at game pixels (32 px/tile) and at a magnified zoom in one sheet,
  because silhouette failures show at 1x and material failures at 3x.

Layer specs come either from a `--dump-data` JSON (`from_data_raw`, exact and
never drifts) or by hand as `Layer(...)`. A few vanilla entities are built in
so a comparison needs no setup.
"""

import json
import os

import numpy as np
from PIL import Image, ImageDraw

from . import imaging


PX_PER_TILE = 32  # what the game draws at zoom 1

# Terrain to judge against. Sampled from the shipped tile art; a sprite is
# only ever "too dark" or "too pale" relative to the ground under it.
TERRAIN = {
    "nauvis-dirt": (150, 96, 45),
    "nauvis-grass": (86, 92, 45),
    "concrete": (94, 94, 90),
    "vulcanus": (108, 76, 66),
    "gleba": (96, 108, 52),
    "fulgora": (110, 96, 84),
    "aquilo": (150, 158, 168),
    "space": (12, 12, 18),
    "remnant-ground": (58, 54, 44),
}


def find_data_dir():
    """The game's `data/` directory: $FACTORIO_DATA, else the usual installs."""
    env = os.environ.get("FACTORIO_DATA")
    if env and os.path.isdir(env):
        return env
    candidates = [
        r"C:\Program Files (x86)\Steam\steamapps\common\Factorio\data",
        r"C:\Program Files\Steam\steamapps\common\Factorio\data",
        os.path.expanduser("~/Library/Application Support/Steam/steamapps/"
                           "common/Factorio/factorio.app/Contents/data"),
        os.path.expanduser("~/.steam/steam/steamapps/common/Factorio/data"),
    ]
    for c in candidates:
        if os.path.isdir(c):
            return c
    raise RuntimeError("game data/ not found -- set FACTORIO_DATA")


def resolve(path, mod_roots=None):
    """`__base__/graphics/...` -> a real file. mod_roots maps mod name to dir."""
    if not path.startswith("__"):
        return path
    mod, rest = path[2:].split("__", 1)
    rest = rest.lstrip("/\\")
    roots = dict(mod_roots or {})
    if mod not in roots:
        roots[mod] = os.path.join(find_data_dir(), mod)
    return os.path.join(roots[mod], rest)


class Layer:
    """One entry of a prototype's `layers` / `animation_list`, as drawn."""

    def __init__(self, filename, width, height, shift=(0.0, 0.0), scale=0.5,
                 frame=0, line_length=1, draw_as_shadow=False, x=0, y=0,
                 tint=None):
        self.filename = filename
        self.width, self.height = width, height
        self.shift = shift          # display pixels, i.e. util.by_pixel args
        self.scale = scale
        self.frame, self.line_length = frame, line_length
        self.draw_as_shadow = draw_as_shadow
        self.x, self.y = x, y
        self.tint = tint

    def render(self, mod_roots=None):
        im = Image.open(resolve(self.filename, mod_roots)).convert("RGBA")
        ll = max(1, self.line_length)
        c, r = self.frame % ll, self.frame // ll
        box = (self.x + c * self.width, self.y + r * self.height,
               self.x + (c + 1) * self.width, self.y + (r + 1) * self.height)
        im = im.crop(box)
        if self.scale != 1.0:
            im = imaging.scale(im, self.scale)
        if self.draw_as_shadow:
            # the engine draws shadow sprites as flat dark, not as their own
            # colour; ~50% black is what it looks like over ground
            a = im.getchannel("A").point(lambda v: int(v * 0.5))
            im = Image.new("RGBA", im.size, (0, 0, 0, 0))
            im.putalpha(a)
        elif self.tint:
            t = np.asarray(im, dtype=np.float32) / 255.0
            t[..., :3] *= np.array(self.tint[:3], dtype=np.float32)
            im = Image.fromarray((t * 255 + 0.5).astype(np.uint8), "RGBA")
        return im


def compose(layers, size=(320, 320), terrain="nauvis-dirt", mod_roots=None,
            footprint=None):
    """Draw an entity's layers, centred, on ground. `footprint` in tiles draws
    the collision box so overhang is visible rather than guessed."""
    bg = TERRAIN.get(terrain, terrain) if isinstance(terrain, str) else terrain
    canvas = Image.new("RGBA", size, tuple(bg) + (255,))
    cx, cy = size[0] // 2, size[1] // 2
    if footprint:
        d = ImageDraw.Draw(canvas)
        w, h = footprint[0] * PX_PER_TILE, footprint[1] * PX_PER_TILE
        d.rectangle([cx - w // 2, cy - h // 2, cx + w // 2 - 1, cy + h // 2 - 1],
                    outline=(255, 255, 255, 60))
    for layer in layers:
        im = layer.render(mod_roots)
        canvas.alpha_composite(
            im, (round(cx + layer.shift[0] - im.width / 2),
                 round(cy + layer.shift[1] - im.height / 2)))
    return canvas


def contact_sheet(panels, zooms=(1, 3), gap=12, label_h=16, bg=(24, 24, 26)):
    """One image, one row per zoom, one column per panel. `panels` is a list
    of (label, PIL image)."""
    labels = [p[0] for p in panels]
    imgs = [p[1].convert("RGB") for p in panels]
    w, h = imgs[0].size
    total_w = gap + len(imgs) * (max(zooms) * 0 + 0)  # computed per row below
    rows = []
    for z in zooms:
        rows.append((z, [im.resize((w * z, h * z), Image.NEAREST) for im in imgs]))
    total_w = max(gap + sum(im.width + gap for im in r[1]) for r in rows)
    total_h = sum(label_h + r[1][0].height + gap for r in rows) + gap
    sheet = Image.new("RGB", (total_w, total_h), bg)
    d = ImageDraw.Draw(sheet)
    y = gap
    for z, row in rows:
        x = gap
        for label, im in zip(labels, row):
            d.text((x, y), "%s  %dx" % (label, z), fill=(210, 210, 210))
            sheet.paste(im, (x, y + label_h))
            x += im.width + gap
        y += label_h + row[0].height + gap
    return sheet


# --- reading real prototypes -------------------------------------------

def from_data_raw(dump_path, entity_name, kind=None, frame=0):
    """Layers for an entity out of a `--dump-data` JSON.

    The exact thing the engine loaded, including any change another mod made,
    so a comparison never drifts from the prototype. See the factorio-validate
    skill for producing the dump.
    """
    with open(dump_path, encoding="utf-8") as fh:
        raw = json.load(fh)
    proto = None
    for k, group in raw.items():
        if kind and k != kind:
            continue
        if isinstance(group, dict) and entity_name in group:
            proto = group[entity_name]
            break
    if proto is None:
        raise KeyError("%s not found in dump" % entity_name)

    out = []

    def walk(node):
        if isinstance(node, dict):
            if "filename" in node and ("width" in node or "size" in node):
                size = node.get("size")
                w = node.get("width", size if isinstance(size, int) else
                             (size or [0, 0])[0])
                h = node.get("height", size if isinstance(size, int) else
                             (size or [0, 0])[1])
                shift = node.get("shift", [0, 0])
                if isinstance(shift, dict):
                    shift = [shift.get("x", 0), shift.get("y", 0)]
                sc = node.get("scale", 1.0)
                out.append(Layer(
                    node["filename"], int(w), int(h),
                    shift=(shift[0] * PX_PER_TILE, shift[1] * PX_PER_TILE),
                    scale=sc, frame=frame,
                    line_length=node.get("line_length", 1) or 1,
                    draw_as_shadow=bool(node.get("draw_as_shadow")),
                    x=node.get("x", 0), y=node.get("y", 0)))
                return
            for v in node.values():
                walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)

    walk(proto.get("graphics_set", proto.get("animation", proto.get("picture", proto))))
    return out


# A few references that need no dump. Read off the shipped 2.1 prototypes;
# `footprint` is the entity's tile size, which is what makes overhang visible.
VANILLA = {
    "beacon": dict(footprint=(3, 3), layers=[
        Layer("__base__/graphics/entity/beacon/beacon-shadow.png", 244, 176,
              shift=(12.5, 0.5), draw_as_shadow=True),
        Layer("__base__/graphics/entity/beacon/beacon-bottom.png", 212, 192,
              shift=(0.5, 1)),
        Layer("__base__/graphics/entity/beacon/beacon-top.png", 96, 140,
              shift=(3, -19)),
    ]),
}


def vanilla_panel(name, terrain="nauvis-dirt", size=(320, 320)):
    spec = VANILLA[name]
    return compose(spec["layers"], size=size, terrain=terrain,
                   footprint=spec.get("footprint"))


# --- colour ------------------------------------------------------------

def srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float64) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def sample(path, alpha_floor=200, box=None):
    """Colour statistics over the opaque part of a sprite, plus the linear
    value to feed a material's base colour. Sample vanilla, drive the shader
    from it -- eyeballing produced grey where this produced Wube's own byte
    values."""
    im = Image.open(path).convert("RGBA")
    if box:
        im = im.crop(box)
    a = np.asarray(im, dtype=np.float32)
    m = a[..., 3] >= alpha_floor
    if not m.any():
        return {}
    rgb = a[..., :3][m]
    med = np.median(rgb, axis=0)
    return {
        "px": int(m.sum()),
        "mean_srgb": tuple(int(v) for v in rgb.mean(axis=0).round()),
        "median_srgb": tuple(int(v) for v in med.round()),
        "median_linear": tuple(round(float(v), 4) for v in srgb_to_linear(med)),
        "lum_mean": round(float((rgb @ [0.2126, 0.7152, 0.0722]).mean()), 1),
    }


def area_vs_footprint(panel_layers, footprint, mod_roots=None):
    """How much bigger the drawn sprite is than the entity's own tiles.

    Vanilla overhangs modestly and deliberately; a sprite several times its
    footprint reads as a different weight class than the entity it replaces,
    which is invisible in the PNG and obvious the moment both are on ground.
    """
    x0 = y0 = 1e9
    x1 = y1 = -1e9
    for layer in panel_layers:
        if layer.draw_as_shadow:
            continue
        im = layer.render(mod_roots)
        bb = imaging.bbox_above(im, 8)
        if not bb:
            continue
        cx, cy = layer.shift
        x0 = min(x0, cx - im.width / 2 + bb[0])
        y0 = min(y0, cy - im.height / 2 + bb[1])
        x1 = max(x1, cx - im.width / 2 + bb[2])
        y1 = max(y1, cy - im.height / 2 + bb[3])
    fw, fh = footprint[0] * PX_PER_TILE, footprint[1] * PX_PER_TILE
    return {
        "drawn_px": (round(x1 - x0), round(y1 - y0)),
        "footprint_px": (fw, fh),
        "ratio": (round((x1 - x0) / fw, 2), round((y1 - y0) / fh, 2)),
    }
