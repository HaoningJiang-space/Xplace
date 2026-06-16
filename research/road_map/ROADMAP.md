# Route-Aware Timing-Driven Placement — Roadmap & Key Results (v3)
Target: DAC 2027 (paper-ready ~autumn 2026). Built on Xplace (mixed-size); OpenROAD/ORFS downstream.
Last updated: 2026-06-16. (v3 = mixed-size/macro scope + routing-response reframing.)

## 0. Problem reframing (the real thesis)
Placement-time timing error is NOT a "weak timer" problem — it is a **missing routing-response model**.
```
real:        x → router R(x) → P_route(x) → STA → WNS/TNS
traditional: x → P_est(x)              → STA            (P_est ≠ P_route)
```
We model the missing layer: **routing-induced parasitic distortion** `Z(x) = P_route(x)/P_est(x)`
(components: length detour, R/C/via multipliers, layer/pin-access/coupling). **Detour is the first-order
observable of Z, not the mechanism.** Chain: `congestion/blockage → routing response → Z → delay/slew → slack`.

## 1. Thesis (sharpened, post-C3PO, mixed-size)
Prior concurrent timing/routability placers (incl. **C3PO**, NVIDIA ASPDAC'26) optimize timing on
**idealized FLUTE-Steiner Elmore RC** and routability on **aggregate RUDY** — blind to **per-arc routed-
parasitic distortion** (esp. detours **around macros/blockages**, vias, pin-access). We add a
**differentiable per-arc routing-response layer** to a graph-based STA inside Xplace, and inject it into
slack gradients that move **macros and cells**, closing a post-route WNS/TNS gap C3PO-style objectives can't see.

## 2. Status — HONEST (incl. correction)
- ✅ Xplace build + ICCAD2015 timing run (superblue4 placement-time late WNS/TNS −6.99/−7091).
- ✅ ORFS data engine (no docker): gcd full flow → routed DEF + **SPEF**; per-net length + pre/post WNS/TNS extraction.
- ❌ **Exp1 gcd pilot invalid** (correction): the placement baseline had **zero wire cap** (`set_wire_rc` missing) → the "3.2× TNS" was RC-from-zero, scaling with absolute length, NOT detour; detour-**ratio** `drt/grt` is the wrong object (global route over-estimates). gcd too small / no macros. **Premise not yet validated; gating open.**
- 🔄 ASAP7+TILOS alignment env (sub-agent). ariane133 nangate45 fails at ORFS `2_4_floorplan_macro` (ORFS macro placer skew — irrelevant: C3PO-style replaces it with OUR mixed-size placement).

## 3. SCOPE DECISION: do macro placement (mixed-size), aligned to C3PO
- C3PO does **concurrent macro + standard-cell placement** (replaces entire GP incl. macro placement; NOT die/IO/PDN). Its biggest wins are macro-heavy (ariane 8.3%).
- **Xplace already supports mixed-size** (`--mixed_size`, `macro_legalization.py`). So we CAN, and SHOULD.
- **Why it strengthens us (causality flip):** with FIXED macros, macro-channel detours are floorplan-determined → uncontrollable. **If WE place macros, those detours become OUR decision → controllable**, and they are exactly where Z is **largest and most Steiner/RUDY-blind** (Steiner ignores blockages; RUDY is aggregate). So macro placement = highest-leverage place for our wedge.
- **Headline designs flip to ariane133/136** (macro-dominated = max leverage, = C3PO headline). std-cell designs (IWLS) = breadth + ablation.

## 4. The model (structured, not black-box)
- **Unit = timing arc (driver→sink)** (a critical sink can be detoured even if net bbox is fine). 
- **Predict** `Z_a = {detour, mR, mC, via/layer proxy}` from pre-route features (geometry, net topology, **macro/blockage geometry**, residual-capacity/RUDY/capacity-RUDY/Φ_F/gap_meter, pin density, est. RC/slack/criticality).
- **Physics decode:** `R̂=R_est·mR`, `Ĉ=C_est·mC`.
- **Objective = path-level via graph-based STA** (like C3PO: Elmore + LSE soft-max propagation, slew-aware), NOT arc-independent and NOT Efficient-TDP's extract-then-attract (which ignores slew). Gradient flows path→arc→positions(macros+cells).

## 5. Three experiments = three gates (must separate)
- **Exp1 / Gate A — Mechanism:** does `Z` (esp. routed_RC−Steiner_RC, beyond RUDY) explain Δdelay on critical arcs? Mixed-model/clustered-SE regression `Δ(routed−Steiner) ~ detour+via+pin_access+blockage+log(len)+fanout | local_RUDY, net_FE`, proper `set_wire_rc`, congested+macro design.
- **Exp2 / Gate B1 — Predictability:** can pre-route features predict `Z` on **held-out designs** (defeat "design-specific surrogate")?
- **Exp3 / Gate B2 — Utility + Causality:** injected into mixed-size placement, does post-route WNS/TNS improve at matched routed-WL/congestion/DRC, **same seed/flow**? With the causality test below.

## 6. CAUSALITY GATE (make-or-break, now at macro level)
Does **moving macros (+cells)** change per-critical-arc routed-RC distortion **predictably**, in the part Steiner+RUDY miss? Test: **route-seed variance** (same placement, N seeds → is Z placement-driven or seed noise?) + **oracle** (substitute true routed-RC into the timer → upper-bound gain) + placement-perturbation sensitivity. **If Z is seed/uncontrollable → thesis dead.**

## 7. C3PO differentiation + protocol
DISTINCT-BUT-WEAK → strong only if Exp3 wins. **Protocol = C3PO TABLE III:** replace entire GP (incl. macro placement) with our mixed-size Xplace, identical downstream ORFS recipe + same seed, report place/clock/route-opt full-flow PPA. **Key ablation:** same mixed-size flow with C3PO-style (Steiner-RC+RUDY) macro+cell placement vs our routing-response layer → attributes the win to OUR layer, not to mixed-size itself.

## 8. Benchmarks / dataset strategy (methodologize the gap)
"Timing benchmarks lack routing stack; routing benchmarks lack timing" is a **motivation**, not a nuisance.
- **Primary (real-tech full-flow):** ORFS **ASAP7 + TILOS (ariane133/136, mempool) + IWLS (FPU/aes/mc_top/DES/i2c)** — LEF/Lib/SDC/route/SPEF/STA. Required for DAC credibility.
- **Auxiliary (controlled):** ICCAD2015 augmented routing for large-timing-benchmark controlled study. Paper must clearly separate **real-tech evidence** from **controlled auxiliary** (don't let synthetic-via undermine credibility).

## 9. Baselines (must beat ALL)
Xplace-Timing; RUDY penalty; capacity-RUDY; Φ_F; **C3PO-style (Steiner-RC + RUDY, in-Xplace)**; and crucially **direct black-box ML (features→post-route slack)** — ablation must show the **structured routing-response layer** generalizes better / is more accurate on critical arcs / more interpretable than direct slack prediction.

## 10. Architecture
Model inside **Xplace mixed-size** (route-aware timing gradient on macros+cells). **OpenROAD/ORFS** = route→SPEF→post-route STA (labels + eval harness; inject at GP stage, same recipe/seed). **Verify EARLY:** Xplace↔ORFS instance/net-name round-trip (SPEF/STA matching).

## 11. How to do it BETTER (design principles)
1. **Learn the RESIDUAL, not absolute RC:** target `routed_RC − Steiner_RC` (the part Steiner misses) → focuses capacity on the wedge, structurally defeats "it's just a Steiner estimate."
2. **Blockage-aware, not congestion-aggregate:** feed macro/blockage geometry + residual-capacity corridor features; predict per-arc detour AROUND specific blockages — this is precisely what RUDY (aggregate) cannot do and is our distinction.
3. **Cheap-predictor + online calibration** (Xplace-Timing template): differentiable Z-predictor in the inner loop, periodically recalibrated against real OpenROAD route+SPEF → cheap AND accurate, avoids drift.
4. **Self-supervised labels from the data engine:** placement variants → route → SPEF → per-arc (Steiner-RC, routed-RC, detour, via, blockage features) labels; no manual labeling; doubles as the Exp1 evidence.
5. **Oracle upper bound first:** before optimizing the predictor, substitute TRUE routed-RC in placement to measure the achievable gain ceiling → tells us if the bottleneck is the mechanism or the predictor.
6. **Always ablatable:** every result = with/without the routing-response layer, same everything else.
7. **Generalization by construction:** train predictor on a design split, test held-out → answers C3PO's "ML surrogates don't generalize" critique head-on.

## 12. Milestones
1. **Foundations (parallel, before gating):** proper `set_wire_rc`/corner calibration (setup/cworst); Xplace↔ORFS name round-trip; ASAP7+TILOS setup; get Xplace mixed-size → ORFS injection working on ariane133.
2. **Exp1/Gate A** (mechanism: Z beyond Steiner+RUDY) on ariane133/mempool.
3. **Causality + Exp2** (controllability via route-seed/oracle; predictability held-out). **TRUE go/no-go.**
4. If pass → build differentiable per-arc routing-response layer in Xplace mixed-size.
5. **Exp3** full-flow: vs in-Xplace C3PO-style + direct-ML baselines, ASAP7+TILOS+IWLS, same recipe/seed.
6. **Fallback:** if uncontrollable → closed-loop post-route timing repair/ECO (needs closed loop, not prediction-only).

## 13. Kill conditions
- **Causality:** Z is route-seed/uncontrollable by macro+cell placement → dead (top risk).
- routed_RC ≈ Steiner_RC on critical arcs → no wedge.
- Z ⊆ RUDY (no beyond-RUDY signal) → "congestion proxy".
- doesn't generalize to held-out designs → dead.
- effect < route-seed noise → not actionable.
- our layer doesn't beat direct black-box ML → no reason for the structure.
- closed-loop worsens DRC/WL/congestion → net-negative.

## 14. codex essence-review integration (v3.1, 2026-06-16)
Verdict: **needs-sharpening** — non-incremental is achievable but, as written, still close to "C3PO + learned routed-RC residual." Sharpenings adopted:

- **Submit framing (replaces §1 one-liner):** *"We formulate timing-driven placement as optimizing the **controllable residual response of the router**, proving that post-route timing loss is often caused by placement-dependent parasitic distortion invisible to Steiner timing and aggregate congestion."*
- **The insight (final):** *Only the placement-CONTROLLABLE component of routed-parasitic error should enter timing gradients.* (Controllability is part of the claim, not a caveat.)
- **#1 NEXT ACTION = ORACLE EXPERIMENT (the SOTA determinant, go/no-go):** on macro-heavy ASAP7/TILOS, inject *true* routed-RC residual into placement, vs a matched in-Xplace C3PO-style baseline, with route-seed variance. **If oracle gain is not real beyond route-seed noise → STOP.** This precedes building any predictor (don't optimize a predictor for a gain that doesn't exist).
- **Incremental-kill baseline (add to §9):** C3PO-style placer **+ any better Steiner / global-route RC** — must show *that* still fails while the *controllable routing-response residual* wins. Proves we are not merely a better parasitic estimator.
- **NEW fundamental risk — "differentiable exploitability" (add to §13):** router response is discontinuous; predicting Z is insufficient if ∇Z points in directions that don't improve *final routed* STA. **Guard: finite-difference validation** — perturb cells/macros along the learned gradient, re-route, confirm post-route STA actually improves (gradient–reality agreement), not just the surrogate.
- **§11 missing principles (added):** (8) variance-aware optimization against route-seed noise (signal must exceed it); (9) finite-difference gradient↔post-route-STA agreement; (10) CTS/route-opt/MCMM/hold-aware evaluation, not setup-only; (11) covariate-shift control (the placer changes the routed-RC distribution it was trained on → online recalibration); (12) runtime fairness vs C3PO; (13) negative controls (designs/regimes where the method should NOT help — uncongested, macro-free — and must not).
- **Drift traps to actively avoid (§0 guardrails, restated):** congestion predictor; direct-ML slack surrogate; Steiner-RC refinement; pin-access/via estimator with no placement causality; router-in-the-loop engineering paper; ORFS-specific calibration trick; macro-placer paper where timing response is incidental.
- **Realistic SOTA outcome:** clear WNS/TNS wins on macro/blockage-heavy (ariane/mempool) at matched WL/DRC/congestion; neutral/small on std-cell. That asymmetry is itself evidence for the controllability thesis (and the std-cell neutrality = a built-in negative control).
