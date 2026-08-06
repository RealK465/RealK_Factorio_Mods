"""Fetch CC0 textures/HDRIs from the Poly Haven public API. No API key.

Stdlib only, so it runs the same from system Python, headless Blender
(`blender -b -P`), or `execute_blender_code` over the MCP bridge. The rig's
Blender MCP has no Poly Haven tools of its own -- this script is the route.

    python polyhaven.py search textures --categories metal
    python polyhaven.py info  metal_plate_02
    python polyhaven.py fetch metal_plate_02 --res 1k
    python polyhaven.py fetch industrial_sunset_02 --res 2k   # HDRIs work too

Downloads land in assets/third-party/polyhaven/<slug>/ (git-ignored;
re-fetchable by slug, so the slug in a generator script IS the source).
Importable: fetch("metal_plate_02") returns {map_key: Path}.
"""

import argparse
import json
import sys
import urllib.request
from pathlib import Path

API = "https://api.polyhaven.com"
UA = {"User-Agent": "factorio-mod-graphics/1.0"}
REPO_ROOT = Path(__file__).resolve().parents[4]
DEFAULT_OUT = REPO_ROOT / "assets" / "third-party" / "polyhaven"

# friendly name -> API map key (API casing is inconsistent: Diffuse, nor_gl, AO)
MAP_ALIASES = {
    "diff": "Diffuse", "diffuse": "Diffuse", "albedo": "Diffuse",
    "rough": "Rough", "roughness": "Rough",
    "nor": "nor_gl", "normal": "nor_gl", "nor_gl": "nor_gl",
    "ao": "AO", "arm": "arm", "metal": "Metal", "metallic": "Metal",
    "disp": "Displacement", "displacement": "Displacement",
    "hdri": "hdri",
}
DEFAULT_MAPS = ["Diffuse", "Rough", "nor_gl", "AO"]
# jpg is fine at sprite resolution; displacement and hdri need real bit depth
FORMAT_PREF = {"Displacement": ["png", "exr"], "hdri": ["hdr", "exr"]}
FORMAT_DEFAULT = ["jpg", "png", "exr"]


def _get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
        return json.loads(r.read().decode())


def search(asset_type="textures", categories=None, query=None):
    url = f"{API}/assets?type={asset_type}"
    if categories:
        url += "&categories=" + ",".join(categories)
    assets = _get_json(url)
    if query:
        q = query.lower()
        assets = {k: v for k, v in assets.items()
                  if q in k.lower() or q in v.get("name", "").lower()}
    return assets


def files(slug):
    return _get_json(f"{API}/files/{slug}")


def fetch(slug, res="1k", maps=None, out_dir=None):
    """Download the requested maps for one asset. Returns {map_key: Path}."""
    tree = files(slug)
    if maps is None:
        maps = ["hdri"] if "hdri" in tree else [m for m in DEFAULT_MAPS if m in tree]
    out = Path(out_dir) if out_dir else DEFAULT_OUT / slug
    out.mkdir(parents=True, exist_ok=True)

    got = {}
    for want in maps:
        key = MAP_ALIASES.get(want.lower(), want)
        if key not in tree:
            print(f"  [skip] {slug} has no '{key}' map (has: {', '.join(sorted(tree))})")
            continue
        by_res = tree[key]
        if res not in by_res:
            print(f"  [skip] {key}: no {res} (has: {', '.join(sorted(by_res))})")
            continue
        by_fmt = by_res[res]
        fmt = next((f for f in FORMAT_PREF.get(key, FORMAT_DEFAULT) if f in by_fmt), None)
        if fmt is None:
            print(f"  [skip] {key}/{res}: no usable format in {list(by_fmt)}")
            continue
        entry = by_fmt[fmt]
        dest = out / entry["url"].rsplit("/", 1)[-1]
        if dest.exists() and dest.stat().st_size == entry["size"]:
            print(f"  [cached] {dest.name}")
        else:
            print(f"  [fetch] {dest.name} ({entry['size'] // 1024} KB)")
            req = urllib.request.Request(entry["url"], headers=UA)
            with urllib.request.urlopen(req, timeout=120) as r:
                dest.write_bytes(r.read())
        got[key] = dest
    return got


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("search", help="list assets by type/category")
    s.add_argument("type", choices=["textures", "hdris", "models"])
    s.add_argument("--categories", help="comma-separated, e.g. metal,rusty")
    s.add_argument("--query", help="substring filter on slug/name")

    i = sub.add_parser("info", help="show an asset's maps and resolutions")
    i.add_argument("slug")

    f = sub.add_parser("fetch", help="download maps for an asset")
    f.add_argument("slug")
    f.add_argument("--res", default="1k")
    f.add_argument("--maps", help="comma-separated: diff,rough,nor,ao,metal,disp")
    f.add_argument("--out", help=f"target dir (default {DEFAULT_OUT}\\<slug>)")

    a = p.parse_args(argv)
    if a.cmd == "search":
        cats = a.categories.split(",") if a.categories else None
        for slug, meta in sorted(search(a.type, cats, a.query).items()):
            print(f"{slug:32} {meta.get('name', '')}")
    elif a.cmd == "info":
        tree = files(a.slug)
        for key in sorted(tree):
            v = tree[key]
            if isinstance(v, dict) and all(isinstance(x, dict) for x in v.values()):
                print(f"{key:14} {', '.join(sorted(v))}")
    elif a.cmd == "fetch":
        maps = a.maps.split(",") if a.maps else None
        got = fetch(a.slug, res=a.res, maps=maps, out_dir=a.out)
        print(f"{len(got)} map(s) in {next(iter(got.values())).parent}" if got
              else "nothing downloaded")


if __name__ == "__main__":
    main()
