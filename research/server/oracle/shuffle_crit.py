#!/usr/bin/env python3
# Shuffled-criticality NULL control (user P5): permute the criticality VALUES across net NAMES, seeded.
# Preserves the criticality value distribution (same #critical nets, same magnitudes) but assigns them to
# RANDOM nets. With fanout_norm downstream, this is "random net set, same cardinality/force/frac" — the
# null that isolates WHICH-nets (criticality) from how-much-force/geometry. Usage: shuffle_crit.py in out seed
import sys, random
inp, out, seed = sys.argv[1], sys.argv[2], int(sys.argv[3])
rows = []
with open(inp) as f:
    header = f.readline()
    for line in f:
        p = line.rstrip("\n").split(",")
        if len(p) >= 2:
            rows.append((p[0], p[1]))
names = [r[0] for r in rows]
vals  = [r[1] for r in rows]
rnd = random.Random(seed)
rnd.shuffle(vals)            # permute criticality values across net names
with open(out, "w") as f:
    f.write(header if header.strip() else "net,worst_slack_ns\n")
    for n, v in zip(names, vals):
        f.write("%s,%s\n" % (n, v))
print("SHUFFLED seed=%d %d nets -> %s" % (seed, len(rows), out))
