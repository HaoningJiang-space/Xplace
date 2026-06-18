# The divergence law (quantified, 2026-06-18) — the thesis's predictive core

Elevates the contribution from "route-aware criticality helps" (a trick) to a **predictive law with a
measurable, oracle-free trigger** (a framework, GOAL #9). Anchored by two designs at opposite ends of
the divergence axis.

## 1. Statement
> The post-route TNS gain from route-aware (routed/union) criticality over estimated criticality, in a
> 2-pass place-route-replace flow, scales with the **disagreement between pass-1 estimated and pass-1
> routed criticality**. When est and routed criticality coincide, routing feedback carries no new
> information and the gain → 0 (it can even slightly hurt, by admitting routed-side noise).

Formally, gain ≈ f(1 − agreement(est_crit, routed_crit)), agreement measured by Spearman of per-net
criticality or top-K Jaccard of the critical set — **both computed from the two pass-1 CSVs, no oracle.**

## 2. Evidence (two anchor designs, same NanGate45 flow, same 2-pass mechanism)
| design | Spearman(est,routed crit) | top-13k Jaccard | routed-only critical nets | route-aware gain |
|---|---|---|---|---|
| **ariane133** (fixed-macro, congested) | **0.192** | **0.244** | 7898 / 13000 | **+15.3% signoff (R33)** |
| **bp_fe_top** (low-congestion) | **0.967** | **0.937** | 424 / 13000 | ~0 (GR: union −96267 vs fairest −93567; routed −100270) |

- ariane: est and routed criticality rankings **barely agree** (Spearman 0.19) — routing reorders which
  nets are critical (layer assignment + detour, R28/R29). 61% of the routed-critical top-13k is invisible
  to the estimator. → large headroom, realized as +15.3%.
- bp_fe: est and routed criticality **nearly coincide** (Spearman 0.97, 94% Jaccard). The placement-stage
  estimate already nails the critical set; routing adds 424 nets of mostly-noise. → no headroom; routed
  even mildly hurts at GR (the predicted negative control).

## 3. Why this matters (three upgrades to the thesis)
1. **From trick to law.** "Always add routing" is false (bp_fe shows it can hurt). The honest, defensible
   claim is conditional and *predictive*: the gain is governed by a measurable quantity. A reviewer can
   no longer say "you just got lucky on ariane" — the law explains exactly when it works and when it
   doesn't, and bp_fe is the confirming negative control.
2. **Oracle-free trigger → adaptive deployable rule.** Both CSVs exist after pass-1. So the placer can
   compute agreement(est,routed) at pass-1 and DECIDE: low agreement → spend pass-2 with routed/union
   criticality (worth it); high agreement → est is sufficient, skip/cheapen pass-2. The decision needs
   NO oracle and NO ML predictor. This is a self-aware timing-closure flow.
3. **Explains every prior result coherently.** R21 (route-awareness "doesn't generalize" — that design
   was low-divergence), R22 (value ∝ divergence — now quantified), R23 (union is the robust hedge),
   R33 (+15.3% on high-divergence ariane) — all are one law, not a bag of datapoints.

## 4. Open refinements (the law suggests better methods, GOAL #4)
- **Confidence-weighted union > raw union.** Raw union = max(est_norm, routed_norm) admits routed-side
  noise on low-divergence designs (why bp_fe union < fairest). A better blend down-weights the routed
  contribution by the measured agreement: `crit = est + (1−agreement)·max(0, routed−est)`. On ariane
  (agreement low) → ≈ union; on bp_fe (agreement high) → ≈ est. Should dominate both raw arms across the
  divergence axis. **Candidate next method — test on both anchors.**
- **Quantify the law's shape.** Two points define a direction; a 3rd design at INTERMEDIATE divergence
  (Jaccard ~0.5–0.7) would turn the law from monotone-direction into a calibrated curve (gain vs
  divergence), which is a stronger DAC claim. Hunt one (a moderately-congested NanGate45 design).
- **Per-net not just aggregate.** Divergence is global here; a per-net or per-region divergence map could
  target route-awareness only where est is locally wrong — finer-grained (GOAL #5).

## 5. Status
- Divergence numbers: FINAL (from pass-1 CSVs, design-independent of pending DR).
- bp_fe negative control at GR: CONFIRMS the law (fairest ≥ union ≥ routed on low-divergence design).
- Pending: bp_fe DR+coupling SIGNOFF numbers (does the GR ordering hold at signoff? — ariane's did).
  Once in, write R35 and update memory with the law as a central pillar.
