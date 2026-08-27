# Analysis — the evidence the design will rest on

Started 2026-08-27, before any mod code existed. It exists so nothing here has to be re-derived,
and so a number quoted from memory can be checked against one that was actually read.
`../decisions.md` holds what is settled and `../journal.md` how it got there; this holds the
evidence. Never ships (leading dot on `.ai-support`).

| File | What is in it |
|---|---|
| `vanilla-robots.md` | The measured baseline: both vanilla robots field by field, the two research caps that decide whether tiers stay meaningful, the force-wide worker-robot research and where its infinite level moves under Space Age, the recipes, and the prototype inheritance a copied tier gets for free |

## Still to be written

Named here rather than in a bullet nobody reads, because each is a real gap:

- **Reference mods.** No survey of the portal's existing robot-tier mods has been done. See
  `../deferred.md` → *Compatibility with existing robot mods*.
- **Quality on robots.** What Space Age quality actually scales on a flying robot is unknown and
  is listed as UNVERIFIED in `vanilla-robots.md` §7. It needs measuring before the tier axes are
  fixed, and the result belongs here.
- **Roboports.** Charging throughput, pad count and radii, if roboports ever come into scope
  (`../deferred.md` → *Roboports*).

## Confidence

Claims here are marked where they are not first-hand:

- **Verified** — read out of `doc-html/prototype-api.json`, `doc-html/runtime-api.json`, or the
  game's own `data/*.lua`, at the version the file's front matter names (2.1.16). `file:line`
  given where it is game data.
- **Partially read** — the location was checked but the prototype was not surveyed.
- **UNVERIFIED** — could not be, or simply was not, confirmed from a first-party source. Listed
  explicitly in `vanilla-robots.md` §7 so they are probed in game rather than trusted.
- Community claims name their source and the game version they apply to.
