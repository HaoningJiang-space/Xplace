# GOAL — living objective (adaptively updated)

Last updated: 2026-06-17 (pm). Rewritten as milestones complete; the single place to see
"what we are doing right now and why." History lives in git.

## North star (stable)
Build a **better GLOBAL PLACER**: close **post-route** WNS/TNS that a congestion-blind
timing-driven placer cannot, via a **fidelity-preserving route-aware timing model**. Must be
**non-incremental**, a genuine methodological contribution, and **stop only at STRONG SOTA**
(beat C3PO / Xplace-Timing on post-route timing at iso-congestion). Target DAC 2027.

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
    WNS/TNS at iso-congestion, multi-design. **不失真** (FIDELITY D1–D9) throughout.

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

## Current objective (ADAPTIVE — live target)
**(running) TERM-2 prototype on ariane:** does a timing-weighted congestion (route) force added on
top of the +20% net-weighting further improve post-route TNS, and is the timing-weighting (vs
uniform) the cause? 4-arm {nw | +uniform-rf | +timing-rf α=1 | α=2}. Decision rule in PROTOTYPE.md.

Then, toward STRONG SOTA (the only stop condition, #12):
- [ ] **Deployable predictor of routed criticality** (remove the oracle): the differentiable
      unification (UNIFICATION.md) — online differentiable routing supplies routed criticality /
      π_b to the placement gradient. This is the #11 differentiable engine and the non-incremental
      core. Recover a large fraction of the +20% WITHOUT the oracle.
- [ ] **2nd + 3rd fixed-macro / congested designs** (multi-case, #3) — confirm the headroom generalizes.
- [ ] **SOTA comparison vs C3PO / Xplace-Timing** at iso-congestion, WNS/TNS/Fmax, post-route (#12).
- [ ] **codex adversarial review** of the predictor + the SOTA comparison fairness (#2).

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
