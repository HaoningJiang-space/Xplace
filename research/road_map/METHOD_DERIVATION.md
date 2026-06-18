# METHOD DERIVATION — mechanism-first route-feedback timing placement

Date: 2026-06-18. Purpose: answer whether the current result is a code bug, a real method, or an
overstated explanation.

## 1. Verdict

The key ariane result is real, but the present explanation is too strong.

- **Not a signoff collector bug:** remote raw signoff shows ariane union `dr_coupling_tns=-823.71` vs
  fair-est `-972.47`, a **15.30%** TNS reduction; all final DRC counts are zero and `BACKEND_DR_DONE`
  appears in the backend logs.
- **Not yet a proven timing-gradient method:** the implemented actuator is a geometric pin-root
  weighted-average wirelength pull, not a post-route STA gradient.
- **Real contribution direction:** a verifier-calibrated, two-pass **route-feedback criticality selection**
  method for macro-congested placements. The route feedback should select and rank critical endpoints; the
  force must remain bounded and must be accepted by a real route/signoff verifier.

So the paper should not claim "we derive the true routed timing gradient" yet. It can claim a route-feedback
criticality mechanism, if the mechanism autopsy below passes.

## 2. What the code really optimizes

Oracle criticality enters in `src/run_placement_nesterov.py:452-514`:

1. read CSV `(net,worst_slack_ns)`;
2. convert slack to `net_crit=max(0,-slack)/max_neg`;
3. optionally collapse to top-K/top-fraction uniform weights;
4. broadcast to pins as `timing_pin_weight = scale * net_crit[pin_id2net_id]`;
5. attach a fake `data.gputimer` so `calculator.py:64-82` adds the timing-WL gradient.

The CUDA kernel `cpp_to_py/wirelength_timing_cuda/wirelength_timing_cuda_kernel.cu:46-124` then performs:

```text
for each net n:
  root = first pin in hyperedge list
  for each non-root pin p:
    add timing_pin_weight[p] * d WA_length(root,p) / dx
```

`net_weight` is passed but unused. The optimized surrogate is therefore approximately:

```text
S_broadcast(x) = sum_n sum_{p in pins(n)\root(n)} w_n * WA_distance(root(n), p)
```

This is useful but not equivalent to signoff TNS. It has three distortions:

- **fanout bias:** a high-fanout net receives more total force because every pin is weighted;
- **wrong endpoint bias:** non-critical sinks of a critical net are pulled too;
- **root-order bias:** the "driver" is whatever pin appears first, unless the hyperedge order happens to
  match driver semantics.

The recent code hooks are the right first autopsy controls:

- `--oracle_topfrac`: use a constant fraction instead of fixed `--oracle_topk 13000`;
- `--oracle_pin_weight_mode=fanout_norm`: divide by degree so each net has comparable total pull;
- `--timing_force_frac`: match the timing-gradient norm to a fixed fraction of the WL-gradient norm.

These controls should be used before adding any new model complexity.

## 3. Mathematical target

Let placement be `x`, routed state be `r*(x)`, and the true objective be positive setup violation:

```text
F(x) = sum_e phi(-slack_e(x, r*(x))),       phi(z)=max(0,z)
```

For an endpoint path, delay decomposes into cell delay and routed wire delay. For each timing arc `a`:

```text
d_a(x,r*(x)) = d_cell,a(x) + d_wire,a(x,r*(x))
```

The true first-order direction has two families of terms:

```text
dF/dx =
  sum_a kappa_a * d estimated_wire_length_a / dx
+ sum_a kappa_a * d route_response_a(r*(x)) / dx
+ cell/slew/load terms
```

The current oracle actuator only approximates the first family, and only after collapsing arc criticality to
a net-level scalar. The experiments also show the direct route-response magnitude force is weak or noisy on
ariane: RC-ratio injection, TERM-2 route force, and detour-force variants did not produce a robust gain.

Therefore the current evidence supports this principle:

