"""Cost of a quality tier, in normal items, for the ladder Extra Qualities ships.

Models the usual upcycling loop as a Markov chain over the quality chain: an assembler with
quality modules crafts the item, whatever reached the target tier is taken out, the rest is
recycled at 25% and rolled again.

The per-roll distribution here was checked against the engine's own
`LuaQualityPrototype.get_roll_chances` and matches to six decimal places - the probe and its
output are in extra-qualities/.ai-support/analysis/quality-roll-mechanics.md. The one thing
worth restating: `next_probability` above 1 is legal and behaves as a plain linear multiplier,
which is what makes it the per-step difficulty knob.

    py qsim.py

Prints the table in extra-qualities/.ai-support/balance.md.
"""

QM3 = 0.025                       # quality module 3, data/quality/prototypes/item.lua
# The shipped ladder: one constant ratio of about 1.26 per tier, keyed by level. Vanilla's
# 1 + 0.3 * level differs only at uncommon (1.3) and epic (1.9).
MULT = {0: 1.0, 1: 1.28, 2: 1.6, 3: 2.0, 5: 2.5, 6: 3.2, 8: 4.0}
VANILLA_MULT = {0: 1.0, 1: 1.3, 2: 1.6, 3: 1.9, 5: 2.5}

# The ladder as shipped. Index is the hop count along the chain, not `level`.
CHAIN = ["normal", "uncommon", "rare", "epic", "legendary", "mythic", "celestial"]
SHIPPED_NP = [1.4, 1.3, 1.1, 1.0, 1.0, 1.0, 1.0]
VANILLA_NP = [1.0] * 7
CHAIN_P = [0.1] * 7

# What the player realistically owns when each tier unlocks: (tier, module quality level).
# You cannot farm legendary with legendary modules before legendary exists.
STAGES = [
    ("epic (Fulgora)", "epic", 2),
    ("legendary (3 planets)", "legendary", 3),
    ("mythic (Aquilo)", "mythic", 5),
    ("celestial (promethium)", "celestial", 6),
]


def upgrade_matrix(n, q, np_, cp):
    """Row k -> distribution over destinations after one quality roll."""
    m = [[0.0] * n for _ in range(n)]
    for k in range(n):
        p_up = min(q * np_[k], 1.0)
        m[k][k] += 1.0 - p_up
        mass, j = p_up, k + 1
        while j < n and mass > 1e-15:
            chain = cp[j] if j + 1 < n else 0.0
            m[k][j] += mass * (1.0 - chain)
            mass *= chain
            j += 1
        if mass > 1e-15:
            m[k][n - 1] += mass
    return m


def _apply(v, m):
    out = [0.0] * len(v)
    for k, mass in enumerate(v):
        if mass:
            for j in range(len(v)):
                out[j] += mass * m[k][j]
    return out


def cost(tiers, q_asm, q_rec, np_, cp=CHAIN_P, retention=0.25, cycles=4000):
    """Normal items consumed per one item at the top of a `tiers`-long chain."""
    m_a = upgrade_matrix(tiers, q_asm, np_, cp)
    m_r = upgrade_matrix(tiers, q_rec, np_, cp)
    v = [0.0] * tiers
    v[0] = 1.0
    product = 0.0
    for _ in range(cycles):
        v = _apply(v, m_a)
        product += v[tiers - 1]
        v[tiers - 1] = 0.0
        v = _apply([x * retention for x in v], m_r)
        if sum(v) < 1e-14:
            break
    return 1.0 / product if product else float("inf")


def main():
    print("normal items per one finished item, assembling machine 3 -> electromagnetic plant\n")
    print("%-24s %-22s %-18s %s" % ("tier unlocked at", "modules in hand", "vanilla ladder", "this mod"))
    for label, tier, mod_level in STAGES:
        tiers = CHAIN.index(tier) + 1
        def band(np_, mult=MULT):
            a, e, r = (n * QM3 * mult[mod_level] for n in (4, 5, 4))
            return "%.0f - %.0f" % (cost(tiers, e, r, np_), cost(tiers, a, r, np_))

        asm, em = (n * QM3 * MULT[mod_level] for n in (4, 5))

        vanilla = band(VANILLA_NP, VANILLA_MULT) if tiers <= 5 else "--"
        print("%-24s %-22s %-18s %s"
              % (label, "%.0f%% / %.0f%%" % (asm * 100, em * 100), vanilla, band(SHIPPED_NP)))


if __name__ == "__main__":
    main()
