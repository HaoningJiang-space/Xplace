# Minimal differentiable TERM-2 prototype: timing-weighted congestion force in Xplace

Goal: implement the smallest faithful realization of MATH.md **TERM 2**
`Σ_b π_b ∂ρ_b/∂x` (timing-weighted congestion price), validate it beats `--timing_opt` on
post-route TNS on ariane, then (later) upgrade the smooth congestion surrogate RUDY→DGR.

## The mechanism (ESSENCE.md §5, made precise against the code)
Xplace's route force already gives `∂ρ_b/∂x` numerically: `get_route_force` (src/core/route_force.py)
builds a per-bin congestion gradient map `route_gradmat[b]` from the GGR demand/cap maps, and the
`routeforce.route_grad` / `filler_route_grad` CUDA kernels turn it into a per-node force
(`mov_route_grad`, `mov_congest_grad`) that **pushes cells out of congested bins**. That force is
**timing-blind** — it treats every congested bin equally (π_b ≡ const). TERM 2 says the price must be
**criticality-weighted**:
```
route_gradmat_timing[b] = route_gradmat[b] · (1 + α · crit_map_norm[b])
π_b ∝ (1 + α·crit_map[b])   ← high where timing-critical nets route, ~1 elsewhere
```
Effect: the spreading/repulsion force is **amplified in bins carrying critical nets** → non-critical
("aggressor") cells are pushed out of critical corridors first → critical nets route straighter
(less detour) → less critical-arc wire delay. Slack regions keep their weak force and pack. This is
the right lever (clear corridors) NOT the R15 lever (pull critical pins into the corridor).

## Per-bin criticality map crit_map[b]
Source of per-net criticality `c_n ≥ 0`:
- **oracle arm (first validation):** from `--oracle_timing_file` netslack (same source as the +20%
  arms result) → `c_n = max(0, -slack_n)/|WNS|`.
- **online arm (deployable):** aggregate `data.gputimer.timing_pin_weight` (per-pin) to per-net
  (max over the net's pins).
Splat onto GR bins (criticality-weighted RUDY): for each net n, add `c_n` to every bin its bounding
box covers (its routing corridor), accumulate, then normalize `crit_map_norm = crit_map/max`. This is
cheap, differentiable-free (a per-iteration weight, exactly like `timing_pin_weight`), and reuses the
bin geometry already in `route_force` (`routeforce.gcell_steps()`, `num_bin_x/у`).

## Integration points (minimal, guarded by a new flag `--timing_route_weight α`, default 0)
1. **param_scheduler:** add `ps.timing_route_weight = args.timing_route_weight`,
   `ps.net_criticality = None` (per-net tensor, set each iter when timing is on).
2. **calculator.py:** when criticality is available (oracle file or gputimer), compute/refresh
   `ps.net_criticality`. No change to the gradient-sum lines — modulation happens inside the force.
3. **route_force.py `get_route_force`:** after `route_gradmat` is obtained and before
   `conn_route_force`/`cell_congestion_force` consume it, if `ps.timing_route_weight>0` and
   `ps.net_criticality is not None`: build `crit_map` (bbox splat), then
   `route_gradmat = route_gradmat * (1 + ps.timing_route_weight * crit_map_norm)`. Everything
   downstream is unchanged → both the conn-route force and the cell-congestion force become
   timing-weighted.
4. **main.py:** add `--timing_route_weight` flag.

This requires `--use_route_force True` (so the route force engine runs) + a criticality source. No
C++ rebuild (pure Python; reuses existing CUDA kernels).

## Decisive test (4-arm, ariane, same back-end as the +20% arms)
| arm | flags |
|---|---|
| plain | (none) |
| standard timing | `--timing_opt` (or oracle net-weight, the +20% winner) |
| uniform route-force | `--use_route_force` (α=0) |
| **timing-weighted route-force (this)** | `--use_route_force --timing_route_weight α` (oracle crit) |
Prediction (ESSENCE.md §6): only the timing-weighted route-force reduces critical-arc DETOUR without
adding corridor congestion → best post-route TNS at iso-routed-WL. If it does NOT beat standard
timing on ariane (where the +20% headroom exists), the controllable-detour is too small and we fall
back to the net-weighting positive (R12/arms) as the headline, with this as the negative companion.

## Why this is the differentiable-unification's minimal core
This IS `∂Ψ/∂x`'s TERM 2 (UNIFICATION.md) with the routing demand modeled by RUDY (the smooth
congestion surrogate of MATH.md §4a) instead of DGR. Validating it here de-risks the full
unification: if RUDY-based TERM 2 helps, swapping in DGR's differentiable router (better ρ, real
paths) is a strict upgrade of the same gradient; if RUDY-based TERM 2 does not help, DGR will not
rescue the effect-size, and we learn that cheaply.