> Route feedback is more valuable as a **criticality set/ranking source** than as a continuous detour-magnitude
> force on the current substrate.

## 4. Congestion vs timing

Congestion does cause timing problems, but only through a chain:

```text
congestion -> route detour / lower-layer assignment / more vias / coupling cap
           -> larger R,C and worse slew/load
           -> larger arc delay
           -> WNS/TNS loss only if the affected arc is timing-critical
```

So the useful variable is not raw congestion `rho_b`; it is **timing-priced congestion**:

```text
pi_b = sum_{critical arcs a through bin b} kappa_a * d delay_a / d congestion_b
```

Raw routability optimization treats every congested bin as important. Timing optimization should instead
clear bins with high `pi_b`: bins used by critical arcs whose delay is actually sensitive to routing. This
explains the current mixed evidence:

- uniform route force can hurt timing because it spreads cells globally, increasing HPWL and load even when
  it reduces congestion;
- a timing-weighted route force can still hurt if it pushes the critical cells themselves away from their
  neighbors instead of clearing non-critical aggressors from critical corridors;
- ariane's measured detour contribution is small, so route-magnitude forces have little headroom, while
  route-feedback criticality ranking still helps.

The paper should therefore say: congestion is a timing mechanism, but **timing-relevant congestion is sparse
and path-dependent**. The method should price congestion by criticality, not optimize congestion as a generic
secondary objective.

## 5. The method that is actually worth pursuing

Call it **Verifier-Calibrated Endpoint Route Feedback (VCERF)**.

### Algorithm

1. **Pass 1 base placement:** run normal Xplace or Xplace-Timing and produce a legal/routable placement.
2. **Same-stage timing snapshots:** on the same post-CTS/post-DP netlist, dump estimated slack before route
   and routed/OpenRCX slack after route. Do not mix pre-CTS estimated timing with post-CTS routed timing.
3. **Endpoint criticality extraction:** build criticality on driver-to-sink endpoints, not only per-net min
   slack. If endpoint identities are not available yet, use fanout-normalized net weighting as the mandatory
   control.
4. **Divergence trigger:** compute critical-set Jaccard with a constant top fraction and a named estimator
   fidelity. Treat the threshold as a heuristic, not a law, until recomputed consistently across designs.
5. **Second-pass actuation:** apply a bounded endpoint/net timing-WL force:

```text
g = g_WL + g_density + beta * normalize(g_route_feedback)
```

where `beta` is chosen by `--timing_force_frac`, not by an arbitrary raw scale.

6. **Verifier acceptance:** route the candidate and accept only if signoff TNS/WNS improves without dirty DRC,
   DRT failure, or unacceptable routed-WL/via/congestion regression.
7. **Skip rule:** if divergence is high-agreement, skip the second pass. bp_fe is the current negative-control
   example: union/fair/routed arms differ by only 0.29% of TNS at signoff.

### Why endpoint feedback is the right next abstraction

The mathematically faithful unit is an arc `(driver pin -> sink pin)`:

```text
S_endpoint(x) = sum_{(u,v)} kappa_{uv} * WA_or_L1_distance(u,v)
```

This removes most of the current surrogate's accidental effects:

- total force no longer scales with unrelated fanout;
- only critical sinks move;
- the reference endpoint can be the real driver, not the first hyperedge pin;
- it aligns with Efficient-TDP-style pin-to-pin actuation while adding route-feedback criticality as the
  novel source.

If endpoint extraction is too expensive for the immediate run, the next experiment must still use
`fanout_norm` and constant `topfrac`; otherwise the ariane gain can still be explained by geometry/fanout.

## 6. What would make this SOTA-level rather than narrow

The contribution cannot be "another timing-driven placer." Current strong baselines already cover concurrent
timing/routability/WL optimization and path-level pin-to-pin timing objectives. The defensible SOTA angle is:

> Existing timing-driven placers optimize estimated criticality; VCERF detects when estimated and routed
> critical sets disagree, then uses real route feedback to reselect the critical endpoints and verifies the
> candidate by signoff.

