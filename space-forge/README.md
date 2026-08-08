# Space Forge

A large overhaul of Factorio, in early development. **Not playable yet** — this is
scaffolding, not a release.

## Two mods, one overhaul

Space Forge ships as a pair:

| Mod | Holds | Changes |
|---|---|---|
| [`space-forge`](../space-forge/) | prototypes, recipes, technologies, runtime scripts | often — balance and content patches |
| [`space-forge-graphics`](../space-forge-graphics/) | every sprite, icon and sound | rarely — only when art changes |

The art is the heavy half of an overhaul, and it is the half that changes least. Keeping it
in its own mod means a balance patch is a few kilobytes rather than a full re-download.
`space-forge` requires `space-forge-graphics`; installing either one pulls the other in.

## License

GPLv3 — see [`LICENSE`](LICENSE).
