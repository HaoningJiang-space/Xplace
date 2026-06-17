# Mathematical formulation of the essential method (and an honest efficacy analysis)

## 1. Setup
Placement variable x (cell positions). True objective = post-route TNS:
```
T(x) = Σ_e max(0, -slack_e(x)),   slack_e = RAT_e - AAT_e,   AAT_e = Σ_{a∈path(e)} d_a
```
Arc delay d_a = cell_delay_a + wire_delay_a. Elmore: wire_delay_a ≈ α R_a C_a with R_a = r·ℓ_a,
C_a = c·ℓ_a + C_pin ⇒ **wire_delay_a ≈ α r c · ℓ_a² + α r C_pin ℓ_a** (∝ routed length ℓ_a, super-linear).
Routed length splits:
```
ℓ_a(x) = ℓ_a^WL(x)  +  Δ_a(x)
         (net-span / HPWL part)   (DETOUR part)
```
- ℓ_a^WL depends **directly** on x (the net's own pin spread).
- Δ_a depends on x **only through the congestion field** ρ(·): Δ_a = Δ_a(ρ(x)) — the router detours
  arc a in proportion to congestion along its corridor.

## 2. The exact timing gradient (the whole point)
```
∂T/∂x = Σ_a w_a · ∂ℓ_a/∂x ,   w_a := Σ_{crit e ∋ a} (∂T/∂d_a)(∂d_a/∂ℓ_a) ≥ 0   (criticality, ∝ wire-delay sens.)
```
Chain rule on ℓ_a = ℓ_a^WL + Δ_a(ρ(x)):
```
∂T/∂x = Σ_a w_a ∂ℓ_a^WL/∂x                         ── TERM 1: timing-weighted wirelength PULL
       + Σ_a w_a (∇_ρ Δ_a)·(∂ρ/∂x)                   ── TERM 2: timing-weighted DETOUR-via-congestion
```
Regroup TERM 2 by bin b of the congestion field:
```
TERM 2 = Σ_b π_b · (∂ρ_b/∂x) ,   π_b := Σ_{a routed through b} w_a · (∂Δ_a/∂ρ_b)  ≥ 0
```
**π_b = the TIMING-WEIGHTED CONGESTION PRICE of bin b** — the marginal critical-path delay caused by
one unit of congestion in b. Since ∂ρ_b/∂x pushes a cell's contribution into b, gradient DESCENT on
TERM 2 **repels cells out of high-π_b bins** = clears the corridors of timing-critical arcs. This is
*exactly* the essential method, and π_b is a Lagrange/price variable (timing-weighted congestion
dual). It is the missing cross-term: standard TDP keeps only TERM 1; routability keeps only an
**unweighted** Σ_b ρ_b penalty (π_b ≡ const). The essence = π_b weighted by criticality.

## 3. The precise diagnosis of why R15 failed (mathematically)
R15 injected the routed/estimated RC ratio m_a = ℓ_a/ℓ_a^WL into the **wirelength** gradient:
```
R15 used:   ∂T/∂x ≈ Σ_a (w_a · m_a) · ∂ℓ_a^WL/∂x          (scale the PULL by the detour ratio)
correct:    ∂T/∂x  = Σ_a w_a ∂ℓ_a^WL/∂x + Σ_a w_a (∇_ρΔ_a)(∂ρ/∂x)
```
R15 attributed the detour's x-dependence to **∂ℓ_a^WL/∂x** (the net's own span), but detour depends on
x through **ρ** (the congestion field), not through the net's span. **Wrong Jacobian.** For a
congestion-detoured net ∂ℓ_a^WL/∂x is small (pins already close) while ∂Δ_a/∂ρ is what matters — so
R15 put large weight on a near-irrelevant, and worse, *congestion-increasing* direction (pulling adds
to ρ in the corridor, i.e. it pushes ∂ρ_b/∂x the WRONG sign for TERM 2). Hence monotonic worsening
with m_a accuracy (R15/R16). The math predicts the sign and the monotonicity we observed.

## 4. Is it actually GOOD? (honest, where it can break — these are testable)
TERM 2 is real and omitted today, but its *usefulness* rests on three quantities:
- **(a) ∇_ρ Δ_a — is detour a usable (differentiable) function of congestion?** Real routing is
  discrete: Δ_a is a step function of ρ (no detour until capacity is exceeded, then a jump). So the
  raw ∇_ρ Δ_a is ~0 a.e. with spikes ⇒ a bad gradient (FIDELITY D8). **Mitigation:** use a SMOOTH
  congestion→detour surrogate — probabilistic congestion (RUDY / expected overflow) gives
  Δ_a ≈ ϕ(demand_b/cap_b) smooth and convex-ish ⇒ a well-behaved ∂Δ/∂ρ. This is *the* modeling crux;
  if no smooth surrogate tracks real detour, the method has no gradient.
- **(b) w_a's wire fraction — does wire/detour delay matter vs cell delay?** w_a ∝ ∂d_a/∂ℓ_a =
  α r(c·2ℓ_a + C_pin). If cell delay dominates the critical paths, TERM 2 is small regardless
  (D5/§5 risk). Effect size is design/node-dependent (must measure the wire-delay fraction on the
  critical paths).
- **(c) coupling stability.** w_a and π_b depend on slacks which depend on ρ which depends on x — a
  fixed point. Naively iterating can oscillate (known timing-mode oscillation). Needs damping
  (EMA on w_a, slow π_b ramp) — standard, but must be respected.

## 5. Verdict
- **Mathematically principled: YES.** The method is precisely the gradient term TERM 2 that the true
  ∂TNS/∂x has and that both standard TDP (TERM 1 only) and routability (unweighted ρ penalty) omit.
  R15's failure is explained exactly as a wrong-Jacobian mis-attribution (with the right sign &
  monotonicity). The price π_b gives a clean optimization-dual interpretation (timing-weighted
  congestion pricing) — distinct from the *dead* pure-Beckmann claim because criticality enters the
  price, i.e. it is the cross-term, not "HPWL + congestion".
- **Guaranteed good: NO.** Its efficacy is gated by (a) a smooth congestion→detour surrogate
  existing, and (b) the wire/detour-delay fraction being material. Both are empirical. So the
  decisive experiment is not optional decoration — it tests exactly (a)+(b). If TERM 2's smooth
  surrogate can't be built or its magnitude is tiny, the principled-but-weak method reframes to the
  (already solid) negative result R15/R16.

## 6. What this makes the contribution
A timing-weighted congestion-price force `f_b = -π_b ∇_x ρ_b` added to the GP gradient, with π_b from
a smooth (RUDY-style) detour surrogate and criticality from the path timer. It is the *correct* way to
make placement route-aware — through the density/congestion Jacobian, not the wirelength one.
