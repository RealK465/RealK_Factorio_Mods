# Space Forge — identity

Register: **what this mod is, and how it stands relative to Space Age.** Edited in place — a
decision that changes is rewritten here rather than annotated, so this file always reads as the
present tense; the story of the change is appended to `journal.md`. Never ships (leading dot).

This file owns **one concept** and holds nothing else. Balance numbers, production chains,
progression, science and compatibility each get their own register the moment anything about
them is decided — see the concept map in `index.md`. That split is deliberate: a mod this size
outgrows a single decisions file fast, and a catch-all is where facts go to be lost.

Started 2026-08-08; identity answered 2026-08-19.

---

## Decided

- **An overhaul of Space Age, not of vanilla.** The positioning, in the owner's words: *what
  Krastorio 2 is to base Factorio, Space Forge is to Space Age.* The same game, with more
  content and more complexity — not a different game.

- **Space Age is required, not optional.** It is the substrate the mod overhauls, so a build
  without it is not a reduced Space Forge, it is nothing. Reading `feature_flags[...]` to light
  up expansion behaviour is the technique for a mod that works either way; this one does not.

  **This reverses the 2026-08-08 position** that no Space Age flag would be declared and none
  required by default. That position carried its own escape hatch — *"unless the overhaul is
  eventually designed around Space Age"* — and it now is.

  The consequence, accepted deliberately: a hard dependency, and a much smaller potential
  audience than a base-game overhaul would have.

- **Full overhaul from minute one.** Vanilla production chains are replaced rather than
  supplemented, starting at the first machine the player builds.

- **No new planets, for now.** The overhaul happens on the planets Space Age already ships.
  A scope decision rather than a design one, and the one most likely to be revisited — a mod at
  this scale that never adds a planet is unusual.

- **The game opens below vanilla's tier and ends well above it.** Steam-era machines on Nauvis
  simpler than the vanilla burner tier, rising to very powerful ones. This is settled as a
  *shape*; how many tiers there are and what unlocks them is a progression question and is not
  decided. `art-direction.md` treats it purely as a visual gradient and commits to nothing else.

- **Two mods.** `space-forge` for prototypes and logic, `space-forge-graphics` for art. The
  reasoning and the operational rules are in `../CLAUDE.md` → Two mods, on purpose.

- **Factorio 2.1 only.** No `legacy/2.0` build. Space Age is required regardless, and an
  overhaul is a large thing to keep on two tracks with nothing shipped to stay compatible with.

- **Names.** `space-forge` / `space-forge-graphics`, titles "Space Forge" / "Space Forge
  Graphics". Both portal names confirmed free on 2026-08-08.

## Required by the above, not yet done

Recorded so the gap between this register and the code is deliberate rather than drift. The mod
has **no code at all**, so nothing here is out of step with a working build — it is a to-do
list, not a defect.

- **`info.json` still declares only `base` and `space-forge-graphics`.** A dependency on
  `space-age` is now required, and whichever `*_required` feature flags follow from it need
  choosing. Do this through the `factorio-mod-setup` skill, not from memory — the flags fail
  silently when wrong.
- **`README.md`, `info.json` `description` and the locale strings** all still describe an
  unfinished mod with no theme. They are player-facing and become the portal description
  verbatim; rewrite them before the first release, in the owner's voice.

## Open — and which concept file each answer belongs to

Nothing below is decided. Each line names the register it becomes, so the answer lands in a file
about that concept rather than back in a catch-all.

| Question | Goes in |
|---|---|
| What the tiers are, what unlocks them, how the player moves between them | **progression.md** |
| What the production chains actually are — the metallurgy the mod is named for | **chains.md** |
| Whether the acts carry their own science packs and how they interleave with Space Age's ten | **science.md** |
| What the mod does with space platforms, if anything | **orbit.md** |
| Which mods are supported, which are declared `!` incompatible | **compatibility.md** |
| Recipe costs, machine speeds, power draw | **balance.md** |
| Startup and runtime settings, each earning its place | **settings.md** |

Two that belong here because they are identity questions:

- **The hook** — the one sentence a player reads on the portal. If it cannot be written, the
  scope is not yet a design.
- **Which part ships first as something playable.** Not urgent yet, but deciding it at month six
  instead of now is how an overhaul stalls.

## Rejected

A rejected idea that is not written down comes back.

- **Space Forge as a planet mod** — one new planet in the Space Age tradition, one twist, one
  science pack, additive and save-compatible. This is what the successful 2.0/2.1-era mods are
  (Maraxsis, Cerys, Muluna, Rabbasca) and it would have been by far the smallest scope.
  Rejected because the owner wants an overhaul of Space Age rather than an addition to it, and
  because the name describes a process rather than a place — Vulcanus already occupies
  "volcanic metallurgy planet".

- **Additive only, save-compatible.** Rejected in favour of the full overhaul above. The cost
  accepted with it: the mod cannot be dropped into a running save, it will carry a long
  incompatibility list, and it is a much larger build before anything is playable.

- **A base-game overhaul that treats Space Age as optional.** Rejected by the identity decision
  above.

- **A fixed four-act structure** (steam / electric / orbital / stellar), briefly written down on
  2026-08-19 and removed the same day. It was a progression design smuggled in through an art
  document, and progression is not decided. What survives is the visual gradient in
  `art-direction.md`, which describes how machines *look* as they get more advanced and commits
  to no tier count, no unlock order and no content.
