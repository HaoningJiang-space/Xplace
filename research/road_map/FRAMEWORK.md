# FRAMEWORK — the system behind the route-aware timing placer

Purpose: tie the empirical results (R1–R11), the fidelity discipline (FIDELITY.md),
and the method into ONE coherent framework, derived from first principles. This is
the "what problem are we actually solving, and what is the general shape of the
solution" document. Updated as understanding sharpens.

## 1. First-principles statement of the problem
Global placement minimizes a **surrogate** objective `f_est(x)` (HPWL / estimated-RC
timing) as a proxy for the **true** objective `f_true(x)` (post-route timing/PPA).
The two differ by a **structured, placement-dependent gap**:

```
f_true(x) = f_est(x) + Δ(x)         Δ(x) = routing-response distortion
```

The entire thesis reduces to three claims about Δ, each now an experiment:
- **(E) Δ exists and is structured** — routing-induced parasitic distortion of
  timing-critical arcs (R1/R1b: residual beyond RUDY; R10: on a macro design the
  est-vs-routed criticality overlap is Jaccard **0.003**).
- **(C) Δ is placement-controllable** — its expectation over routing randomness is a
  usable function of x (R11: steering placement by the *true* routed criticality
  improves post-route TNS ~23% at lower wire-cap; FIDELITY D2 controllability).
- **(P) Δ is predictable cheaply pre-route** — a surrogate `Δ̂(x)` from placement-time
  features (detour/residual-capacity/RUDY/Φ_F) ← the thing to build.

If E∧C∧P hold, a placer optimizing `f_est + Δ̂` closes post-route timing a congestion-
blind placer cannot. R10+R11 give E and C on a congested design; P is the open work.

## 2. The sharpest insight (why this is not "more timing weighting")
Δ matters **only where `f_est` and `f_true` disagree** — i.e. where congestion makes
routed criticality diverge from estimated criticality. The data proves this is the
hinge:
- **aes (uncongested):** est≈routed (Spearman 0.95, Jaccard 0.61) → Δ≈0 → route-aware
  = estimated, **no headroom** (R9).
- **ariane133 (congested):** est⊥routed (Jaccard 0.003) → Δ large → route-aware ≫
  estimated, **~20% headroom** (R11).

So the contribution is not a timing term; it is **correcting the surrogate exactly in
the structured direction where it lies, gated to where it is controllable.** Generic
timing weighting (even with a perfect criticality *ranking*) cannot do this when the
ranking itself is what's wrong — which is the congested case (R10).

## 3. High-level abstraction → borrow from other fields
This is an instance of **surrogate optimization with a biased model + learned bias
correction** — the same structure as:
- **Sim-to-real (robotics/RL):** optimize in a cheap simulator whose bias vs reality
  is learned and corrected; trust the correction only where it generalizes.
- **Bayesian optimization with model discrepancy (Kennedy–O'Hagan):** `y = η(x) +
  δ(x)`; δ is the systematic model-form error — exactly our Δ.
- **Offline RL pessimism:** don't optimize where the model is uncertain/uncontrollable
  (our FIDELITY D2b: only the placement-controllable, finite-difference-verified
  component of Δ enters the gradient).
- **Multi-fidelity optimization:** cheap est-RC (low fidelity) + occasional routed
  ground truth (high fidelity) + online recalibration (FIDELITY D2c).
These give us the discipline (calibrate, gate by controllability, re-ground online)
and the failure modes (exploiting model bias = FIDELITY D2/D8). The novelty vs them is
the **physical mediator**: Δ is not a black-box residual but routing-response →
parasitics → delay, which makes `∇Δ̂` physically meaningful and harder to game.

## 4. Data structures (be deliberate here)
- **Modeling unit = driver→sink timing ARC, not net.** Per-net loses the asymmetry
  (driver vs sink, per-sink detour). R11 used net-weighting as a first probe; the real
  Δ̂ lives on arcs. ARC KEY MUST BE UNIQUE (FIDELITY D9; the GR-residual join blew up
  340k→492k on non-unique keys — a data-structure bug, not a nuisance).
- **Δ̂ output = a per-arc multiplier field** `(m_len, m_R, m_C, m_via)` feeding the RC
  tree → timer. Multipliers (not absolute RC) keep it bounded and calibratable.
- **Criticality = a WNS-relative self-shrinking band** (report_criticality_threshold),
  not a fixed top-K — it concentrates compute on the ~hundreds of arcs that gate TNS
  and self-disables when timing is met.
- **Injection point = the timing-WL term** `merged_wl_loss_grad_timing(timing_pin_weight,
  net_weight)` (R7 finding: plain GP ignores net_weight; this is the ONLY per-net/pin
  hook). The route-aware force is a per-pin weight field over the placement gradient.
- **Routing-response features = local corridor maps** (demand/capacity/blockage/pin-
  density) → CNN, + per-arc scalar features → MLP/GNN. Spatial structure matters.

## 5. The system (framework components, and where each result/rule lives)
```
            placement x
                │
   [Feature extractor]  local corridor maps + per-arc features      (§4)
                │
   [Route-response model Δ̂]  per-arc (m_len,m_R,m_C,m_via)          (P, open)
                │   ── calibrated & gated to controllable part (FIDELITY D2)
   [RC/timer]  R̂=R_est·m_R, Ĉ=C_est·m_C → arc delay → slack → WNS/TNS
                │
   [Criticality band]  WNS-relative, self-shrinking                 (§4)
                │
   [Timing-WL gradient]  per-pin weight field, overflow-scheduled   (D3,D4,R7)
                │
   [Nesterov GP]  f_est + Δ̂-correction, bounded additive           (D5)
                │   ── periodically re-ground vs real router        (D2c)
            better x  → judged POST-ROUTE (D1,D6,D7)
```
Validation gates: **E** (R1/R1b/R10), **C** (R11), **P** (to build) → then Exp3
full-flow PPA vs C3PO / Xplace-Timing.

## 6. "There is always a better way" — open iteration directions
- RC-correction oracle (delay magnitudes, not just criticality ranking): does it beat
  the criticality oracle of R11? (upper-bounds P's ceiling).
- Predict Δ̂ directly vs predict detour then propagate — which is more learnable/robust?
- Self-shrinking band vs differentiable soft-criticality weighting.
- Online co-optimization (place⇄GR every K iters) vs one-shot predictor.
- 3D extension: Δ includes tier-assignment + inter-tier vias (see open3dbench memory).

## 7. Falsification ledger (the framework must survive these)
E without C (Δ exists but uncontrollable) → thesis dead. C without P (controllable but
unpredictable cheaply) → fall back to bounded residual-flow emulator. P without iso-
congestion/PPA win → not non-incremental. Each has a designed experiment; see FIDELITY
falsifiable checks + RESULTS IN-FLIGHT.
