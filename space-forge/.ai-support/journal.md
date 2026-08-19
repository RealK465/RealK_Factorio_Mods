# Space Forge — journal

What happened, newest first. **Append-only** — an entry is never edited once written, even when
it turns out to have been wrong; the correction is a new entry, and the *current* answer lives in
`identity.md` or `art-direction.md`. Only a moved file path is ever repaired in place. Never
ships (leading dot).

---

## 2026-08-19, later still — the palette was re-measured, and the violet rule moved

A cleanup review of the day's work found a sampling bug in the throwaway script the palette
figures came from, so every number in `analysis/vanilla-palette.md` was re-taken with an exact
measurement. Two consequences, one of them a rule change.

**The bug:** the sampler strided a *flat* pixel index and read `px[i % w, i // w]`, which aliases
onto `gcd(step, width)` columns. On one sheet that was 204 of 1632 columns — an eighth of the
sprite's width, sampled while looking thorough. The paint percentages moved by up to two points
(the foundry from 2.0% to 1.7%, the biochamber from 2.1% to 0.6%, the radar from 4.3% to 2.3%),
which shifts the Space Age band from 0.1–2.1% to **0.1–1.7%** but changes no conclusion: Space
Age machines are still essentially unpainted and still carry their identity in the glow.

**The rule change:** the first pass flagged the vanilla `fusion-reactor` glow as UNVERIFIED and
"the most likely vanilla occupant of the violet band". It was measured, and the guess was right —
**345 deg red-magenta at 81%, 330 magenta at 19%**. Magenta is Wube's. So `art-direction.md`'s
reserved band was narrowed from 290–345 to **290–330 deg**, violet proper, stopping short of the
fusion reactor. What is genuinely unclaimed is roughly 250–330.

Worth noting because it is the whole argument for the evidence genre: the rule was written from a
measurement, the measurement carried a caveat naming exactly what might overturn it, and checking
that caveat overturned it four hours later. A rule with no evidence file behind it would simply
have been wrong and stayed wrong.

The measurement is now a kept script rather than a throwaway —
`.claude/skills/factorio-entity-design/scripts/counterpart.py` — so the thresholds in
`analysis/vanilla-palette.md` and the ones anyone can run are the same thresholds.

## 2026-08-19, later — the acts came back out, and the folder split by concept

Two corrections to the session below, both from the owner, both the same day. The entry beneath
this one is left exactly as written: it is what was decided at the time, and a journal that gets
tidied after the fact is worth nothing.

**The four-act structure is gone.** `art-direction.md` had been built on a named ladder — Iron,
Arc, Vacuum, Star, with a planet or an orbit attached to each. The owner's correction: *that is
not decided, it is just art style.* And they were right about what had happened — the acts were a
**progression design smuggled in through an art document**. Nobody had decided how many tiers the
mod has, what unlocks them, whether there is an orbital stage at all, or whether a star ever gets
tapped, yet all four were sitting in a register as though settled.

What survives is the part that was genuinely about art: a **visual gradient** with three anchors
— crude, industrial, exotic — describing how a machine *looks* as it gets more advanced, and
committing to no tier count, no unlock order and no content. Everything downstream still works,
because the paint targets, the violet rule and the vessel-disappears silhouette rule were never
really about acts; they were about advancement, and the acts were just the labels. Two rules came
out better for it:

- **The wear map is now keyed to environment rather than to tier.** "No rust in Acts III and IV"
  became "nothing rusts in vacuum", which is true regardless of what the progression turns out to
  be, and stops being a claim about content.
- **The paint ladder interpolates** between anchors rather than quantising into four bands, so a
  machine that sits between two of them has an answer.

**The folder is now divided by concept, not by genre.** The owner's second correction: an
overhaul accumulates too many decisions for a file named **decisions.md**, and a catch-all named
after its lifecycle rather than its subject is where facts go to be lost. So **decisions.md** is
gone, replaced by `identity.md` — which owns exactly one concept and says so — and the rule is
written into `index.md` so the next session adds a concept file instead of growing a bucket.
`identity.md`'s open table now doubles as the **concept map**: every unanswered question names
the file its answer will land in (**progression.md**, **chains.md**, **science.md**, **orbit.md**,
**compatibility.md**, **balance.md**, **settings.md**), none of which exist yet, because stubbing them
would read as though the questions had been considered.

