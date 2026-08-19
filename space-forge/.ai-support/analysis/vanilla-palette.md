---
verified_against: 2.1.14
verified: 2026-08-19
---

# Vanilla palette — what carries a machine's identity

Measured off the shipped sprites in the pinned dev install, not recalled. The question it
answers: **if Space Forge machines need to read as their own family without reading as
non-vanilla, which colours are free and which are spoken for?**

Method: every opaque pixel (alpha >= 250) of the named PNG, in HSV. "Paint" means saturation
>= 0.18 with value in 0.12–0.97, which excludes black crevices and blown speculars. "Rust band"
means hue 0–60 deg — the oxide/grime/soot substrate almost every Factorio entity shares.
Emissive layers are measured separately at alpha >= 40, value >= 0.25, saturation >= 0.12, so
the white-hot core (which carries no hue) does not vote.

**The measurement is `.claude/skills/factorio-entity-design/scripts/counterpart.py`**, which
encodes those thresholds as its constants. Run it rather than re-deriving; re-verify this file
against it when the dev install moves.

> **Corrected 2026-08-19.** The first pass used a hand-written sampler that strided a flat
> pixel index, which aliases onto `gcd(step, width)` columns — on one sheet it sampled an
> eighth of the sprite's width while looking thorough. Every figure below is the re-measured
> exact value; the paint percentages moved by up to 2 points and **§3's conclusion changed
> outright**. Recorded because the earlier numbers were quoted elsewhere before this fix.

---

## 1. Space Age machines are essentially unpainted — **Verified**

Fraction of opaque pixels whose hue falls **outside** the 0–60 deg rust band, i.e. actual
identity paint rather than oxide substrate:

| Entity | Sprite | Non-rust paint |
|---|---|---|
| Cryogenic plant | `cryogenic-plant/cryogenic-plant-anim1-base.png` | **0.1%** |
| Electromagnetic plant | `electromagnetic-plant/electromagnetic-plant-base.png` | **0.4%** |
| Beacon (base 1.x art) | `beacon/beacon-bottom.png` | **0.4%** |
| Biochamber | `biochamber/biochamber-animation.png` | **0.6%** |
| Crusher | `crusher/crusher-horizontal.png` | **1.0%** |
| Foundry | `foundry/foundry-base.png` | **1.7%** |
| Radar | `radar/radar.png` | 2.3% |
| Assembling machine 3 | `assembling-machine-3/assembling-machine-3-base.png` | **13.7%** |
| Lab | `lab/lab.png` | **44.7%** |

Paths are relative to `data/<base|space-age>/graphics/entity/`.

**The interpretation, and it is the load-bearing one for this mod:** base-game entities are
painted objects (lab 44.7%, assembling machine 3 13.7%). Space Age entities are *not* — every
one measured sits between **0.1% and 1.7%**. Their identity is carried by the **emissive
layer** over a dark, desaturated, rusted hull. This matches, and puts a number on, what the
`factorio-graphics` skill records as the 2.0 evolution: *"the static base is kept dark and
desaturated so animated light layers carry the identity."*

Space Forge builds on Space Age, so the Space Age convention is the one to match — see
`../art-direction.md`, which turns this into the paint-decreases-with-advancement rule.

## 2. Why the modal hue is the wrong statistic — **Verified**

Read naively, a hue histogram says every machine in Factorio is orange, including the blue
assembling machine 3. It does not — it says the **rust substrate outnumbers the paint**, which
is §1 seen from the other side. The lab is the only entity here whose paint out-votes its
grime, which is exactly why it is the one entity most players could name the colour of.

**Never identify a machine's identity colour from a modal hue.** Use the non-rust fraction.

Two readings that this method cannot produce, both **UNVERIFIED** and not chased:

- Assembling machine 3's non-rust paint resolves to yellow-olive, not the blue a player would
  name. The `-base` layer is the frame and skirt; the blue may live largely in `-anim`.
- The cryogenic plant's cold turquoise identity does not appear at all. Per the
  `factorio-graphics` skill that identity is applied through a **tint mask**, multiplied in by
  the engine, so it is not present in the source PNG's pixels. A tinted machine cannot be
  measured this way.

## 3. Emissive accents — which glow colours are taken — **Verified**

Dominant hue of the light/glow layers, which §1 establishes is where Space Age identity
actually lives. Status lamps are excluded: the standard vanilla working indicator is green on
every machine that has one, and letting it vote answers this question with green every time.

| Entity | Layer measured | Dominant emissive hue |
|---|---|---|
| Heating tower | `heating-tower-glow.png` | **0 deg red** (30%), 15 orange (29%) |
| Foundry | `foundry-lights-1.png` | **15 deg orange** (63%), 30 (27%) |
| Cryogenic plant | `cryogenic-plant-anim1-working.png` | 30 deg orange (45%), 15 (33%) |
| Biochamber | `biochamber-glow-2.png` | **30–45 deg orange-yellow** (42% / 37%) |
| Electromagnetic plant | `electromagnetic-plant-lights-rotate-1.png` | **195 deg cyan** (51%), 210 blue (36%) |
| **Fusion reactor** | `fusion-reactor-connection-1-glow.png` | **345 deg red-magenta** (81%), 330 magenta (19%) |

Conclusions:

- **Warm is crowded.** Four of six accents sit in 0–45 deg. Anything Space Forge lights orange
  reads as another foundry — which matters, because the foundry is the most thematically
  adjacent vanilla machine to a mod called Space Forge.
- **The electromagnetic plant owns cool cyan** at 195–210 deg. Not ours to take.
- **The fusion reactor owns magenta at 330–345 deg.** This was flagged UNVERIFIED in the first
  pass — *"the most likely vanilla occupant of the violet band"* — and measuring it confirmed
  the guess. It is **no longer an open question, and it moved the mod's reserved band**:
  `../art-direction.md` now reserves **290–330 deg**, violet proper, and stops short of the
  magenta the fusion reactor already uses.
- **What remains genuinely unclaimed is roughly 250–330 deg** — blue-violet through violet.

## 4. What this does not tell you

- Nothing here is a judgement about whether a colour *looks* right, only about whether it is
  already spoken for. The skill's rule stands: build the `vanilla.contact_sheet` A/B and look
  at it.
- Tinted layers are invisible to this method entirely (§2).
- Terrain is not accounted for. A palette that separates from the foundry on white may not
  separate from it on Vulcanus basalt.
