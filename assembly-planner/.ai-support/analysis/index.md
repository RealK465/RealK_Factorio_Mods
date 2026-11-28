# analysis — Assembly Planner evidence

Engine facts measured for this mod. Each file carries `verified_against` front matter and marks
every claim with its confidence.

| File | What is in it | Read it when |
|---|---|---|
| `api.md` | the chest `bar` in blueprints, nameless normal-quality filters, the pipe row per machine, beacon reach around a cell, planet-locked recipes, the recipe-default trap; an inserter's round trip and hand, the stack inserter's wait, a stamped cell crafting at its planned rate | before changing `cell.lua`, `blueprint.lua`, the plan's defaults or its throughput arithmetic |

The rest — blueprint field shapes, the fluid rotation rule, module acceptance, beacon and pole
reach rules, the Confirm key, the GUI's measured behaviour — is Upcycler Planner's, in
`upcycler-planner/.ai-support/analysis/api.md`, and was not re-measured here unless `api.md`
says so.
