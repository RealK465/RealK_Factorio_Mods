"""Fetch CC0 PBR materials from the ambientCG public API. No API key.

The second CC0 source beside `polyhaven.py`, and the two genuinely differ:
Poly Haven's texture library is small and photographic; ambientCG runs to
2000+ and is much stronger on the flat industrial surfaces a Factorio machine
is actually made of -- tread plate, diamond plate, corrugated sheet, painted
and rusted metal, concrete, chain-link.

Stdlib only, so it runs the same from system Python, headless Blender
(`blender -b -P`), or `execute_blender_code` over the MCP bridge.

    python ambientcg.py search metal
    python ambientcg.py info Metal032
    python ambientcg.py fetch Metal032 --res 1K

Downloads land in assets/third-party/ambientcg/<asset>/ (git-ignored;
re-fetchable by id, so the id in a generator script IS the source, the same
rule as Poly Haven). Importable: `fetch("Metal032")` returns {map_key: Path}.

1K is plenty. Sprites end up 200-300 px, so texel detail barely survives the
render -- what survives is tonal variation, wear and grime, and a 4K download
costs render memory to deliver none of it.

**When a photo map beats procedural:** large flat repetitive surfaces whose
photographic grain noise cannot fake. **When it does not:** the machine's
painted body, where the tint must be sampled from vanilla and the wear stack
must sit on top. Best pattern is to combine -- multiply the photo diffuse over
the procedural paint at 0.2-0.4 for grain, keep rust/jitter/edge-wear on top,
and re-check the sampled chassis colour afterwards, because a photo's average
tint shifts it. See references/materials.md.
"""

import argparse
import json
import shutil
import sys
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

API = "https://ambientcg.com/api/v2/full_json"
DOWNLOAD = "https://ambientcg.com/get"
UA = {"User-Agent": "factorio-mod-graphics/1.0"}
REPO_ROOT = Path(__file__).resolve().parents[4]
DEFAULT_OUT = REPO_ROOT / "assets" / "third-party" / "ambientcg"

# ambientCG names its maps in the filename: <Asset>_<res>-<fmt>_<Map>.jpg
MAP_ALIASES = {
    "color": "Color", "diffuse": "Color", "albedo": "Color", "diff": "Color",
    "rough": "Roughness", "roughness": "Roughness",
    "normal": "NormalGL", "nor": "NormalGL", "nor_gl": "NormalGL",
    "ao": "AmbientOcclusion", "ambientocclusion": "AmbientOcclusion",
    "metal": "Metalness", "metallic": "Metalness",
    "disp": "Displacement", "displacement": "Displacement",
}
# NormalGL, not NormalDX: GL is the convention Blender's Normal Map node wants.
DEFAULT_MAPS = ["Color", "Roughness", "NormalGL", "AmbientOcclusion"]


def _get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
        return json.loads(r.read().decode())


def search(query="", limit=40, asset_type="Material"):
    params = {
        "type": asset_type, "q": query, "limit": str(limit),
        "include": "displayData",
        "sort": "popular",
    }
    data = _get_json(API + "?" + urllib.parse.urlencode(params))
    return [
        {"id": a.get("assetId"), "name": a.get("displayName") or a.get("assetId"),
         "category": a.get("displayCategory")}
        for a in data.get("foundAssets", [])
    ]


def info(asset_id):
    params = {"id": asset_id, "include": "downloadData,displayData"}
    data = _get_json(API + "?" + urllib.parse.urlencode(params))
    found = data.get("foundAssets") or []
    if not found:
        raise KeyError("no such ambientCG asset: %s" % asset_id)
    return found[0]


def variants(asset_id):
    """Downloadable zip names, e.g. Metal032_1K-JPG."""
    a = info(asset_id)
    out = []
    for _, group in (a.get("downloadFolders") or {}).items():
        for _, files in (group.get("downloadFiletypeCategories") or {}).items():
            for f in files.get("downloads", []):
                out.append(f.get("attribute") or f.get("fileName"))
    return [v for v in out if v]


def fetch(asset_id, res="1K", fmt="JPG", maps=None, out_dir=None, force=False):
    """Download and unpack one material. Returns {map_key: Path}."""
    out_dir = Path(out_dir or DEFAULT_OUT) / asset_id
    maps = [MAP_ALIASES.get(m.lower(), m) for m in (maps or DEFAULT_MAPS)]
    have = {}
    if out_dir.exists() and not force:
        for p in out_dir.glob("*"):
            for m in maps:
                if p.name.endswith("_%s.%s" % (m, fmt.lower())) or ("_" + m + ".") in p.name:
                    have[m] = p
        if len(have) >= len(maps):
            return have

    variant = "%s_%s-%s" % (asset_id, res, fmt)
    url = "%s?file=%s.zip" % (DOWNLOAD, variant)
    out_dir.mkdir(parents=True, exist_ok=True)
    tmp = out_dir / (variant + ".zip")
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=300) as r, open(tmp, "wb") as fh:
        shutil.copyfileobj(r, fh)
    with zipfile.ZipFile(tmp) as z:
        for member in z.namelist():
            if member.endswith("/"):
                continue
            name = Path(member).name
            # only the maps asked for -- a full pack carries PBR variants,
            # previews and a .usd nobody here needs
            if not any(("_" + m + ".") in name for m in maps):
                continue
            with z.open(member) as src, open(out_dir / name, "wb") as dst:
                shutil.copyfileobj(src, dst)
    tmp.unlink()

    result = {}
    for p in out_dir.glob("*"):
        for m in maps:
            if ("_" + m + ".") in p.name:
                result[m] = p
    return result


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("search"); s.add_argument("query", nargs="?", default="")
    s.add_argument("--limit", type=int, default=40)

    i = sub.add_parser("info"); i.add_argument("asset_id")

    f = sub.add_parser("fetch"); f.add_argument("asset_id")
    f.add_argument("--res", default="1K"); f.add_argument("--fmt", default="JPG")
    f.add_argument("--maps", nargs="*"); f.add_argument("--out")
    f.add_argument("--force", action="store_true")

    args = ap.parse_args(argv)
    if args.cmd == "search":
        for a in search(args.query, args.limit):
            print("%-16s %-34s %s" % (a["id"], a["name"], a["category"] or ""))
    elif args.cmd == "info":
        print("\n".join(sorted(variants(args.asset_id))[:40]))
    else:
        for k, v in sorted(fetch(args.asset_id, args.res, args.fmt,
                                 args.maps, args.out, args.force).items()):
            print("%-20s %s" % (k, v))
    return 0


if __name__ == "__main__":
    sys.exit(main())
