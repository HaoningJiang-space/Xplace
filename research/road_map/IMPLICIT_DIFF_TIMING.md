# Implicit-differentiation route-aware timing gradient (the route-response term frozen-criticality drops)

Goal: derive the route-aware timing-aware placement gradient when timing depends on placement
*through the routing solution*, and show precisely what the current frozen/envelope scheme
(`APPROACH_A.md`, `merged_wl_loss_grad_timing`) omits.

> Status: adversarially reviewed by codex (gpt-5.5) 2026-06-18 — core envelope objection
> CONFIRMED; overclaims tightened (Eq 6, 10–12, §7–8). See §11 for the review ledger.

## 1. Notation
- `x ∈ ℝ^{2n}` — movable cell positions.
- `r = p ∈ ℝ^{m}` — relaxed routing decision, **parameterized directly in probabilities**
  (per 2-pin arc, a point on the simplex `Δ` over its L/Z/C candidates), NOT in logits. This
  choice makes the lower problem convex (§7) and `∂ℓ/∂p` clean (§6).
- `R(p, x)` — routing cost the router minimizes (overflow + via + routed wirelength + barrier).
- `T(x, p)` — timing penalty, e.g. `T = −TNS = Σ_e max(0, −slack_e)` (nonsmooth — see §6).
- `f(x) = WL(x) + λ_d D(x)` — base placement objective (HPWL + density).

Routed length of net `n`: `ℓ_n(x, p)`, with parasitics `R_n = r_f ℓ_n`, `C_n = c_f ℓ_n`.

## 2. The bilevel problem
```
min_x   F(x) = f(x) + λ_t T(x, p*(x)),     p*(x) = argmin_{p∈Δ} R(p, x).             (1)
```
Use an interior log-barrier for the simplex so the lower problem is smooth and unconstrained in
the interior; lower-level stationarity:
```
∇_p R(p*(x), x) = 0.                                                                  (2)
```

## 3. The exact gradient (total derivative)
```
∇F(x) = ∇_x f(x) + λ_t [ ∂T/∂x + (dp*/dx)ᵀ ∂T/∂p ].                                   (3)
        \_____________/        \________/   \______________________/
         placement (have)       direct       ROUTE-RESPONSE cross term   (4)
```

## 4. What the frozen/envelope scheme computes — and the error
Current code: `force = κ · ∂(HPWL)/∂x`, `κ` (= `timing_pin_weight`) read from the routed timer
and **detached**. In the notation of (3):
```
∇F_frozen(x) = ∇_x f + λ_t · ∂T/∂x |_{p = p* fixed},                                  (5)
```
keeps the routed *ranking* (κ) but applies it to the route-blind geometric gradient and
**drops the cross term (4)**.

