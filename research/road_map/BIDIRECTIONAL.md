# Bidirectional differentiable fusion: x and p co-descend (resolves the lever mismatch)

## The correction to my envelope plan (user, 2026-06-18)
The envelope approach was UNIDIRECTIONAL: solve r*(x), freeze it, ∂/∂x only. True bidirectional =
x (positions) and p (routing-pattern probabilities, DGR's variable) are TWO co-equal differentiable
variables in ONE objective; gradients flow both ways. Hard constraint: **bidirectional ⟺ an explicit
routing variable p must exist** → forces Level B (soft-rasterized differentiable routing). Level A
(RUDY ℓ̂(x)) is one-directional (no routing state to push back) — warm-up, not endpoint.

## The coupled objective
```
L(x, p) = WL(x) + λ_d·D(x) + λ_r·Overflow(x,p) + λ_t·T(x,p)
                                  ↑ soft-rasterized, differentiable in BOTH x and p
∂L/∂x : move cells (incl. route-aware ∂ℓ̂(x,p)/∂x and ∂overflow/∂x)
∂L/∂p : adjust routing patterns (overflow + via + critical-net delay)
```
Co-descent (x fast / p slow, interleaved small steps — NOT solve-p-to-convergence-then-freeze) →
converges to a joint stationary point = self-consistent place/route. No staleness, no fixpoint
oscillation (R19 k3/k4 cured).

## ★ Why this resolves my central negative (R15 / ESSENCE / TERM-2 lever mismatch)
My finding: a critical net's DETOUR is congestion-set, NOT HPWL-pullable; feeding it to the
placement-pull lever (R15) hurts monotonically. The bidirectional system routes the detour to the
RIGHT lever:
- **∂T/∂x** : HPWL component → timing-driven PLACEMENT (move cells). Correct lever for the span part.
- **∂T/∂p** : detour component → timing-driven ROUTING (re-route the critical net shorter / make way).
  THE missing lever ESSENCE.md named. C3PO / Efficient-TDP optimize placement only — they do NOT have
  this ∂T/∂p channel. **This is the genuine differentiator.**

## κ stays the envelope constant (no backprop through STA)
κ = ∂T/∂delay is frozen (refresh STA every M steps), delay = f(ℓ(x,p)) is differentiable in x AND p:
timing force to x = κ·∂delay/∂x (have); timing force to p = κ·∂delay/∂p (new). κ's source is the
**union(est,routed) criticality (R23)**, gated by divergence (R22). So the criticality story is
unchanged — it now acts bidirectionally. "Bidirectional-differentiable + enveloped timing" = best
cost/benefit (no need for full end-to-end STA backprop + soft-topK).

## Level A is NOT the R15 trap (autograd attributes detour to the ρ-lever)
R15 manually scaled the HPWL-PULL by a stale detour ratio (wrong-lever attribution). Level A as a
FULLY differentiable ℓ̂(x) = HPWL(x) + detour(ρ(x)) fed into delay → autograd splits the gradient:
HPWL part → pull (TERM-1); detour part ∂detour/∂ρ·∂ρ/∂x → congestion/density lever (TERM-2),
automatically. So Level A correctly puts detour on the ρ-lever — provided the smooth detour surrogate
detour(ρ(x)) (RUDY / expected-overflow) is differentiable and tracks real detour (MATH.md §4a crux).

## Roadmap A → B
**Level A (cheap, one-directional, tests if differentiable routed-length helps + direction):**
- Add a differentiable per-net detour surrogate ℓ̂_n(x) = HPWL_n(x) + α·rudy_detour_n(x), where
  rudy_detour from the differentiable congestion map (density-splat of net bboxes — reuse eDensity).
- Feed ℓ̂ into the timing wire-delay (replace HPWL with ℓ̂ in the timing path), weight by κ (union).
- autograd → TERM-1 (pull) + TERM-2 (congestion repulsion). Measure post-route TNS vs the net-weight
  union baseline. CAUTION: still gated by divergence (R22) + the surrogate's fidelity (D8).
**Level B (the real thing, bidirectional):**
- soft-rasterized candidate routing (DGR_PLAN.md): pattern segments → bilinear-splat per-GCell demand,
  differentiable in x AND p; p = pattern logits (live variable).
- L(x,p) co-descent: Nesterov on x (route+timing forces) + a few Adam steps on p every K iters,
  shared L, κ refreshed every M. → ∂T/∂p timing-driven routing channel; staleness/oscillation gone.

## Honest costs
- Level B requires the soft rasterization (load-bearing, unavoidable for p to exist).
- Coupled dynamics → step-size/λ stability (x fast, p slow usually stable).
- κ periodic refresh (STA not in autograd) — accepted (envelope on timing).
- Payoff still gated by divergence (R22): bidirectional pays on high-divergence (fixed-macro) designs.
