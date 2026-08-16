# Analysis — the research behind the design

Started 2026-08-15, before any mod code existed, and kept current since — implementation-time
findings are folded back in as they are verified. The condensed record of a deep exploration:
two upcycler blueprints decoded, ~14 more found and read, both reference planner mods cloned
and studied, and every API call checked against the installed 2.1.14's own `doc-html/` rather
than recalled.

It exists so none of that has to be re-derived. `../decisions.md` holds what is settled and
`../journal.md` how it got there; this holds the evidence they rest on. Never ships (leading
dot on `.ai-support`).

| File | What is in it |
|---|---|
| `blueprints.md` | The decoded reference designs, the recycler eject mechanism, the scaling law, coordinate conventions |
| `layout-belt-ring.md` | **The chosen layout family — kept matching what the mod actually builds** |
| `layout-bot-loop.md` | The deferred second family, specified so it can be picked up as a GUI toggle later |
| `api.md` | Every verified API shape this mod needs, plus what could not be verified |
| `factorio-2.0.md` | Where 2.0.77 differs from `api.md`'s 2.1 picture and where it agrees — the planner seam's evidence, the 2.0 recycler ground truth. Read before touching the seam or anything on `legacy/2.0` |
| `quality-math.md` | Quality roll maths, recycler mechanics, known failure modes of closed loops |
| `reference-mods.md` | P.U.M.P., Mining Patch Planner and flib — patterns to copy and to avoid |
| `blueprints/` | The two source blueprint strings, so the analysis is reproducible |

## Reproducing the blueprint decoding

A Factorio blueprint string is `"0"` + base64( zlib-deflate( JSON ) ). A book is
`{"blueprint_book": {"blueprints": [{"blueprint": {...}, "index": n}, ...]}}`.

```python
import base64, zlib, json
def decode(s):
    assert s[0] == "0", "unknown blueprint version byte"
    return json.loads(zlib.decompress(base64.b64decode(s[1:])).decode("utf-8"))
```

`blueprints/owner-upcycler.txt` is the repo owner's own build (parameterised, 18x16, never
tested). `blueprints/reference-book.txt` is a 12-blueprint book found online — the same design
solved at four target qualities across three machine types, which is what exposed the scaling
law. Both are other people's work in the sense that only the owner's is ours; they are kept as
reference material, never redistributed.

## Confidence

Claims here are marked where they are not first-hand:

- **Verified** — read out of `doc-html/runtime-api.json`, `doc-html/prototype-api.json`, or the
  game's own `data/*.lua`, at the version the file's front matter names (2.1.14, or 2.0.77 for
  `factorio-2.0.md`). File:line given where it is game data.
- **Decoded** — read directly out of a blueprint's JSON.
- **UNVERIFIED** — could not be confirmed from a first-party source. Listed explicitly in
  `api.md` §9 so they can be probed in game rather than trusted.
- Community claims name their source and the game version they apply to.