**Claim (corrects APPROACH_A.md's envelope justification — codex CONFIRMED).** The envelope
theorem does NOT make (4) vanish. It applies to the lower *value* `V(x)=R(p*(x),x)`, giving
`dV/dx = ∂R/∂x` because `∂_pR|_{p*}=0`. We differentiate `T`, a **different** functional, so
`∂_pR=0` does not imply `∂_pT=0`. The term must be retained.

**Honest scope (codex Eq 6).** Not "`∂_pT≠0 ⇒ cross≠0`" unconditionally. The cross term
`-(dp*/dx)ᵀ∂_pT = -Bᵀμ` (see §5) is **generically nonzero** but vanishes in special cases:
`B = ∂²_{px}R = 0` (placement does not shift the routing optimum), `∂_pT ∈ null(BᵀH⁻¹)`, or
`T = φ(R(p,x), x)` (then `∂_pT = φ_R ∂_pR = 0` at `p*`). Empirically it is large exactly in the
structural-congestion / high-divergence regime (R22) and ≈0 in the uncongested regime (R9) —
consistent with the divergence law.

## 5. Implicit differentiation of the routing layer
Let `H := ∇²_{pp}R(p*,x) ∈ ℝ^{m×m}` (symmetric; SPD by §7) and
`B := ∂(∇_pR)/∂x = ∇²_{px}R ∈ ℝ^{m×2n}` (gradients as column vectors). Differentiate (2):
```
H·(dp*/dx) + B = 0   ⟹   dp*/dx = − H⁻¹ B.                                            (6)
```
Cross term via the **adjoint** (avoid forming `H⁻¹`): solve `Hᵀ μ = ∂_pT` (≡ `Hμ = ∂_pT` since
`H=Hᵀ`), then
```
cross contribution to ∇F  =  −λ_t (dp*/dx)ᵀ ∂_pT  =  −λ_t Bᵀ μ  ∈ ℝ^{2n}.            (7)
```
Hence
```
∇F(x) = ∇_x f + λ_t ∂T/∂x − λ_t Bᵀ μ,        H μ = ∂_pT.                              (8)
```
One SPD solve (matrix-free CG with Hessian-vector products) + one sparse mat-vec `Bᵀμ`.

## 6. Connection to the GPU timer — and where it is exact vs heuristic
`∂_pT` factors through routed length:
```
∂_pT = Σ_n (∂T/∂ℓ_n)(∂ℓ_n/∂p),   ∂T/∂ℓ_n = Σ_{arc a∈n} (∂T/∂d_a)(∂d_a/∂ℓ_n).         (9)
```
- `∂ℓ_n/∂p_c = len_c` — **exact**, because `r=p` and `ℓ_n = Σ_c p_c·len_c` is linear in `p`
  (no softmax Jacobian; this is why §1 parameterizes in probabilities).
- `∂d_a/∂ℓ_n` — parasitic delay sensitivity (Elmore `d∝R_nC_n∝ℓ_n²` ⇒ `∂d/∂ℓ=2r_fc_fℓ_n·(topo)`;
  linear-delay model ⇒ constant). Exact given the chosen RC/delay model.
- `∂T/∂d_a = κ_a` — **this is the approximate step.** The *exact* `∂T/∂d_a` is the reverse-mode
  STA adjoint over the (max,+) arrival/required propagation. The gputimer's path-based
  `report_criticality_threshold + path exploration` produces a **support-truncated heuristic**
  estimate of that adjoint (it weights the top WNS-band paths, not all active violating paths).
  So (8) is **exact only if `κ` is the exact timing adjoint**; with heuristic `κ` it is an
  approximation whose error = (path-band truncation) + (subgradient choice below). Two options:
  (a) keep heuristic `κ` (cheap, current); (b) compute the exact adjoint by reverse-mode through
  a **smoothed** timing graph.

**Nonsmoothness (codex Eq 10–11).** `T=−TNS` uses `max(0,·)` and arrival `=max` over fan-in;
the derivative is a *set-valued subgradient*, nonunique at tied critical paths and at slack `=0`.
Make it a true gradient by either (i) smoothing max with log-sum-exp / soft-max (β-temperature),
or (ii) fixing the standard subgradient selection (the active critical path), which is exactly
what the criticality band does — state which is used.

## 7. A smooth, convex lower problem so H ≻ 0 (corrects the earlier claim)
Parameterize in probabilities and keep the demand **affine in p**:
```
R(p,x) = Σ_e ψ( s_e(p,x) − cap_e )  +  (γ/2)‖p‖²  +  (1/β) Σ_arc B_log(p_arc),         (10)
   s_e(p,x) = Σ_c p_c · a_{e,c}(x),   ψ convex,   B_log = simplex log-barrier (convex).
```
- For **fixed x**, `s_e` is **affine in p** ⇒ `ψ∘s_e` is convex in `p`; `‖p‖²` and `B_log` are
  convex ⇒ `R(·,x)` is **convex in p**, so `H = ∇²_{pp}R ≻ 0` **globally in p-space** and the
  inner argmin `p*(x)` is unique. (The earlier logits formulation was nonconvex — `softmax`
  destroys convexity; that is fixed by working in `p` with the barrier.)
- `B = ∇²_{px}R` exists iff `a_{e,c}(x)` is `C²` — use a `C²` soft occupancy (bilinear/smooth
  splat, reuse eDensity's bin-splat) and **fixed candidate sets** (no candidate appearing/
  disappearing as x moves). Then (6) holds. **IFT is LOCAL**: it differentiates the branch of
  `p*(x)` analytic at the current `x`; convexity-in-`p` gives uniqueness of that branch, and `B`
  must be evaluated at `(p*,x)` each step.

## 8. Complexity and the honest reduction
Cost of (8) `= (#CG iterations) × (HVP cost)`, **not** "a few routing evals" — CG iteration count
depends on `cond(H)`, so it needs a preconditioner (e.g. the `γI + diag` block) and empirical
justification. `H` is sparse with two coupling sources: **edge-incidence** (candidates sharing a
GCell edge) **and per-arc blocks** (the barrier/`‖p‖²` couple the candidates of the same arc).

**Critical-support reduction = a Schur complement, not a free lunch.** `∂_pT` is supported on
critical-net candidates `p_c` (vs non-critical `p_⊥`). Solving only the `cc` block,
`H_cc μ_c = ∂_{p_c}T`, **discards** the Schur-complement coupling
```
exact:  (H_cc − H_{c⊥} H_{⊥⊥}⁻¹ H_{⊥c}) μ_c = ∂_{p_c}T,   and   the  B_⊥ᵀ μ_⊥  contribution.  (11)
```
Dropping `H_{c⊥}H_{⊥⊥}⁻¹H_{⊥c}` and `B_⊥ᵀμ_⊥` assumes critical timing is insensitive to how
non-critical nets reroute/re-congest. State it; bound it by occasionally solving the full system.

## 9. Amortization: the learned surrogate (P-gate)
Train `Δ̂_θ(x)` (placement features → per-net routed length / detour), differentiable by
construction. Supervision: **value** (`Δ̂_θ(x) ≈ ℓ^routed(x) − ℓ^est(x)` from real routes) and/or
**gradient matching** (`‖ ∇_x(κᵀ ℓ̂_θ(x)) − g_cross^{IFT}(x) ‖²`, fitting (8)'s route-response
*direction*). Deployed: `∇_x f + λ_t ∂T/∂x + λ_t ∇_x( (∂T/∂ℓ)ᵀ ℓ̂_θ(x) )` — one forward+backward
through θ, no router, no staleness. (8) is the gold-standard training target; θ the cheap form.
Note θ inherits the same κ-approximation as (8) unless trained against the exact adjoint.

## 10. Summary
- Frozen criticality (5) drops the route-response cross term (4); the envelope theorem does
  **not** license this because `T ≠ R` (codex CONFIRMED). The term is **generically** nonzero,
  large in the high-divergence regime.
- (8) restores it via one adjoint solve `Hμ = ∂_pT`. **Exactness is bounded by κ** being a
  heuristic timing adjoint and by the subgradient/smoothing choice for nonsmooth TNS.
- Well-posedness requires the **probability-space, barrier-regularized, affine-demand** lower
  problem (§7), `C²` fixed-candidate soft occupancy, and is **local**.
- κ stays the sparse `∂T/∂d` estimate; the new content is `dp*/dx` via IFT — the bidirectional,
  no-staleness route-aware ∂T/∂x.

## 11. Review ledger (codex gpt-5.5, 2026-06-18, adversarial)
- CONFIRMED: §4–5 envelope objection is correct; route-response term must be retained.
- Fixed Eq(6): "generically nonzero" + cancellation cases (B=0 / nullspace / T=φ(R,x)).
- Fixed Eq(7–9): B defined as ∇²_{px}R; adjoint `Hᵀμ=∂_pT` → `Hμ` by symmetry; row/col convention.
- Fixed Eq(10): `r=p` so `∂ℓ/∂p_c=len_c` exact (no softmax Jacobian).
- Fixed Eq(10–11): κ = heuristic, NOT exact STA adjoint — stated; TNS nonsmooth → smoothing/
  subgradient rule stated.
- Fixed CRITICAL Eq(12→10): H≻0 does NOT hold in logits; re-derived in p-space (affine demand +
  convex ψ + barrier ⇒ globally convex in p). IFT made explicitly local; `C²` fixed candidates.
- Fixed §8: reduction reframed as Schur complement with the discarded terms named; CG cost =
  #iters × HVP, needs preconditioning; H sparsity = edge-incidence + per-arc blocks.
