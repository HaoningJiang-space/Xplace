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
| design | #macros | Spearman(est,routed crit) | top-K Jaccard | route-aware gain |
|---|---|---|---|---|
| **ariane133** (fixed-macro, congested) | **132+ SRAM** | **0.192** (HIGH div) | **0.244** (top-13k) | **+15.3% signoff (R33)** |
| **bp_multi_top** (multi-core BP) | ~30 (6 ram types) | **0.776** (INTERMEDIATE div) | 0.878 (top-5k) | **measuring now (law's middle)** |
| aes (std-cell, NanGate45) | 0 | 0.946 | 0.639 (top-3k) | ~0 expected (R18 ρ≈0); unmeasured |
| bp_be_top | ~12 | 0.960 | 0.653 (top-5k) | ~0 predicted (Spearman high); unmeasured |
| bp_fe_top (low-congestion) | few | 0.967 | 0.937 (top-13k) | ~0 signoff (R35: tied within 0.3%) |

**★ bp_multi = the INTERMEDIATE-divergence design (codex Issue 3.1).** Spearman 0.776 sits cleanly between
ariane (0.19) and the 0.95–0.97 cluster — an independent multi-core design at the law's middle. Its
Spearman (0.78, intermediate) and Jaccard (0.88, near-low) DISAGREE → measuring its gain DISAMBIGUATES the
metric: intermediate gain ⇒ Spearman is the gain-predictor + law calibrated; ~0 gain ⇒ Jaccard wins (gain
needs near-total ranking disagreement). Either outcome sharpens the law. Macro count (~30) is between bp_be
(12) and ariane (132), consistent with divergence ∝ macro-congestion.

**★ KEY FINDING (4 designs): ariane is the LONE high-divergence OUTLIER; the regime is HEAVY MACRO-CONGESTION.**
Three of four NanGate45 designs cluster at Spearman ~0.95–0.97 (est≈routed criticality ranking); only ariane
(132+ SRAM macros) is low-Spearman 0.19. The discriminator is **macro count / congestion**: ariane's 132 fixed
SRAM blockages force long global nets through detours + layer reassignment that reorder criticality (R28/R29
"real half"); bp_be (~12 macros), bp_fe (few), aes (0) have short-enough nets that placement-stage est already
nails the critical ranking. **Implication for thesis scope (honest):** the method's value is CONCENTRATED in
congestion-dominated, many-macro designs; for the common low-congestion case the divergence trigger correctly
says "est suffices, skip route-awareness". This is a coherent SCOPED contribution — but it makes a **2nd
heavily-macro-congested design** the load-bearing experiment (codex Issue 3): without it, +15% is ariane-specific.
Candidates by macro count: ariane136 (136 macros, sibling — easy but not independent), mempool_group / bp_multi /
bp_quad (many macros, independent — heavier). bp_be (12 macros) was NOT enough to enter the high-divergence regime.

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
- **★ WHICH agreement metric? Spearman vs Jaccard DISAGREE on aes (GOAL #5/#8).** aes: Spearman 0.946
  (HIGH, like bp_fe) but top-3k Jaccard 0.639 (INTERMEDIATE). R18 says aes has ~0 timing headroom
  (detour↔slack ρ≈0) → Spearman (high→predicts ~0) is the BETTER gain-predictor here; global top-K
  Jaccard over-counts divergence on non-critical nets. **Hypothesis: the gain-predictive divergence is
  rank-correlation OR divergence RESTRICTED TO CRITICAL-PATH nets, not global set-overlap.** A net can be
  routed-vs-est divergent yet off the critical path → contributes to Jaccard but not to TNS gain. This
  refines the law: gain ∝ (1 − agreement_on_timing-bottleneck-nets). **TEST: measure aes route-aware gain
  (cheap — std-cell, 0-DRC routes); if ~0 despite Jaccard 0.64, it confirms Spearman/critical-restricted
  divergence is the right trigger and falsifies naive global-Jaccard.** aes CSVs exist
  (`backend_aes/aes_{est,base}_netslack.csv`).

## 5. Status
- Divergence numbers: FINAL (from pass-1 CSVs, design-independent of pending DR).
- bp_fe negative control at GR: CONFIRMS the law (fairest ≥ union ≥ routed on low-divergence design).
- Pending: bp_fe DR+coupling SIGNOFF numbers (does the GR ordering hold at signoff? — ariane's did).
  Once in, write R35 and update memory with the law as a central pillar.
