"""Turn a Blender render into a shippable Factorio module icon.

Bloom, downscale, then the 120x64 mipmap strip vanilla uses.

The bloom has to happen here rather than in Blender's compositor: the glow
must extend the *alpha* as well as the colour, or the halo simply vanishes
against the game's background. Vanilla's module icons carry exactly that --
their cyan haze reaches past the chassis silhouette into transparent pixels.

    python export_icon.py item <render.png> <out.png>   ->  120x64
    python export_icon.py tech <render.png> <out.png>   ->  480x256
"""

import sys
from PIL import Image, ImageFilter

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


def mipmap_strip(icon, base):
    """base + base/2 + base/4 + base/8 laid out horizontally, as vanilla ships
    them: 120x64 for item icons, 480x256 for technology icons."""
    sizes = [base, base // 2, base // 4, base // 8]
    strip = Image.new("RGBA", (sum(sizes), base), (0, 0, 0, 0))
    x = 0
    for size in sizes:
        strip.alpha_composite(icon.resize((size, size), Image.LANCZOS), (x, 0))
        x += size
    return strip


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
    im = bloom(Image.open(src))
    if kind == "item":
        mipmap_strip(im.resize((64, 64), Image.LANCZOS), 64).save(dst)
    elif kind == "tech":
        # inset so the shadow has somewhere to fall inside the 256 box
        body = im.resize((216, 216), Image.LANCZOS)
        canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        canvas.alpha_composite(body, (14, 10))
        mipmap_strip(drop_shadow(canvas), 256).save(dst)
    else:
        raise SystemExit("kind must be 'item' or 'tech'")
    print("wrote", dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
