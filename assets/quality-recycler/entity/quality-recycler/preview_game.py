"""Composite the packed sheets on real planet ground, beside real vanilla machines.

    py preview_game.py <graphics_dir> <out_dir> [--frame N] [--dirs N,E,...]
                       [--grounds nauvis,fulgora,aquilo] [--no-night]
                       [--no-gif] [--no-vanilla]

`preview_sheets.py` answers "do the layers line up". This answers the two
questions only the surroundings can settle: whether a dark hull reads as mass
or as a hole on the terrain it will actually sit on, and whether the machine is
a weight class away from the vanilla ones it will sit beside. Both have been
got wrong on a flat background and only found in game, so the ground is cropped
out of the shipped tile sheets and the neighbours out of their real prototypes.

Draw order is the engine's: ground, shadow, base, animation cell, then the glow
ADDED rather than alpha-composited -- `draw_as_glow` with
`blend_mode = "additive"` is not a layer, and the `-light` sheets are declared
at scale 1.0 against the base's 0.5, so the glow cell is upscaled 2x first.
Everything composites at source resolution (64 px/tile) and is resampled down
to the 32 px/tile the game shows, so the plain sheets are the real thing and
the `-2x` ones are those pixels magnified, not extra detail.

Still no substitute for the engine: render-layer order against neighbours,
module tint and real daylight only resolve there.
"""
import argparse
import os
import re
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont


def _skill_scripts():
    d = os.path.dirname(os.path.abspath(__file__))
    while True:
        c = os.path.join(d, ".claude", "skills", "factorio-graphics", "scripts")
        if os.path.isdir(c):
            return c
        parent = os.path.dirname(d)
        if parent == d:
            raise RuntimeError("factorio-graphics scripts not found")
        d = parent


sys.path.insert(0, _skill_scripts())
from factorio_render import imaging, vanilla                   # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DIRS = ("N", "E", "S", "W", "flipped-N", "flipped-E", "flipped-S", "flipped-W")
PANEL = 448            # source px == 7 tiles; the game halves this to 224
AB_PANEL = 576         # the electromagnetic plant is 4x4 and throws a long shadow
PX_PER_TILE = 64       # source px per tile, i.e. a scale 0.5 sheet at 1:1
FOOTPRINT = (3, 3)
SHADOW_ALPHA = 0.55    # shadow sheets are stored pure black at full alpha and
                       # the engine draws them well short of that; ours and
                       # vanilla's get the same factor or the A/B lies
# Must match prototypes/recycler/pictures.lua, or the GIF lies about tempo.
ANIMATION_SPEED = 2
NIGHT = (0.19, 0.21, 0.30)   # ~22% with the blue cast Factorio's night has


def numbers():
    out = {}
    for raw in open(os.path.join(HERE, "sheet_numbers.txt")):
        if ":" not in raw:
            continue
        key, rest = raw.split(":", 1)
        shift = rest.split("shift=util.by_pixel(")[1].split(")")[0]
        d = dict(shift=tuple(float(v) for v in shift.split(",")))
        for tok in rest.split():
            if "=" in tok and not tok.startswith("shift"):
                k, v = tok.split("=", 1)
                if k in ("width", "height", "frames", "line_length"):
                    d[k] = int(v)
        out[key.strip()] = d
    return out


def cell(sheet, w, h, i, cols=8):
    r, c = divmod(i, cols)
    return sheet.crop((c * w, r * h, (c + 1) * w, (r + 1) * h))


def sidecar(stem):
    """Geometry out of the `.lua` beside a vanilla sheet -- the same file
    util.sprite_load reads, so it never drifts from what the engine loaded."""
    txt = open(stem + ".lua", encoding="utf-8").read()
    sx, sy = txt.split("util.by_pixel(")[1].split(")")[0].split(",")
    m = {"shift": (float(sx), float(sy))}
    for k in ("width", "height", "line_length"):
        hit = re.search(r"\b%s\s*=\s*(\d+)" % k, txt)
        if hit:
            m[k] = int(hit.group(1))
    return m


# path under data/, repeat unit in source px, candidate cell origins. A
# tile_variations_template sheet keeps 16 one-tile variants at y=0 and the game
# mixes them per tile, so mix them here too; a material_background is one
# seamless 8x8-tile texture and seams the moment it is diced into tiles.
GROUNDS = {
    "nauvis": ("base/graphics/terrain/grass-1.png", 64,
               [(i * 64, 0) for i in range(8)]),
    "fulgora": ("space-age/graphics/terrain/fulgoran-dust.png", 512, [(0, 0)]),
    "aquilo": ("space-age/graphics/terrain/aquilo/snow-flat.png", 64,
               [(i * 64, 0) for i in range(8)]),
}
FLAT = {"nauvis": "nauvis-grass", "fulgora": "fulgora", "aquilo": "aquilo"}
GROUND_SRC = {}


