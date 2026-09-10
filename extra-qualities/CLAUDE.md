# CLAUDE.md — Extra Qualities

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

**Two quality tiers above legendary — mythic (level 6) and celestial (level 8) — and the seven
tiers respread one per planetary milestone: epic on Fulgora, legendary after the first three
planets, mythic on Aquilo, celestial after promethium science.** The first three steps of the
odds ladder were made easier to pay for the two new ones, so each tier costs roughly what the
tier below it costs in vanilla at the point the player unlocks it. An assembling machine 3 runs
at 4 on mythic and 5 on celestial, which is the owner's power anchor.

**The mod owns all eleven icons**, not its own four: vanilla's five quality glyphs and its two
quality technology icons are redrawn too, because a set where two of seven follow different
rules is what a player notices.

**The data stage loads clean against base 2.1.17 with all four expansions (2026-09-10), and
`--check-unused-prototype-data` reports nothing ignored.** The roll mechanics the balance rests
on are measured against the engine. **Nothing has been played** — see `.ai-support/deferred.md`,
which leads on exactly that.

Read `.ai-support/index.md` first. Decisions and their reasons are there, not here.

## The five rules worth not re-deriving

- **`next_probability` is the per-step difficulty knob, and values above 1 are legal.** The
  upgrade chance is the machine's quality effect times this number, linearly — measured, not
  assumed. It is the only lever that reshapes the ladder's *curve*; module strength scales every
  step equally. Reasoning and the measurement: `.ai-support/analysis/quality-roll-mechanics.md`.
- **Edits to vanilla technologies belong in `data-updates.lua`, never `data.lua`.** space-age
  rewires `epic-quality` and `legendary-quality` from its own `data.lua` despite the file being
  called `base-data-updates.lua`, so a `data.lua` edit here is silently overwritten.
- **Adding a quality means raising `quality_selector_dropdown_threshold`.** Core sets it to 6
  and vanilla ships five qualities, so one extra tier costs the player their row of quality
  buttons. `data-final-fixes.lua` owns this; do not delete it as dead code.
- **A quality's `color` is its icon fill times 0.7.** Base's `normal` is written literally as
  `255 * 0.7`. Derive the prototype colour from the icon, never the reverse. `normal` is the
  one exception: its icon is drawn at 188 grey, not at 255.
- **The strength ladder is one table in `ladder.lua`, and it covers vanilla's tiers too.**
  All seven `default_multiplier` values live there, at one constant ratio of about 1.26.
  Do not set a multiplier anywhere else and do not extend vanilla's `1 + 0.3 * level` past
  legendary — that rule is uneven (legendary is a two-level jump) and inheriting it puts the
  unevenness at the top of the ladder, which shipped twice. `level` is a separate knob and
  drives only what is *counted*: equipment grid, pole supply area, accumulator capacity.
  Changing any multiplier moves the cost table in `.ai-support/balance.md`, because stronger
  quality modules farm quality faster — re-run `qsim.py` rather than reasoning about it.

## Layout

```
info.json                  base, quality, space-age; quality_required
data.lua                   what is ours: the qualities and the technologies
data-updates.lua           what is not: the chain, the odds, the two vanilla technologies
data-final-fixes.lua       the quality-picker threshold, counted after every other mod
prototypes/quality/qualities.lua           mythic and celestial
prototypes/quality/technology.lua          mythic-quality and celestial-quality
prototypes/quality/ladder.lua              the whole ladder: all seven multipliers,
                                           the chain, and the retuned odds
prototypes/quality/vanilla-technology.lua  epic and legendary move a planet each
prototypes/quality/icons.lua               vanilla's five glyphs and two dies, redrawn
changelog.txt
LICENSE
README.md
thumbnail.png              144x144
locale/en/extra-qualities.cfg
graphics/icons/            all seven quality glyphs, 64x64
graphics/technology/       all four technology dies, 480x256 mipmap strips
.ai-support/index.md       the map -- read it first
.ai-support/decisions.md   what is settled, and why
.ai-support/balance.md     the ladder's numbers and where they came from
.ai-support/art-direction.md  the pip language and the dies -- read before any icon work
.ai-support/deferred.md    open questions and parked work
.ai-support/journal.md     dated sessions, newest first
.ai-support/analysis/      measured engine findings
```

`assets/extra-qualities/` at the repo root holds the sources: `icons/` (the glyph generator, the
die model and the two render steps) and `balance/qsim.py` (the cost model). Only exported PNGs
land in `graphics/`. See the repo `CLAUDE.md` → *Asset sources*.

**No `.blend` is kept** — both generators are self-contained Python with no hand-edited state.
That stops being true the moment anything is posed by hand; the reasoning is in
`.ai-support/art-direction.md`.

## No control.lua

Nothing here needs runtime scripting. If that changes, record the decision in
`.ai-support/decisions.md` before writing the file.

## Regenerating the art

```
cd assets/extra-qualities/icons
py make_quality_icons.py
blender -b -P render_tech_icons.py -- <scratch dir>
py make_tech_icons.py <scratch dir>
```

Seven glyphs and four dies. The dies are rendered at 512 and the second step does the
paint-over, the drop shadow, the mipmap strips and `thumbnail.png`.

**The stock `icon` paint-over preset overshoots on a subject this smooth** — it took the dies to luminance sd 67 where vanilla's measure 52–56 — so
`make_tech_icons.py` passes its own amounts. Re-check them against vanilla after any change to
the model or the lighting.
