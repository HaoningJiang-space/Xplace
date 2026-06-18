# GOAL — living objective (adaptively updated)

Last updated: 2026-06-17 (pm). Rewritten as milestones complete; the single place to see
"what we are doing right now and why." History lives in git.

## North star (stable)
Build a **better GLOBAL PLACER**: close **post-route** WNS/TNS that a congestion-blind
timing-driven placer cannot, via a **fidelity-preserving route-aware timing model**. Must be
**non-incremental**, a genuine methodological contribution, and **stop only at STRONG SOTA**
(beat C3PO / Xplace-Timing on post-route timing at iso-congestion). **Target DAC 2027 — ~5 months
out (deadline ~Nov 2026). DO NOT RUSH: understand the mechanism deeply before claiming/coding;
depth beats speed.** A wrong-but-fast result wastes more than a slow-but-correct one.

## Process invariants (the standing /goal — always on, updated 2026-06-17)
1. **Write insight + results to md, multi-faceted** (this file + RESULTS/MATH/ESSENCE/UNIFICATION…).
2. **Let codex adversarially review** code + methodology from first principles, often, before trusting.
3. **Multi-case testing** — never conclude from one design/seed.
4. **There is always a better method** — do not settle on the first that works.
5. **Finer-grained thinking** — decompose to the mechanism, not the aggregate.
6. **Check related work + iterate** — has it been done? what is strictly better? converge by iteration.
7. **Heavy git management** — commit + push to `HaoningJiang-space/Xplace` (remote `hj`) constantly.
8. **First principles** — derive the gradient/mechanism, don't pattern-match.
9. **Form a coherent framework / system** — not a bag of tricks.
9b. **Abstract to high-level problems + read other fields** for borrowable solutions.
10. **Be sensitive to data structures** (PlaceData tensors, GR grid, pin/net maps, criticality).
11. **★ Think hard about differentiable techniques** — the unification of differentiable placement +
    differentiable routing (UNIFICATION.md), smooth congestion→detour surrogates, implicit/unrolled
    gradients, Gumbel/soft-assignment. This is the methodological engine.
