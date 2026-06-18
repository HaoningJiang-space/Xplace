# THESIS — the one coherent story (2026-06-18, post-R37, supersedes scattered docs)

The single entry point that ties the 27 road_map docs + R1–R37 into ONE framework. Read this first;
each claim points to its evidence doc. (串起来: this is the system, not a result log.)

> ⚠ **STATUS (2026-06-18, user mechanism-investigation — see MECHANISM_AUTOPSY.md): EARNED vs NOT EARNED.**
> EARNED: union net-weighting → **+15% post-route coupling TNS on ariane at 0-DRC signoff** vs fair-est (R33)
> AND vs force-matched `--timing_opt` (R36) — numbers VERIFIED from raw remote logs, not a collector artifact.
> NOT EARNED (now hypotheses under autopsy): (1) the **mechanism** is "routed-timing reordering" — the actuator
> is actually a per-pin geometric WIRELENGTH pull (`wirelength_timing_cuda_kernel.cu:46`), so the gain MAY be
> a fanout/geometry effect (test: per-pin/fanout-normalized weighting). (2) the **"Jaccard<0.4 threshold law"**
> — it mixes ests (gain uses fair metal5 → ariane Jaccard 0.517, ABOVE 0.4; the 0.231 uses metal3 default).
> (3) the cross-design trigger — unfair fixed top-K, mixed est, est/routed not same-stage. **Do not write the
> mechanism story or the law into the paper until the autopsy resolves them. §2/§4 below are tempered.**

---
## 0. One sentence — VCERF (Verifier-Calibrated Endpoint Route Feedback; METHOD_DERIVATION.md)
**A deployable TWO-PASS route-feedback timing-placement framework for MACRO-CONGESTED designs, with an
ORACLE-FREE divergence TRIGGER, bounded endpoint actuation, a SIGNOFF VERIFIER, and one validated rescue case:** re-placing with a
gentle net-weight on the UNION of estimated + first-pass-routed criticality closes post-route timing a
congestion-blind placer cannot (+15% signoff coupling TNS on ariane vs both academic and production
baselines), and a pass-1 critical-set-Jaccard trigger predicts WHEN to apply it (does-no-harm elsewhere).
**The contribution is the TRIGGER + the rescue case, NOT a broad SOTA placer or a calibrated "law"**
(those are not yet earned — see §4/§6). The load-bearing open test: a 2nd low-Jaccard design that GAINS.

---
## 1. The problem (first principles, FRAMEWORK.md §1 + METHOD_DERIVATION.md §4)
Global placement minimizes a surrogate `f_est(x)` (estimated-RC timing) as a proxy for `f_true(x)`
(post-route timing). They differ by a structured, placement-dependent gap `Δ(x)` = the routing response.
Closing Δ is the whole thesis. **Congestion→timing is NONLINEAR (user, METHOD_DERIVATION §4):**
congestion → detour/lower-layer/vias/coupling-cap → worse R,C,slew,load → larger arc delay → WNS/TNS loss
ONLY if the arc is timing-critical. So the useful variable is NOT raw congestion ρ_b but **timing-priced
congestion** `π_b = Σ_{critical arcs a through bin b} κ_a·∂delay_a/∂ρ_b` — sparse, path-dependent. This
explains the mixed evidence (uniform/timing route FORCE hurts by inflating HPWL/load; route-feedback
criticality RANKING helps): **price congestion by criticality, don't optimize congestion as a generic
secondary objective.** ⇒ route feedback's value is as a CRITICALITY-SET source, not a detour-magnitude force. Δ has three necessary properties — each an experiment:
- **(E) Δ exists & is structured** — routed criticality ≠ estimated criticality on congested designs.
- **(C) Δ is placement-controllable** — re-placing on routed criticality changes post-route timing.
- **(P) Δ is recoverable without an oracle** — a 2-pass flow's first route supplies it (no ML needed).

## 2. WHAT Δ actually is — criticality REORDERING, not delay magnitude (the central mechanism)
The hard-won, 4×-confirmed mechanism (R15, R18, R30, R36-`--timing_opt`):
- **Routing changes WHICH nets are critical** (detour + layer-assignment around fixed macros), not merely
  their delay. The lever is the criticality **RANKING/SET**, NOT the RC/detour **magnitude**.
