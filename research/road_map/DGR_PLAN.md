# Position-differentiable routing layer in Xplace (borrow DGR's overflow model, fix the break)

## The exact differentiable break (confirmed from DGR source)
```
position → [two_pin_routing (util.py:163): DISCRETE int coords → candidate edge sets] → demand(p) → overflow_cost(demand)   [model.py:308]
            ^^^^^^^^^^^^^^^^^^^^ non-differentiable (∂pool/∂pos = 0) ^^^^^^^^^^^^^^^^^^^^   ^^^^^ differentiable in p only ^^^^^
```
DGR's `objective_function` is smooth in `p` (pattern probs) via demand; but `edge_length`,
`via_count`, `wire_length_count`, and the GCell each segment occupies are STATIC, baked from discrete
pin positions. So DGR gives ∂cost/∂p (fixed pins), not ∂cost/∂position. Replacing GGR with DGR is a
pure loss (CUGR2 dependency + inner 2000-iter pattern opt + still no position gradient).

## What to build (the contribution): soft segment rasterization
Make each candidate pattern's per-GCell demand a CONTINUOUS function of pin positions:
- A candidate pattern = a few H/V segments with turning points = functions of (driver, sink) positions.
- Replace the hard "segment crosses GCell g" indicator with a SOFT occupancy: bilinear/sigmoid splat
  of each segment's extent onto GCells (exactly eDensity's bin-splat operator, reused). Then
  `demand_g(x, p) = Σ_patterns p_pattern · soft_occupancy_g(segments(x))` is smooth in x AND p.
- Feed into DGR's smooth `overflow_cost(demand)` + expected `wire_length = Σ p·len(x)`,
  `via = Σ p·via`. Now ∂overflow/∂x, ∂wirelength/∂x, ∂via/∂x all flow (autograd).
- Run on XPLACE's GCell grid + net/pin tensors (NOT CUGR2). Lightweight: 2-pin decomposition of
  nets (FLUTE tree, already in Xplace via flute_cpp), L/Z candidates per arc, a few inner steps on p
  (or closed-form softmax-min over candidates).

## How its outputs enter placement (gated, lever-correct)
1. **Timing (primary, the validated path):** expected routed length/via per net → per-net wire RC →
   feed GPUTimer as the criticality RANKING source (R12/R19 helps), NOT as a magnitude pull multiplier
   (R15 hurts). The differentiable version gives ∂(routed-criticality)/∂x at the CURRENT position →
   kills the fixpoint's moving-target oscillation (R19 k3/k4). Reuse the `set_net_rc_mult` hook.
2. **Congestion (secondary, gated):** ∂overflow/∂x is a true congestion gradient — but TERM-2 had ~0
   headroom on ariane (4% detour); only worth it on congestion-limited designs.

## Strategic gating (be honest — from R21/R22)
Route-awareness payoff ∝ est-vs-routed criticality DIVERGENCE: big on ariane (0.24), ~0 on bp_fe
(0.94). So this differentiable layer pays off in the HIGH-divergence (fixed-macro structural
congestion) regime. Build priority is AFTER confirming route-awareness robustly helps (the selective/
normalized-blend method, R23). The layer's unique value even at fixed payoff: online (no cheat) +
no staleness (no oscillation) + true ∂T/∂x.

## Build order
1. (cheap, now) Fix R23: normalized-criticality selective blend; multi-design robustness.
2. (medium) Port pin2pin path-based actuation into Xplace (stronger force; Efficient-TDP strength).
3. (large) This differentiable routing layer (soft segment rasterization) — the methodological novelty
   and the oscillation-free online route-aware gradient. Validate on high-divergence designs first.
