"""Turn a Blender render into a shippable Factorio module icon.

Bloom, paint-over, downscale, then the 120x64 mipmap strip vanilla uses.

The bloom has to happen here rather than in Blender's compositor: the glow
must extend the *alpha* as well as the colour, or the halo simply vanishes
against the game's background. Vanilla's module icons carry exactly that --
their cyan haze reaches past the chassis silhouette into transparent pixels.

Every resample goes through factorio_render.imaging, never Image.resize.
These renders are straight (unassociated) alpha, so a direct resize averages
colour across the alpha edge unweighted and lays a dark rind round the icon.
Measured on this mod's own art at a 4x reduction, 27-38% of the surviving
pixels came out more than 8/255 wrong, and an icon is nothing *but* edge at
64 px. Factorio loads with premul_alpha = true, so the shipped files are the
right convention; it was our downscaling that was wrong.

    python export_icon.py item <render.png> <out.png>   ->  120x64
    python export_icon.py tech <render.png> <out.png>   ->  480x256
"""

import os
import sys

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


sys.path.insert(0, _skill_scripts())

from factorio_render import imaging, post

# Above the lit chassis (~0.51 luminance) so the bloom picks up the lens and
# bevel highlights only -- lower, and the whole body hazes over.
BLOOM_THRESHOLD = 0.58
BLOOM_RADIUS = 16.0
BLOOM_RGB_GAIN = 1.05
BLOOM_ALPHA_GAIN = 0.85


def bloom(im):
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size

    bright = Image.new("RGB", (w, h), (0, 0, 0))
    bp = bright.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
            if lum <= BLOOM_THRESHOLD:
                continue
            k = (lum - BLOOM_THRESHOLD) / (1.0 - BLOOM_THRESHOLD)
            bp[x, y] = (int(r * k), int(g * k), int(b * k))

    blur = bright.filter(ImageFilter.GaussianBlur(BLOOM_RADIUS))
    bl = blur.load()

    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            br, bg_, bb = bl[x, y]
            glow = (0.2126 * br + 0.7152 * bg_ + 0.0722 * bb) / 255.0
            op[x, y] = (
                min(255, int(r + br * BLOOM_RGB_GAIN)),
                min(255, int(g + bg_ * BLOOM_RGB_GAIN)),
                min(255, int(b + bb * BLOOM_RGB_GAIN)),
                min(255, int(max(a, glow * 255.0 * BLOOM_ALPHA_GAIN))),
            )
    return out


def sharpen(im):
    """The paint-over pass, at full render size and after the bloom.

    Order is deliberate. The bloom is a 16 px-radius glow; the contrast pass
    works at radius 4, so it sits entirely below the glow's frequency band and
    cannot amplify the halo -- it only shapes the chassis. alpha_gamma is
    pinned to 1.0 so the bloomed alpha, which is the whole point of doing the
    glow here rather than in the compositor, comes through untouched.
    """
    return post.paint_over(im, "icon", alpha_gamma=1.0)


def drop_shadow(icon, offset=(11, 13), blur=7.0, opacity=150):
    """Technology icons carry a soft shadow; item icons do not. Vanilla's
    module tech icons all sit on one, and without it they read as stickers
    next to the rest of the tech tree."""
    w, h = icon.size
    shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    alpha = icon.split()[3].point(lambda a: min(opacity, a))
    shade.putalpha(alpha)
    shade = shade.filter(ImageFilter.GaussianBlur(blur))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(shade, offset)
    out.alpha_composite(icon, (0, 0))
    return out


def main(kind, src, dst):
    im = sharpen(bloom(Image.open(src)))
    if kind == "item":
        imaging.mipmap_strip(imaging.resize(im, (64, 64)), 64).save(dst)
    elif kind == "tech":
        # inset so the shadow has somewhere to fall inside the 256 box
        body = imaging.resize(im, (216, 216))
        canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        canvas.alpha_composite(body, (14, 10))
        imaging.mipmap_strip(drop_shadow(canvas), 256).save(dst)
    else:
        raise SystemExit("kind must be 'item' or 'tech'")
    print("wrote", dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
