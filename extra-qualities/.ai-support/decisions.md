# Decided — Extra Qualities

What is settled, and why. Edited in place: a superseded entry is rewritten, never annotated.
Numbers live in `balance.md`; art lives in `art-direction.md`.

## Identity

- **Name `extra-qualities`, title "Extra Qualities", author RealK, version 0.1.0.** The owner
  asked for "something like extra qualities" and the plain name was free of any reason to
  avoid it. Unpublished, no tag — the portal name has **not** been checked for availability.
- **The two tiers are `mythic` (level 6) and `celestial` (level 8).** Chosen from four
  name-and-colour pairs the owner was shown; mythic continues the RPG rarity ladder vanilla's
  own names sit on, and celestial suits a tier that comes from the far side of the solar
  system.
- **Prototype names are unprefixed**, against the repo's usual short-mod-tag rule. Quality
  names surface in blueprint strings and circuit signals, where a prefix is noise, and vanilla's
  own are bare (`uncommon`, `rare`). The cost is a hard name collision with another mod that
  defines a quality called `mythic` — and any such mod also sets `legendary.next`, so the two
  would produce a broken ladder even if they loaded. Failing loudly is the better of the two.

## Dependencies

- **Hard `base`, `quality` and `space-age`; `quality_required = true`.** The owner asked for a
  mandatory Space Age dependency, and the engine agrees: a quality prototype with a `level`
  above 0, or any name other than `normal` / `quality-unknown`, requires Space Age. The
  technologies also name `cryogenic-science-pack` and `promethium-science-pack`, which only
  exist there.
- **No `recycler` dependency.** Nothing here touches the recycler prototype, and `quality`
  already depends on it.
- **`+ upcycler-planner`, recommended, with no version floor.** `+` is 2.1's recommended
  prefix: optional, but ticked on by default in the mod manager. Upcycler Planner is the
  natural companion, since a longer ladder means more upcycling loops to lay out. **The floor
  is omitted deliberately** — a version on an optional or recommended dependency is still
  enforced, so `+ upcycler-planner >= x` would disable *this* mod for anyone running an older
  copy of that one. Nothing here calls into it, so any version will do.

## Where each tier is gated

One tier per major milestone, as asked:

| Technology | Gate | Was |
|---|---|---|
| `epic-quality` | Fulgora — electromagnetic science | Gleba — agricultural science |
| `legendary-quality` | all three inner planets | Aquilo — cryogenic science |
| `mythic-quality` | Aquilo — cryogenic science | — |
| `celestial-quality` | promethium science | — |

Fulgora is covered by `epic-quality` being a prerequisite of `legendary-quality`, so naming
metallurgic and agricultural science there is what makes it "all three planets".

## Which stage does what

- **`data.lua`** defines what is ours: the two qualities and the two technologies.
- **`data-updates.lua`** edits what is not: the chain, the retuned odds, and the two vanilla
  technologies. **space-age rewires those technologies from its own `data.lua`**
  (`data/space-age/data.lua:65` requires `base-data-updates`), so doing it in our `data.lua`
  would be silently overwritten.
- **`data-final-fixes.lua`** raises the quality-picker threshold, counted after every other
  mod has added its own qualities.

## The quality picker keeps its buttons

`quality_selector_dropdown_threshold` in core is 6
(`data/core/prototypes/utility-constants.lua:627`) and vanilla ships five qualities, so **any**
mod adding a single tier turns the row of quality buttons into a dropdown. That is the loudest
complaint about the quality mods on the portal, and none of the 2.1 ones appear to have fixed
it. Raising the constant to one above the number of visible qualities keeps the buttons.

The ladder is left alone past eight visible qualities: a twenty-button row is worse than the
dropdown it replaced.

## The mod sets the whole strength ladder, vanilla's tiers included

Uncommon moves 1.3 → 1.28 and epic 1.9 → 2.0; rare and legendary keep vanilla's numbers. This
is not tinkering for its own sake — with celestial anchored at crafting speed 5 it is
arithmetically impossible to keep the steps from shrinking while leaving vanilla's uneven
epic → legendary jump in place. `balance.md` carries the proof and the resulting table.

## The mod owns all seven icons, not two

Vanilla's five quality glyphs and its `epic-quality` / `legendary-quality` technology icons are
overridden with redrawn versions. The reason is in `art-direction.md`: six pips cannot be drawn
to vanilla's geometry in a 64 px canvas, so the new tiers have to differ, and a set where two
of seven follow different rules is what a player actually notices. One generator for the seven
glyphs, one Blender model for the four dies.

The cost is that this mod changes the look of vanilla quality icons for anyone who installs it.
That is deliberate and was asked for. `quality-module` 1/2/3 keep their vanilla technology
icons — they are module art, not tier art, and nothing about them is inconsistent.

## Field set on the two new qualities

They carry vanilla's own field set and nothing more. **`default_multiplier` is deliberately
not among it** — all seven tiers' multipliers live in one table in `ladder.lua`, including
vanilla's, because the ladder only makes sense read as a whole and splitting it across two
files let an uneven step ship twice. `level` is still set here and still drives the counted
bonuses. Numbers and the reasoning in `balance.md`. Two departures, both forced:

- **`beacon_power_usage_multiplier` and `mining_drill_resource_drain_multiplier` are hand-picked.**
  Vanilla's ramp is `(6 - level) / 6`, which reaches zero at level 6. The engine refuses that
  for the beacon — the API says "must be >= 0.01" — but *allows* it for the drill, whose range
  is `[0, 1]`. Zero there is legal and would mean mining consumes no resource at all, which is
  a different game rather than a stronger quality, so both are picked by hand.
- **`cargo_wagon_inventory_size_multiplier` is omitted.** Vanilla's override is a nerf *below*
  the general multiplier that converges on it exactly at legendary, so past legendary the
  default already is the continuation.

## No `control.lua`

Nothing here needs runtime scripting. If that changes, it is a decision to record here before
the file is written.