That is broader than "ariane-only" because it is an adaptive framework:

- on low-divergence designs it self-skips and behaves like the baseline;
- on macro-congested/high-divergence designs it spends one extra route to rescue the critical set;
- the trigger is part of the algorithm, not a post-hoc explanation.

But this framing is only publishable if the following falsifiers pass.

## 7. Decisive experiments

### P1. Fair actuator controls

Run ariane and bp_fe with:

```text
--oracle_topfrac 0.10
--timing_force_frac 0.1
--oracle_pin_weight_mode broadcast
--oracle_pin_weight_mode fanout_norm
```

If ariane's gain survives `fanout_norm`, the effect is about **which nets/endpoints** route feedback selects.
If it collapses, the current result is mostly fanout/geometry.

### P2. Endpoint weighting

Implement/load per-critical-sink weights and compare, at matched force norm:

```text
net-min broadcast  vs  fanout_norm  vs  critical-sink-only  vs  endpoint driver->sink
```

Expected publishable outcome: endpoint or critical-sink-only preserves most of union's gain with less HPWL
and lower variance.

### P3. Same-stage divergence

Dump estimated and routed slack on the same post-CTS/post-DP netlist. Report top-fraction Jaccard under the
same estimator used as the baseline. This fixes the current stage-mixing problem.

### P4. Gradient-reality finite difference

Perturb a saved placement by `+/- epsilon` along the route-feedback force, legalize, route with the same
backend, and measure real DR+OpenRCX TNS. Require the sign of measured change to agree with the predicted
descent direction more often than a random/shuffled criticality control.

### P5. Negative controls

Run all controls at the same top fraction and force norm:

- shuffled criticality labels;
- random same-degree nets;
- all-zero weights;
- estimated-only on a high-agreement design;
- stale oracle file path must fail loudly, not silently become baseline.

## 8. Paper claim after the autopsy

If P1/P2 pass:

> We introduce a verifier-calibrated route-feedback timing placement framework. It uses pass-1 routing to
> detect estimator/routed critical-set divergence, reweights only the critical endpoints under a bounded
> force budget, and accepts candidates by signoff. On macro-congested ariane, it improves DR+OpenRCX TNS by
> 15.3% over a fair estimated-timing baseline and by 15.0% over force-matched Xplace-Timing, while the trigger
> skips low-divergence designs where route feedback has no benefit.

If P1/P2 fail:

> The current positive is still valuable as a negative/diagnostic paper result: net-level broadcast
> route-feedback can look strong because of fanout/geometric side effects, and endpoint/fidelity controls are
> necessary for credible route-aware timing placement.

The first branch is the desired SOTA method. The second branch is still a meaningful research contribution,
but not the same paper.

## 9. Stop doing

- Do not cite `ariane_inflate_fidelity_results.txt`; it is the stale `DR_TNS == GR_TNS` output.
- Do not quote "Jaccard < 0.4" without naming the estimator and top fraction.
- Do not use fixed `topK=13000` for cross-design claims.
- Do not add IFT/soft-router complexity until endpoint/fanout and finite-difference checks pass.
- Do not claim broad SOTA until at least one second low-Jaccard/high-divergence or high-macro positive case is found, or
  the self-skip framework is evaluated as an adaptive algorithm across the full design set.

## 10. External positioning checked

- NVIDIA C3PO (ASP-DAC 2026) positions concurrent differentiable timing, routability, and wirelength
  optimization as the commercial-quality baseline family.
- Efficient-TDP (DATE 2025) provides the closest open path-level/pin-to-pin timing-driven placement baseline.
- DGR (DAC 2024) is the relevant differentiable global-routing substrate, but by itself is a router, not the
  same endpoint criticality feedback loop.

VCERF must therefore win on **route-feedback criticality source + verifier-calibrated adaptivity**, not on
generic timing-WL or generic routability.
