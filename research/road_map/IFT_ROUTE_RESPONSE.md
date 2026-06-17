# The route-response cross-term: implicit differentiation (corrects the envelope error)

## The error (in APPROACH_A.md and BIDIRECTIONAL.md)
We claimed the envelope theorem lets us treat r*(x) as fixed: ∂T/∂x ≈ direct partial (κ·∂HPWL/∂x).
WRONG. Envelope kills ∂R/∂r·dr*/dx only when differentiating R's OWN optimum (∂R/∂r=0 at r*).
Timing T ≠ routing cost R, so:
```
r*(x) = argmin_r R(x,r)          (routing solves the congestion/wirelength objective)
dT/dx = ∂T/∂x|_r + (∂T/∂r)·dr*/dx     <- the 2nd term is NONZERO (∂T/∂r ≠ 0) and was DROPPED
```
The dropped (∂T/∂r)·(dr*/dx) = the ROUTE-RESPONSE cross-term: how moving a cell changes the routing
solution, hence routed length/delay on critical arcs. The frozen-criticality method (force = κ·∂HPWL/∂x)
is route-blind in its GRADIENT (κ fixes the ranking, but ∂HPWL/∂x ignores route response) → this
cross-term is exactly the headroom it leaves on the table (beyond the empirical +8%).

## ① Implicit differentiation of the routing fixed-point (exact, cheap, the gold standard)
Treat r*(x) as an optimization layer; from stationarity ∂R/∂r|_{r*}=0, IFT gives:
```
dr*/dx = −(∂²R/∂r²)⁻¹ (∂²R/∂r∂x)
dT/dx  = ∂T/∂x|_r − (∂T/∂r)(∂²R/∂r²)⁻¹(∂²R/∂r∂x)      (exact route-aware timing gradient)
```
**Cheapness (the key):** ∂T/∂r is SPARSE — nonzero only on the few-hundred critical arcs (κ's
support). So no Hessian inverse: solve ONE small linear system (∂²R/∂r²)ᵀ z = (∂T/∂r)ᵀ by conjugate
gradient (Hessian-vector products only, OptNet/DEQ style), then dT/dx += −z·(∂²R/∂r∂x). Effective
dimension = #critical arcs, well within a GP single-step budget. More accurate than the envelope
(adds the cross-term), cheaper than unrolled co-descent (no unroll, no staleness, no explicit p).
**Smooth R for a clean Hessian:** reuse eDensity's Poisson/diffusion potential as the congestion
field R (or a convex Beckmann flow), so ∂²R/∂r² is well-conditioned.
**Bidirectional naturally:** dr*/dx lets placement see the routing response; κ lets routing see timing.

## ② Learned differentiable route-response surrogate (amortize ①, deployable, the P-claim)
Amortize ①'s gradient into a neural surrogate Δ̂(x): placement features → routed length/criticality,
natively differentiable. Online = one forward pass, no inner solve, no staleness. Train by GRADIENT
MATCHING to ①'s implicit gradient (fit the route-response DIRECTION, not just the value) + value
regression to real routes. This is the thesis's unverified P-claim; it differentiates from
C3PO/Xplace-Timing (both estimated, no route-response).

## ③ Explicit co-descent (x,p) — now demoted to "brute force"
The earlier BIDIRECTIONAL.md co-descent (explicit p, soft-raster, alternating, unroll-approx, big
variable, stability tuning) captures the cross-term but via unrolling. ① gets in one linear solve
what ③'s unroll approximates. Keep ③ only as the fallback if IFT is impractical.

## Unified picture (the "best")
```
① IFT  ──(exact route-response gradient = truth/upper bound)
        │ gradient-matching training signal
② Δ̂(x) ──(amortized differentiable forward, online-deployable)
```
κ (union criticality, R23) is always the sparse ∂T/∂delay weight; gated by divergence (R22). The
criticality-source story is unchanged — but now the source acts on x BIDIRECTIONALLY and EXACTLY
through the route-response cross-term, not just the route-blind ∂HPWL/∂x.

## Build order
0. (running) frozen union method multi-design (R23) — establishes κ-source value (the +8%).
1. ① IFT route-response on a SMOOTH R (eDensity-potential congestion), critical-arc-sparse CG —
   measure the EXTRA gain over frozen (the cross-term's worth). This is the theoretically-correct method.
2. ② surrogate Δ̂(x) trained by gradient-matching to ① — the deployable, novel, C3PO-differentiating form.