def ground(name, size=PANEL):
    """Seamless terrain at source resolution, or a flat colour that says so."""
    spec = GROUNDS.get(name)
    path = (os.path.join(vanilla.find_data_dir(), *spec[0].split("/"))
            if spec else None)
    if not path or not os.path.isfile(path):
        GROUND_SRC[name] = "flat fallback -- no sheet at %s" % (path or "?")
        flat = vanilla.TERRAIN[FLAT.get(name, "nauvis-dirt")]
        return Image.new("RGBA", (size, size), tuple(flat) + (255,))
    GROUND_SRC[name] = path
    sheet = Image.open(path).convert("RGBA")
    unit, origins = spec[1], spec[2]
    cells = [sheet.crop((x, y, x + unit, y + unit)) for x, y in origins]
    out = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    # line the tile grid up with the footprint box so the machine sits on tile
    # boundaries, the way it does in game
    start = (size // 2 - FOOTPRINT[0] * PX_PER_TILE // 2) % unit - unit
    for gy, y in enumerate(range(start, size, unit)):
        for gx, x in enumerate(range(start, size, unit)):
            out.paste(cells[(gx * 73856093 ^ gy * 19349663) % len(cells)], (x, y))
    return out


def paint(canvas, img, shift, scale=0.5, shadow=False, glow=False):
    """Place one layer. `shift` is display px (util.by_pixel); the canvas runs
    at 64 px/tile, so a scale 0.5 sheet lands 1:1 and a scale 1.0 one doubles."""
    if scale * 2 != 1.0:
        img = imaging.scale(img, scale * 2)
    if shadow:
        a = img.getchannel("A").point(lambda v: int(v * SHADOW_ALPHA))
        img = Image.new("RGBA", img.size, (0, 0, 0, 0))
        img.putalpha(a)
    x = int(canvas.width / 2 + shift[0] * 2 - img.width / 2)
    y = int(canvas.height / 2 + shift[1] * 2 - img.height / 2)
    if not glow:
        canvas.alpha_composite(img, (x, y))
        return
    # additive, premultiplied first: a soft glow edge carries full-strength RGB
    # at low alpha, which alpha-composites fine and adds far too hot
    rgb = Image.composite(img.convert("RGB"),
                          Image.new("RGB", img.size, (0, 0, 0)),
                          img.getchannel("A"))
    reg = canvas.crop((x, y, x + img.width, y + img.height)).convert("RGB")
    canvas.paste(ImageChops.add(reg, rgb).convert("RGBA"), (x, y))


def draw(canvas, png, meta, frame, missing, **kw):
    if meta is None or not os.path.isfile(png):
        missing.add(os.path.basename(png))
        return
    im = Image.open(png).convert("RGBA")
    w, h = meta.get("width", im.width), meta.get("height", im.height)
    ll = meta.get("line_length", 1) or 1
    if (w, h) != im.size:
        n = meta.get("frames") or max(1, (im.height // h) * ll)
        im = cell(im, w, h, frame % n, ll)
    paint(canvas, im, meta["shift"], **kw)


def our_layers(graphics, d, N):
    """(png, metadata, paint kwargs) for one direction, in engine draw order."""
    # Engine draw order: shadow, then the `animation` layers (base + anim),
    # then the working_visualisations in the order the prototype lists them --
    # fragments, then the glow, then the always-drawn status lamp. `fx` and
    # `lamp` were added when the entity went from four sheets to six.
    for suffix, key, kw in (("-shadow", "shadow", dict(shadow=True)),
                            ("", "base", {}),
                            ("-anim", "anim", {}),
                            ("-fx", "fx", {}),
                            ("-light", "light", dict(glow=True, scale=1.0)),
                            ("-lamp", "lamp", dict(glow=True))):
        yield (os.path.join(graphics, "quality-recycler-%s%s.png" % (d, suffix)),
               N.get("%s %s" % (d, key)), kw)


def darken(im):
    r, g, b, a = im.split()
    ch = [c.point(lambda v, f=f: int(v * f)) for c, f in zip((r, g, b), NIGHT)]
    return Image.merge("RGBA", ch + [a])


def panel(layers, frame, bg, missing, night=False):
    """Everything but the glow, then the night multiply, then the glow -- an
    additive light is exactly what a machine still shows after dark."""
    canvas, glows = bg.copy(), []
    for png, meta, kw in layers:
        if kw.get("glow"):
            glows.append((png, meta, kw))
        else:
            draw(canvas, png, meta, frame, missing, **kw)
    if night:
        canvas = darken(canvas)
    for png, meta, kw in glows:
        draw(canvas, png, meta, frame, missing, **kw)
    return canvas


# Read off the shipped 2.1 prototypes. Geometry comes from each sheet's own
# `.lua` sidecar; only what the prototype adds on top is spelled out here --
# `util.sprite_load` ADDS its `shift` to the sidecar's rather than replacing it.
EM = "__space-age__/graphics/entity/electromagnetic-plant/electromagnetic-plant-"
CP = "__base__/graphics/entity/chemical-plant/chemical-plant-"
VANILLA = {
    "recycler": ((2, 4), [
        ("__recycler__/graphics/entity/recycler/recycler-N-shadow", dict(shadow=True)),
        ("__recycler__/graphics/entity/recycler/recycler-N", {}),
        ("__recycler__/graphics/entity/recycler/recycler-N-lights", dict(glow=True)),
    ]),
    "electromagnetic-plant": ((4, 4), [
        (EM + "base-shadow", dict(shadow=True)),
        (EM + "shadow-warm-up", dict(shadow=True)),
        (EM + "base", {}),
        (EM + "main-warm-up", {}),
        (EM + "lights-warm-up", dict(glow=True)),
    ]),
    "chemical-plant": ((3, 3), [
        # the shadow is one 4-direction strip with no sidecar of its own
        (CP + "shadow.png", dict(shadow=True, width=312, height=222,
                                 shift=(27, 6), line_length=1)),
        (CP + "north-base", dict(extra=(0, -9))),
        (CP + "north-anim-1", dict(extra=(0, -9))),
        (CP + "north-anim-2", dict(extra=(0, -9))),
    ]),
}


def vanilla_layers(name):
    for path, kw in VANILLA[name][1]:
        kw = dict(kw)
        stem = vanilla.resolve(path)
        meta = sidecar(stem) if os.path.isfile(stem + ".lua") else {}
        for k in ("width", "height", "shift", "line_length"):
            if k in kw:
                meta[k] = kw.pop(k)
        dx, dy = kw.pop("extra", (0, 0))
        sx, sy = meta.get("shift", (0, 0))
        meta["shift"] = (sx + dx, sy + dy)
        yield stem if stem.endswith(".png") else stem + ".png", meta, kw


def _font(size=13):
    for n in ("arial.ttf", "segoeui.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)


FONT = _font()


def finish(canvas, label=None, footprint=FOOTPRINT):
    """Source res -> the 32 px/tile the game shows, then annotate, so the box
    and the label stay 1 px crisp instead of being resampled with the sprite."""
    im = imaging.resize(canvas, (canvas.width // 2, canvas.height // 2))
    d = ImageDraw.Draw(im)
    cx, cy = im.width // 2, im.height // 2
    hw, hh = footprint[0] * 16, footprint[1] * 16
    # white on its own vanishes on Aquilo snow, so both carry a dark backing
    d.rectangle([cx - hw - 1, cy - hh - 1, cx + hw, cy + hh], outline=(0, 0, 0, 110))
    d.rectangle([cx - hw, cy - hh, cx + hw - 1, cy + hh - 1],
                outline=(255, 255, 255, 170))
    if label:
        d.text((6, 4), label, fill=(255, 255, 255, 235), font=FONT,
               stroke_width=2, stroke_fill=(0, 0, 0, 190))
    return im


def grid(panels, cols=4):
    w, h = panels[0].size
    rows = (len(panels) + cols - 1) // cols
    sheet = Image.new("RGBA", (w * min(cols, len(panels)), h * rows), (24, 24, 26, 255))
    for i, p in enumerate(panels):
        sheet.paste(p, ((i % cols) * w, (i // cols) * h))
    return sheet


def nearest2x(im):
    return imaging.resize(im, (im.width * 2, im.height * 2), Image.NEAREST)


def animate(graphics, d, N, bg, missing, path):
    """The whole frame range at 2x, looping. Shadow and base never move, so
    they are composited once and copied -- 64 frames of a full panel otherwise."""
    meta = N.get("%s anim" % d)
    if not meta:
        missing.add("%s anim (no metadata)" % d)
        return False
    static = bg.copy()
    specs = list(our_layers(graphics, d, N))
    for png, m, kw in specs[:2]:
        draw(static, png, m, 0, missing, **kw)
    # PLAY IT AT THE ENGINE'S RATE, not at a comfortable GIF rate. The
    # prototype declares `animation_speed = 2`, which is 2 frames per tick =
    # 120 frames a second, so a 64-frame loop takes 32 ticks (0.53 s). A GIF
    # cannot hold 8.3 ms reliably -- most viewers floor at 20 ms and the format
    # stores durations in 10 ms units -- so take every STRIDE-th frame at
    # STRIDE x 8.3 ms instead. The 25 ms this asks for is stored as 20, so the
    # loop comes out 440 ms against the engine's 533: about 17% fast, and the
    # closest the format allows. At the previous flat 30 ms per frame the
    # preview ran 3.6x SLOW, and a rotor judged there reads as barely moving
    # when in game it is brisk -- a false negative that nearly cost a re-bake.
    n = meta.get("frames", 1)
    stride = 3
    step_ms = int(round(stride * 1000.0 / (60.0 * ANIMATION_SPEED)))
    frames = []
    for i in range(0, n, stride):
        c = static.copy()
        for png, m, kw in specs[2:]:
            draw(c, png, m, i, missing, **kw)
        frames.append(nearest2x(finish(c, "%s  f%02d" % (d, i))).convert("RGB")
                      .convert("P", palette=Image.ADAPTIVE, colors=128))
    frames[0].save(path, save_all=True, append_images=frames[1:],
                   duration=step_ms, loop=0, disposal=1)
    return True


def main():
    ap = argparse.ArgumentParser(description="game-accurate sprite preview")
    ap.add_argument("graphics")
    ap.add_argument("out_dir")
    ap.add_argument("--frame", type=int, default=8)
    ap.add_argument("--dirs", default=",".join(DIRS))
    ap.add_argument("--grounds", default="nauvis,fulgora,aquilo")
    ap.add_argument("--night", action=argparse.BooleanOptionalAction, default=True)
    ap.add_argument("--gif", action=argparse.BooleanOptionalAction, default=True)
    ap.add_argument("--vanilla", action=argparse.BooleanOptionalAction, default=True)
    a = ap.parse_args()

    dirs = [d for d in a.dirs.split(",") if d]
    grounds = [g for g in a.grounds.split(",") if g in GROUNDS]
    os.makedirs(a.out_dir, exist_ok=True)
    N, missing, written = numbers(), set(), []

    def save(im, name):
        p = os.path.join(a.out_dir, name)
        im.save(p)
        written.append((name, os.path.getsize(p)))

    def ours(d, bg, night=False):
        return panel(our_layers(a.graphics, d, N), a.frame, bg, missing, night)

    for g in grounds:
        bg = ground(g)
        panels = [finish(ours(d, bg), d) for d in dirs]
        if not panels:
            continue
        sheet = grid(panels)
        save(sheet, "grid-%s.png" % g)
        save(nearest2x(sheet), "grid-%s-2x.png" % g)
        if a.night:
            save(grid([finish(ours(d, bg, True), d) for d in dirs]),
                 "night-%s.png" % g)
        if a.vanilla:
            wide = ground(g, AB_PANEL)
            ab = [("quality-recycler %s" % d, finish(ours(d, wide)))
                  for d in ("N", "E")]
            ab += [(n, finish(panel(vanilla_layers(n), a.frame, wide, missing),
                              footprint=VANILLA[n][0])) for n in VANILLA]
            save(vanilla.contact_sheet(ab, zooms=(1, 2)).convert("RGBA"),
                 "vanilla-ab-%s.png" % g)

    if a.gif:
        bg = ground("nauvis")
        for d in dirs:
            name = "anim-%s.gif" % d
            p = os.path.join(a.out_dir, name)
            if animate(a.graphics, d, N, bg, missing, p):
                written.append((name, os.path.getsize(p)))

    for g in grounds:
        print("[ground] %-8s %s" % (g, GROUND_SRC.get(g, "?")))
    if missing:
        print("[skipped] %s" % ", ".join(sorted(missing)))
    print("[preview] %d files, %.1f MB -> %s | %s"
          % (len(written), sum(s for _, s in written) / 1e6, a.out_dir,
             " ".join(n for n, _ in written)))


# Guarded so the module can be imported for its terrain and vanilla helpers
# without running a whole preview pass.
if __name__ == "__main__":
    main()
