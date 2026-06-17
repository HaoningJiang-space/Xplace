# TERM-2 prototype v0 result + diagnosis (route-force congestion lever HURTS — and WHY)

## Result (ariane, oracle routed criticality, same back-end; route_weight=1.0)
| arm | post-route TNS | wirecap_fF | HPWL |
|---|---|---|---|
| nw (net-weight only, the +20% positive) | **−2401** | 542112 | 2.446E7 |
| rf0 (+ uniform route force, α=0) | −2759 | 599658 | 2.727E7 |
| rf1 (+ timing-weighted route force, α=1) | −2875 | 609744 | 2.756E7 |
| rf2 (α=2) | (running) | | |

Adding the route force HURT post-route TNS (−2401→−2759), with HPWL **+12%** and wirecap **+10%**.
Timing-weighting it (rf1) hurt MORE. `[TERM-2]` engagement confirmed (α=1, 40576/152343 crit cells).

## Diagnosis 1 — v0 is NOT actually TERM-2 (the first-principles error)
MATH.md TERM-2 = `Σ_b π_b ∂ρ_b/∂x`, with **π_b a per-BIN price** (criticality of nets routing
through bin b), applied to push *all* cells out of high-π_b bins. **v0 instead scaled the force
PER-NODE by the node's OWN criticality** — i.e. it pushed *critical cells themselves* harder toward
low congestion. That moves a critical cell into whitespace, away from its net neighbors → **lengthens
the critical net's own wire** → worse wire delay. This is the wrong sign of mechanism (it is closer
to a per-node version of the R15 mistake than to TERM-2). v0's negative does NOT falsify TERM-2; it
falsifies a per-node misimplementation. **TERM-2 must be per-BIN** (price on the corridor, not the cell).

## Diagnosis 2 — even UNIFORM route force hurts on ariane (effect-size, R18)
rf0 (α=0, the stock Xplace routability force) already hurt (−2401→−2759) at route_weight=1.0. The
generic congestion-spreading lever trades wirelength for congestion: it spread cells (HPWL +12%) to
relieve GR congestion, but on ariane the **detour it relieves is only ~4% of TNS (R18)** while the
HPWL it adds drives the dominant wire+cell delay → net loss. So a congestion lever can only help if
it relieves congestion **without** globally inflating WL — i.e. it must be **surgical** (critical
corridors only), and even then the ceiling is small on ariane.

## The corrected mechanism (v1 — the real TERM-2)
Inject the criticality price into the congestion POTENTIAL, not per-node:
```
input_mat_timing[b] = input_mat[b] · crit_map_norm[b]     # concentrate the congestion potential
route_gradmat = FFT-force(input_mat_timing)               # force CONCENTRATED on critical corridors
```
with `crit_map[b]` = per-bin aggregate criticality of nets routing through b (criticality-weighted
RUDY/demand splat on the GR grid). Key difference from v0/rf0:
- It does **not** apply a uniform spreading force everywhere (which inflates WL globally, rf0's harm).
- It pushes **non-critical aggressors** out of **critical** bins (clears the corridor) while leaving
  slack regions to pack — ESSENCE.md §5, the actual essence.
- Use a **concentrating** weight (crit_map multiplier, ~0 off critical corridors), NOT `(1+α·crit)`
  which would inherit rf0's harmful uniform spread.

## Honest gate
Even v1 is gated by R18: if the placement-controllable critical-corridor detour is ~4% of TNS, the
surgical force's ceiling is small and may not beat nw (−2401). v1 is the faithful test of TERM-2;
if it also fails to beat nw, the conclusion is firm: **on ariane the congestion lever cannot add to
the net-weighting positive** → net-weighting (+20%) is the headline, TERM-2 is the rigorous negative
companion (with this per-bin-vs-per-node + effect-size analysis as the contribution). To pursue a
POSITIVE TERM-2 (#12 SOTA), v1 must be tested on a design where critical-corridor detour is a LARGE
TNS fraction (the substrate search remains open).

## ★ CRITICAL HONESTY (user's objection, 2026-06-17): the +20% is an ORACLE, not a method
The +20% "positive" feeds ROUTED criticality (obtained by routing the design FIRST) back into
placement. At real placement time you have NOT routed yet → **this is circular / future-peeking,
NOT deployable.** Worse, it is not even a self-consistent oracle: the routed criticality came from
a REFERENCE placement P0's route, but it produced a DIFFERENT placement P1 whose route (and true
criticality) differs — a moving-target/fixed-point gap.

What the oracle study legitimately establishes (and ONLY this):
- The PRIZE is real: routed criticality carries placement-actionable info that pre-route estimation
  misses (R10 Jaccard 0.003), worth ~+20% post-route TNS. It justifies building a predictor.
- It does NOT establish a method. There is currently **NO deployable positive result.**

The only honest paths to a real positive (no routing-first cheat):
- (A) iterate place→route→re-weight→re-place to a fixed point (cheap routing in the loop, self-consistent);
- (B) predict routed criticality from pre-route features (no routing at deploy).
The differentiable unification (UNIFICATION.md) = (A)+(B) elegantly: a DIFFERENTIABLE router inside
the GP loop supplies routed criticality online & cheaply (≈ the fixed point) and is differentiable
(joint ∂Ψ/∂x), removing the "route-first" circularity. The oracle +20% is its CEILING/target, nothing more.
