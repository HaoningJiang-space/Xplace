# Can differentiable PLACEMENT and differentiable ROUTING be unified? (analysis)

## 1. The two differentiable systems
- **Placement (Xplace):** variable x = cell positions (continuous). Objective
  `P(x) = WL(x) + λ_D·D(x)` (WA-wirelength + eDensity density penalty), Nesterov on x. D(x) is a
  Poisson/FFT potential of the **cell-area demand field**.
- **Routing (DGR/PGR):** variable r = per-net path/pattern probabilities (continuous via
  Gumbel-softmax). Objective `R(r) = Σ_e c_e(d_e(r))`, gradient descent on r. PGR shows c_e = ∂Φ/∂d_e
  with Φ the **Rosenthal potential** of the congestion game; d_e = **routing (wire) demand** on edge e.
  Pin positions are FIXED inputs.

## 2. The coupling — they share ONE physical object: the demand field ρ
Routing demand depends on **both**: `d_e = d_e(x, r)` — x sets where each net's terminals are
(which GCells it spans), r sets which path carries the demand. And the crux:
> **eDensity's cell-area demand and DGR's routing(wire) demand are the SAME resource** — occupancy
> of the 2D fabric. Placement spreads area-demand; routing spreads wire-demand; both are congestion
> on ρ. They are two granularities of one field, optimized by two separate descents today.

This is exactly why sequential place→route is the "HPWL bug": placement allocates ρ **route-blind**
(it only sees its own D(x), not the routing congestion c_e(d_e(x,·))).

## 3. The unified objective (yes — one potential over (x, r))
```
Ψ(x, r) = WL(x) + λ_D·D(x) + λ_R · Σ_e ω_e · c_e( d_e(x, r) )
```
with ω_e = **timing-criticality weight** on edge e (the price/Pigouvian-tax weighted by how critical
the paths through e are — = π from MATH.md). Gradient flow on Ψ over **(x, r) jointly** is unified
differentiable place+route+timing. Two cross-terms fall out by autodiff:
```
∂Ψ/∂r = λ_R Σ_e ω_e c_e' ∂d_e/∂r        ← DGR's routing gradient (timing-weighted)
∂Ψ/∂x = ∂WL/∂x + λ_D ∂D/∂x + λ_R Σ_e ω_e c_e' (∂d_e/∂x)   ← the route-aware PLACEMENT gradient = MATH.md TERM 2
```
**So DGR is precisely the object that supplies the ∂(routing)/∂x that MATH.md's TERM 2 needs.**
Unification = compute both gradients on one autodiff graph and descend jointly.

## 4. The one missing bridge: differentiable pin → GCell assignment
DGR today takes FIXED pin GCells. To get ∂d_e/∂x we need x → d_e differentiable. The bridge: a
**soft pin-to-GCell assignment** s(x) (e.g. bilinear/softmax splat of a pin at position x onto
neighboring GCells, exactly like eDensity already splats cell area onto bins). Then
`d_e = Σ_pins s(x)·(path indicators from r)` is differentiable in x AND r. eDensity ALREADY does the
area-splat; reuse the same operator for wire-demand splat → the graph closes.

## 5. Two regimes — joint vs bilevel
- **Joint co-descent:** descend (x, r) together (alternate K_r routing steps per placement step).
  Cheap; a relaxation; may not reach the route-optimal-per-placement point; can oscillate (needs
  damping / a schedule, like the timing-mode EMA).
- **Bilevel (correct PnR semantics):** r*(x) = argmin_r Ψ(x,r) (route optimally for each placement),
  then min_x Ψ(x, r*(x)); ∂/∂x via implicit-function theorem or unrolling DGR's descent. This is the
  "placement sees the optimal routing response" — the principled route-aware placement. PGR's
  Nash/social-optimum equilibrium IS r*(x), so its fixed point gives a clean implicit gradient.

## 6. Timing = criticality-weighted congestion price on the SHARED field
ω_e = Σ_{crit paths through e} w_path. This **allocates the scarce clear-corridor resource to
critical paths** (keep their corridors low-d_e, push demand to slack regions) — the ESSENCE.md
mechanism, now as a weight on the unified routing potential. Joint descent then **places AND routes**
to keep critical corridors clear — the right lever (ESSENCE/MATH), not the R15 pull.

## 7. Is it good / novel? (honest)
- **Unifiable: YES, cleanly** — one potential Ψ(x,r) on the shared demand field, joint autodiff, with
  the soft pin→GCell splat as the only new operator. The cross-term ∂Ψ/∂x is the route-aware
  placement gradient; ∂Ψ/∂r is DGR. Timing is a criticality weight ω_e on the routing term.
- **Novel:** prior art is *sequential* (place → route) or *additive* (place + RUDY penalty, C3PO).
  A **single differentiable potential jointly over placement AND routing with a timing-weighted
  congestion price** (Rosenthal/Pigouvian, from PGR) is the unification neither side has. It is the
  principled cure for the "HPWL bug" (placement no longer route-blind: it descends the real routing
  potential).
- **Risks (the same gates, now sharpened):**
  - **(a) discreteness gap:** r (paths) and s(x) (pin→GCell) are relaxed; continuous optimum ≠
    discrete PnR. Must verify the relaxed gradient tracks real routed timing (FIDELITY D8).
  - **(b) effect size (R18):** still gated — if detour/wire-delay is ~4% of TNS (uncongested,
    fixed-macro), unification can't buy more than ~4%. Unification PAYS on congested / wire-dominated
    designs where ρ-allocation matters. Pick the design accordingly.
  - **(c) coupling stability + cost:** joint/bilevel descent of (x,r) at GP scale — needs the routing
    inner-loop cheap (DGR is GPU/fast → feasible, unlike OpenROAD GR) and damping.
  - **(d) engineering:** soft pin→GCell splat + sharing eDensity's bin operator + an alternating
    optimizer. Substantial but bounded; DGR + Xplace are both PyTorch.

## 8. Why this is the POSITIVE path
The positive result (R12: routed-criticality net-weighting beats standard timing-driven) says the
value is in the **routed** view. Unification makes the placement gradient SEE the routed view
**differentiably and online** (∂Ψ/∂x through DGR), instead of an offline oracle. That is the
deployable mechanism behind R12's oracle headroom — and it is a single, principled, novel
differentiable PnR-timing objective. The decisive test: does joint (x,r) descent on Ψ beat
sequential `--timing_opt`→route on post-route WNS/TNS, on a congested/wire-dominated design.
