# Locked experiment protocol (answers codex R24 flaws 1 & 2)

Predeclared BEFORE running the final matrix, so results are not best-of-trajectory or cherry-picked.

## The method's FROZEN deployable rule (flaw 2: no best-of-trajectory)
**Route-aware union TDP (1-shot, fixed):**
1. Place with ESTIMATED criticality net-weight (top-K, K=13000, scale=1.0) — a deployable cold start.
2. Route once (global route), extract routed per-net worst-slack.
3. crit_n = max(est_norm, routed_norm); place ONCE more with this union criticality (same K, scale).
4. STOP. Report THIS placement's post-route TNS. No iteration beyond step 3, no best-of-k selection.
Hyperparameters (K=13000, scale=1.0, 1 union step) are FROZEN here from ariane/bp_fe and applied
UNCHANGED to all held-out designs. Routing-call budget = 2 routes (cold + 1 re-place route) + final.
(The multi-iteration fixpoint R19 is an ANALYSIS probe, not the reported method — it had the
best-of-k issue; the frozen method is the 1-shot union above.)

## The locked baseline matrix (flaw 1)
Arms (all same K/scale/force-norm/routing-call budget, iso-congestion):
| arm | criticality | actuation | role |
|---|---|---|---|
| no-timing | — | — | floor |
| Xplace --timing_opt | estimated, path-based (GPUTimer) | per-pin | STRONG est actuation baseline (≈ Efficient-TDP class) |
| est net-weight | estimated | net-weight | est ablation |
| routed net-weight | routed (1 route) | net-weight | route-aware, pure-swap (R21: not robust) |
| **union net-weight (OURS)** | max(est,routed) | net-weight | the frozen method |
| (stretch) pin2pin-est | estimated | pin2pin-arc | true Efficient-TDP actuation (port or run upstream) |
Designs: ariane133, bp_fe_top, swerv_wrapper (≥3, spanning the divergence axis: ariane 0.24 high,
bp_fe 0.94 low, swerv TBD). Seeds: ≥3 placement × (routing deterministic on a placement, R1 CV≈0).
Metric: post-route WNS/TNS, at GR fidelity AND detailed-route+OpenRCX (coupling) spot-check (flaw 3).
Iso-congestion: report routed wirelength + overflow alongside TNS; a TNS win with worse congestion
is discounted.

## Decision rule (predeclared)
SOTA-supported IFF the frozen union method beats BOTH the no-timing floor AND the strongest estimated
baseline (--timing_opt / pin2pin-est) on post-route TNS, on a MAJORITY of the ≥3 designs, at
iso-congestion, surviving detailed-route+coupling. Else: report honestly as design-dependent
(divergence-gated) with the negative cases.

## Current partial fills (GR fidelity, single seed — to be completed/locked)
| design | no-tim | --timing_opt | est-nw | routed-nw | union-nw (OURS) |
|---|---|---|---|---|---|
| ariane | — | −2600 | −2685 | −2421 | **−2390.6** (+8% vs --timing_opt) |
| bp_fe  | −98519 | TODO | −63279 | −66841 | **−62045** (+2% vs est; routed REGRESSES) |
| swerv  | floorplanning | TODO | TODO | TODO | TODO |
Detailed-route+OpenRCX re-eval of ariane {blend,est}: RUNNING (flaw 3).
Honest status: ariane union beats the strong est baseline (--timing_opt) +8%; bp_fe union beats est
but margin small. Needs: swerv (3rd), multi-seed, DR-fidelity confirmation, pin2pin row.