**Genre still sets the lifecycle** — that part of the repo rule is untouched and was never the
problem. Concept decides *which file*; genre decides *how it is maintained*. The two got
conflated because the repo's own examples happened to use genre names for both jobs; the rule in
`../../.claude/references/ai-support.md` now separates them explicitly, and points at
`pure-modules-realk`'s **balance.md** as the precedent that was already there.

**`analysis/` deliberately kept its generic name.** Renaming it to something concept-flavoured
would have looked more consistent and silently disabled the freshness check —
`check-ai-docs.py:172` keys `verified_against` enforcement on the literal path
`/.ai-support/analysis/`. The concept division happens inside the folder instead. Noted here
because it looks like an inconsistency and is actually a constraint.

## 2026-08-19 — the mod got a theme

The first real design session. The mod had been scaffolding since 2026-08-08 with the identity
question deliberately untouched; it is now answered, and the `.ai-support/` folder was
restructured to hold the answer.

**What the research turned up**, before any decision was made:

- **The tech-tree-overhaul era has passed.** The 2.0/2.1 scene is planet mods — Maraxsis, Cerys,
  Muluna, Rabbasca, Linox — each one planet, one twist, and explicitly non-invasive so it drops
  into an existing save. Krastorio 2 still is not natively Space Age compatible; Bob's and
  Pyanodons self-select for the hardcore. A wide overhaul in 2026 is swimming against this.
- **Factorio 2.1's headline change is platform-to-platform logistics.** Items move between space
  platforms without a round trip to the ground, which makes *specialised* platforms worth
  building for the first time. This mod already targets 2.1 only. Nothing on the portal has
  claimed that ground; the closest is Space Factory, a small infinite-research mod.
- **Real-world in-space manufacturing is a rich, unused seam**: vacuum arc remelting,
  containerless levitation melting, zero-g single-crystal casting, ZBLAN fibre drawing, vacuum
  smelting of asteroid feedstock. It makes the machines *legible*, which the design-language doc
  says is the whole game.

**What was measured**, rather than recalled — the full write-up is `analysis/vanilla-palette.md`:

- Space Age machines carry **0.1–2.1%** painted pixels against the base-game lab's 45% and
  assembling machine 3's 15.4%. Space Age identity is emissive, not painted. This became the
  paint ladder in `art-direction.md`.
- Four of five vanilla Space Age emissive accents sit in 0–45 deg. The electromagnetic plant
  owns cool cyan at 195 deg. **Violet and magenta are unclaimed**, which is why the mod spends
  them at exactly one moment rather than decoratively.
- A first pass measured the *modal* hue of each sprite and reported that every machine in
  Factorio is orange, including the blue assembling machine 3. That statistic was measuring the
  rust substrate, not the paint — precisely the failure the `factorio-graphics` skill warns
  about. The measurement was re-cut to "fraction outside the rust band", which is the number
  that survived into the register.

**What the owner decided:** an overhaul *of Space Age*, positioned as Krastorio 2 is to vanilla;
full overhaul from minute one; no new planets for now; the game opens on Nauvis with steam-era
machines below vanilla's burner tier and ends with very powerful ones; custom art for some
machines, the miner line first.

**What was derived from that and written into `art-direction.md`:** the vessel-disappears ladder
across four acts, the paint-down/emission-up gate with measured targets per act, the violet rule,
and the vacuum wear map that replaces rust with micrometeorite pitting and UV bleaching above the
atmosphere. Act IV (star tap) is provisional and the ladder is complete at three.

**A decision was superseded.** The 2026-08-08 position was *"no Space Age `*_required` flag, and
none by default"*, with a note that it would be revisited if the overhaul was ever designed
*around* Space Age. It now is, so the position is reversed: Space Age is the substrate and a
build without it is not a reduced Space Forge, it is nothing. the identity register (then named decisions.md) carries the new
position; `info.json` has not been changed yet and the gap is recorded there deliberately.

**Structural change to this folder.** It was one register file plus an index. It is now
a register for what the mod is, `art-direction.md` for how it looks, this journal, and
`analysis/` for measured facts — split by genre and by subject, at the owner's request, because
a single file could not hold a colour measurement and a scope decision under the same lifecycle.

**Still open and worth not forgetting:** every mechanical question. What each act changes, what
the science looks like, what the orbital act *does* beyond being where the good alloys are made,
the compatibility list, and which act ships first as something playable. None of the art
direction depends on any of them, which is why it could be settled first.