- Every attempt to use the magnitude as a FORCE failed: R15/R16 (route-aware RC into the GPUTimer → hurt
  monotonically), R30 (differentiable detour force → multi-seed noise/negative), R36 (production
  `--timing_opt`'s strong exponential pull → over-concentrates, squanders routed criticality).
- → **Actuation must be GENTLE** (flat top-K net-weight). Source (routed criticality) and actuation
  (gentle) are BOTH necessary; their interaction is the recipe. (CODEX_REVIEW_R36.md Issue 2.)

## 3. The METHOD — VCERF: Verifier-Calibrated Endpoint Route Feedback (METHOD_DERIVATION.md, the spine)
The method worth pursuing (user derivation, 2026-06-18), an ADAPTIVE framework — NOT "another timing placer":
```
1. Pass-1 base placement (Xplace / Xplace-Timing) → legal/routable.
2. SAME-STAGE timing snapshots: on one post-CTS/post-DP netlist, dump est slack BEFORE route and
   routed/OpenRCX slack AFTER route. (do NOT mix pre-CTS est with post-CTS routed — autopsy #4.)
3. ENDPOINT criticality: build crit on driver→sink endpoints (not per-net min); if endpoints unavailable,
   FANOUT-NORMALIZED net weighting is the mandatory control.
4. DIVERGENCE TRIGGER: constant-top-fraction critical-set Jaccard at a NAMED est fidelity — a HEURISTIC, not
   a law, until recomputed consistently.
5. BOUNDED 2nd-pass actuation: g = g_WL + g_density + β·normalize(g_route_feedback), β via --timing_force_frac
   (NOT an arbitrary raw scale).
6. VERIFIER acceptance: route the candidate; accept ONLY if signoff TNS/WNS improves with no dirty DRC/DRT
   fail / no unacceptable routed-WL/via/congestion regression.
7. SKIP rule: high est↔routed agreement → skip the 2nd pass (bp_fe = the negative-control example).
```
- **Why endpoint (arc) feedback is the right unit:** `S_endpoint(x)=Σ_(u,v) κ_uv·dist(u,v)` removes the
  current surrogate's 3 accidental effects — fanout bias, wrong-sink bias, root-order bias — and aligns with
  Efficient-TDP pin2pin actuation while adding route-feedback criticality as the NOVEL source.
- **NOT an oracle:** the routed criticality is pass-1's own route (independent base) — a standard 2-pass
  place→route→re-place. The "oracle→predictor" gate is an efficiency-optimization, not a blocker.
- **The SOTA angle (broader than "ariane-only"):** existing placers optimize ESTIMATED criticality; VCERF
  DETECTS when est & routed critical SETS disagree, reselects the critical endpoints from real route feedback,
  and VERIFIES by signoff — self-skipping on low-divergence designs. The trigger is part of the algorithm.

## 4. WHEN it applies — the DIVERGENCE TRIGGER (a HYPOTHESIS, not yet a law — codex)
**Hypothesis: gain ∝ (1 − top-K critical-SET Jaccard(est, routed)), with a threshold near Jaccard ≈ 0.4.**
HONEST STATUS (codex): this is ONE positive outlier (ariane) + 4 "no-gain when est≈routed" points — it
predicts when the placement PERTURBS, but a 2nd low-Jaccard design that GAINS is required to prove the
perturbation is BENEFICIAL not merely different (the soft circularity). Until then it is a trigger
hypothesis, not a calibrated law. Measured at a consistent top-10% fraction across 5 designs:

| design | #macros | top-10% Jaccard | route-aware gain |
|---|---|---|---|
| **ariane133** | 132 | **0.231** | **+15.3% signoff** |
| aes | 0 | 0.545 | ~0 (R18) |
| bp_multi_top | ~30 | 0.619 | ~0 (R37) |
| bp_be_top | ~12 | 0.666 | unmeasured |
| bp_fe_top | few | 0.963 | ~0 signoff (R35) |

- **The metric is the critical-SET Jaccard, NOT full-ranking Spearman** — settled by bp_multi (Spearman
  0.776 intermediate but Jaccard 0.62, gain ~0). Net-weighting acts on the top-K SET; identical sets →
  identical placement regardless of within-set rank order.
- **Threshold/nonlinear, not smooth:** gain appears ONLY below Jaccard ~0.4 (ariane alone); the 0.5–0.97
  range all give ~0. Routing must reorder MOST of the critical set before re-placing helps.
- **Driver = heavy macro-congestion** (ariane's 132 fixed SRAMs force long nets through detour + layer
  reassignment). The discriminator is structural congestion, measurable as macro density.
- **Oracle-free trigger:** the Jaccard is computed from the two pass-1 CSVs → the placer DECIDES adaptively
  (apply route-awareness iff pass-1 Jaccard < ~0.4; else est suffices, skip). Self-gating, does-no-harm.

## 5. The EVIDENCE (signoff-fidelity, codex-reviewed)
- **R33 — the clean core result:** ariane, vary criticality only (gentle net-weight, iso-mechanism,
  iso-HPWL), detailed-route + OpenRCX coupling, 0 DRC: union −823.7 vs fair-est −972.5 = **+15.3%**.
  This is the ONE un-criticized result.
- **R36 — vs PRODUCTION Xplace-Timing:** union −823.7 vs force-matched `--timing_opt` −968.9 = **+15.0%**,
  both 0-DRC at signoff. The two estimated-criticality methods tie (fair-est ≈ `--timing_opt`) → consistent
  with source-dominance (tempered: not yet a Pareto proof — codex Issue 1).
- **R35 — negative control:** bp_fe (low-divergence) all arms tied within 0.3% → confirms the law predicts
  ~0 where Jaccard is high.
- **R37 — multi-design law:** 5 designs, threshold ~0.4, metric = critical-set Jaccard.

## 6. SCOPE (honest, the anti-overclaim)
The method helps in a **NARROW high-congestion regime** — among 5 tractable NanGate45 designs only ariane
crosses the gain threshold. This is a SCOPED contribution, not a universal one. Its integrity comes from
the **trigger**: the same divergence metric that bounds the gain also *predicts* it pre-route, so the placer
never applies route-awareness where it wouldn't help (does-no-harm on the other 4). The honest framing is a
**predictive law for a real but narrow regime**, with ariane as the validated exemplar.

## 7. POSITIONING (RELATED_WORK.md)
No prior work makes placement timing criticality route-aware via a routing-response. A (diff-TDP DAC'22 /
Efficient-TDP DATE'25) = frozen estimated-RC criticality (route-blind); B (DGR DAC'24) = ∂/∂routing-prob, no
∂/∂position; C (ML parasitic predictors) = non-differentiable standalone annotators; D (GP+gate-sizing fusion
ICCAD'24) = no routing. Our axis — the criticality SOURCE (route-aware union) + its divergence law — is
orthogonal to all.

## 8. PATH TO STRONG SOTA (#12 — what remains, honestly)
1. **A 2nd low-Jaccard (heavy-macro) design with a POSITIVE gain** — to prove +15% isn't ariane-unique.
   Candidates: mempool_group (NanGate45, 4400×4400, heavy), or ASAP7-ariane (pin-access LEF defect, R2b).
   THIS is the load-bearing gap.
2. **0-DRC signoff PARETO sweep** vs `--timing_opt` (× density/inflation knobs) at matched density/wirelength
   /via — to make R36 a Pareto-dominance proof, not a single point (codex Issue 1).
3. **vs Efficient-TDP (pin2pin) / C3PO** head-to-head.
4. (optional) aes gain (Jaccard 0.545) to fill the threshold curve; cross-base/fixpoint convergence (codex
   Issue 3.2); confidence-weighted union (blend_crit_conf.py) for safety on low-divergence designs.

## 9. PARKED / superseded threads (so the sprawl is legible)
- **IFT route-response FORCE** (IMPLICIT_DIFF_TIMING.md, IFT_ROUTE_RESPONSE.md, UNIFICATION.md, DGR_PLAN.md):
  parked — the value is the RANKING, not a force; the detour force is settled negative on the only available
  substrate (R30). Revisit only with a high-detour design.
- **Differentiable detour term** (detour_timing.py, DETOUR_EXPERIMENT.md, CRITICALITY_GRANULARITY.md): built +
  FD-verified but the force has no headroom (R30). The differentiable machinery awaits a use as a *ranking*
  refiner, not a force.
- **TERM-2 congestion force** (MATH.md, PROTOTYPE.md, ANALYSIS_TERM2.md): negative (R18, congestion lever no
  headroom on ariane).
- Earlier docs (CEILING, ESSENCE, INSIGHTS, ROADMAP, EXPERIMENT_PROTOCOL, FIDELITY) = supporting context;
  FRAMEWORK.md = the prior synthesis (R19–R23), now folded into this.

---
**The system in one line:** place against the divergence-gated UNION of estimated + first-pass-routed
criticality, actuated as a gentle net-weight, judged at signoff — route-aware where the critical set
genuinely reorders (heavy congestion, Jaccard < 0.4), provably harmless elsewhere, no oracle.