12. **★ Stop only at STRONG SOTA** — a confirmed positive is necessary, not sufficient. The bar is
    beating the SOTA route-aware timing placer (C3PO ASPDAC'26 / Xplace-Timing) on post-route
    WNS/TNS at iso-congestion, multi-design. **不失真** (FIDELITY D1–D9) throughout. Until then,
    keep iterating — never conclude early.
13. **★ Depth over speed (DAC 2027, ~5 months).** 弄懂了再说话 — fully understand the mechanism
    (derive it, codex-verify it, check the literature) BEFORE coding or claiming. There is time;
    spend it on correctness and understanding, not on premature breadth.

## Current state (the live picture)
**POSITIVE result CONFIRMED (multi-seed):** routed-criticality net-weighting beats estimated-
criticality net-weighting on ariane post-route TNS by **+20–27% across 3 seeds** (routed −2255/
−2401/−2425 vs est −3011/−3100/−3150), and beats the real `--timing_opt` (−2600) by ~8%. The value
is the **criticality RANKING** (which nets are routed-critical), NOT the detour RC magnitude (R15
falsified that, monotonically). Force-matched (same top-K, same scale) → clean isolation.

**Effect-size map (measured):** ariane (fixed-macro) = the substrate with real headroom; aes
(std-cell, NanGate45) detour changes arc delay but NOT slack (ρ≈0) → no headroom; ASAP7 synfree =
broken. So the thesis substrate = fixed-macro / structurally-congested designs.

**The math (MATH.md):** true ∂TNS/∂x = TERM1 (timing-weighted WL pull, = net-weighting, the +20%) +
TERM2 (Σ_b π_b ∂ρ_b/∂x, timing-weighted congestion price — the missing cross-term). The positive so
far is TERM1 done right (routed criticality). TERM2 is being tested now.

## Current objective (ADAPTIVE — live target, 2026-06-18)
Current best method = **R23 normalized UNION criticality** (ariane −2390.6, bp_fe −62045) under the
**frozen auto-cal rule** (`--timing_force_frac=0.1`, R25/R26). Theory upgrade = **R27**: frozen
criticality drops the route-response cross term `(∂T/∂r)(dr*/dx)`; envelope theorem fails (T≠R);
restore via IFT (IMPLICIT_DIFF_TIMING.md). codex architecture review (2026-06-18) redirect:

**Sequenced plan (codex-converged — arc-level FIRST, fidelity gate BEFORE IFT):**
- [ ] **Arc-level union criticality + arc-corridor detour proxy** (NOT net-level — net aggregation is
      a "false-negative machine", erases signal). Upgrade `detour_timing.py` to per-arc (driver→sink):
      `len_a=‖u−v‖₁`, corridor congestion `ρ_a`, per-arc `κ_a`. (CRITICALITY_GRANULARITY.md §3.)
- [ ] **★ FIDELITY GATE (the make-or-break, codex risk #4):** measure cosine / descent agreement of
      the detour-gradient direction vs **finite-difference REAL reroute+STA** on critical arcs. If the
      direction disagrees, the proxy differentiates the WRONG simulator → fix the proxy before IFT.
- [ ] **IFT** (IMPLICIT_DIFF_TIMING.md) ONLY after the gate passes; else prefer the simpler
      "arc-level union + cheap detour force + periodic routed-STA refresh" (codex 90% architecture),
      or the **perturbation-response distillation** alternative (codex #5).
- [ ] **Multi-design under the FROZEN rule** (#3): ariane + bp_fe + a valid 3rd (swerv dropped, R26)
      — union must beat est design-invariantly.
- [ ] **STRONG SOTA (#12):** vs C3PO / Xplace-Timing / Efficient-TDP, iso-congestion, post-route, ≥3 designs.
- [ ] **codex review** the arc-level term + the SOTA fairness (#2).

Run substrate: moe-server (`ssh -p 10548 ziheng@10.16.52.172`, hpclab03), **GPU 1 only** (GPU 0 = PPoPP).

## Done (rolling, newest first)
- 2026-06-17 **Multi-seed CONFIRMED** routed-criticality net-weight +20–27% over est across 3 seeds (ariane).
- 2026-06-17 **TERM-2 prototype v0 implemented** (per-node timing-weighted congestion force; cache-mutation bug fixed) + PROTOTYPE.md; test running.
- 2026-06-17 **UNIFICATION.md** — differentiable placement + routing unify into one potential Ψ(x,r) over the shared demand field; ∂Ψ/∂x = TERM2, ∂Ψ/∂r = DGR; bridge = differentiable pin→GCell splat.
- 2026-06-17 **MATH.md / ESSENCE.md** — TERM1/TERM2 decomposition; R15 wrong-Jacobian diagnosis; essence = timing-weighted congestion allocation (clear critical corridors, don't pull).
- 2026-06-17 R18 effect-size: detour ~4% of TNS on ariane (gating); aes detour↔slack ρ≈0.
- 2026-06-17 R15/R16: route-aware RC-correction HURTS monotonically (lever mismatch) — falsified the magnitude route.
- 2026-06-17 R13/R14: GPUTimer unblocked, path-based `--timing_opt` works (libs-list fix, wire_R 0.0036).
- 2026-06-17 R11/R12: routed-criticality oracle ~20% post-route headroom on ariane (force-matched).
- 2026-06-17 Substrate + bridge verified (Xplace place → OpenROAD route round-trip).

## Open gates / risks (honest blockers)
- **Oracle → predictor** is the make-or-break: the +20% uses true routed criticality. Without a
  predictor that recovers it pre-route, there is no deployable method. The unification is the bet.
- **Strong SOTA (#12) not yet attempted** — confirmed positive ≠ SOTA. Must beat C3PO/Xplace-Timing.
- TERM-2 may add little beyond TERM1 (if controllable detour is small) — being measured now.
- Physical risk (D5): placement-controllable parasitic delta dominated by cell/CTS/buffering.

## ★ CURRENT STATE (2026-06-18, R33–R36 — SIGNOFF-fidelity + production SOTA on 1 design, supersedes R29)
**The ariane positive is now SIGNOFF-fidelity, 0-DRC, and beats BOTH baselines:**
- **R33:** route-aware union criticality beats the academic fair-est baseline by **+15.3%** post-route
  coupling TNS at detailed-route + OpenRCX SIGNOFF fidelity (0 DRC, `--use_cell_inflate`). union −823.7,
  routed −832.0, fair-est −972.5.
- **R36 (NEW — clean #12 vs production):** union beats Xplace's own production **`--timing_opt` by +15.0%**
  (−823.7 vs −968.9), BOTH 0-DRC at signoff. R34's "confound" RESOLVED by force-matching `--timing_opt` down
  (its HPWL saturates ~2.64e7, 6% denser than routability-grade, can't be loosened to union's density). KEY
  ISOLATION: the two estimated-criticality methods TIE (fair-est −972.5 ≈ `--timing_opt` −968.9, <0.4%)
  regardless of actuation → **the contribution is the criticality SOURCE, not the force/actuation**.
- **R35 (NEGATIVE CONTROL):** bp_fe (low-divergence, Spearman 0.97) → all 3 arms tied within 0.3% at signoff
  → route-awareness ~0 gain, confirming the DIVERGENCE LAW.
**Three framework pillars (this session, committed):**
- **DEPLOYABILITY.md:** the "+15%" is a deployable **2-pass place→route→re-place** flow (criticality from an
  independent base route, no oracle/leak) — downgrades the oracle→predictor gate from blocker to efficiency-opt.
- **DIVERGENCE_LAW.md:** gain ∝ (1 − agreement(est,routed crit)), measurable oracle-free from pass-1 CSVs
  (ariane Jaccard 0.24→+15%, bp_fe 0.94→~0). Predictive law + adaptive trigger, not "always add routing".
- **SOTA_COMPARISON_DESIGN.md:** Path A (oracle net-weight) ⊥ Path B (`--timing_opt`) disjoint but same
  consumer → R33/R36 cleanly isolate criticality source from actuation.
**Honest remaining path to STRONG SOTA (#12), NOT rushed (#13):**
1. **★ 2nd HIGH-DIVERGENCE design** (the main gap): ariane is the only high-div design; bp_fe/aes are low-div
   negative controls. Candidate = bp_be_top (fresh ORFS, macro-heavy). Show +15% generalizes.
2. **aes gain measurement** to disambiguate the law's metric (Spearman vs Jaccard disagree on aes).
3. vs Efficient-TDP (pin2pin) / C3PO.
4. IFT route-response cross-term (IMPLICIT_DIFF_TIMING.md) — theoretically-correct EXTRA gain (parked: needs
   high-detour substrate; the RANKING lever, not force, is what works).
**Honest distance to strong SOTA:** a CLEAN signoff-fidelity, 0-DRC, +15%-vs-production-`--timing_opt`
positive on 1 design, with a confirming negative control and a predictive law. NOT yet multi-design (the 2nd
high-divergence design is the gating experiment). This is materially stronger than the prior GR-fidelity +5.6%.
