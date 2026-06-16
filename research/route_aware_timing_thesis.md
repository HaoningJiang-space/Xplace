# Route-aware pre-route timing model — DAC 2027 thesis plan

Venue: DAC 2027 (San Jose, 2027-07-10/16; CFP/deadline TBA). Target paper-ready
≈ autumn 2026. Source: https://dac.com/2026/events/dac-2027

## One-line thesis

> A unified pre-route timing model should not estimate timing from geometry
> alone; it should predict the **routing-induced parasitic distortion** of
> timing-critical arcs and propagate it through STA.

NOT: `WL loss + timing loss + congestion penalty` (incremental, crowded).
INSTEAD: replace the inaccurate placement-stage RC/timing estimate by a
**route-aware timing surrogate** with an explicit physical mediator:

```
placement x → routing response / parasitic distortion → arc delay/slew
            → path slack / WNS / TNS → placement optimization
```

`D_place_est(n)  →  D_route_aware_hat(n)`, via an explicit intermediate layer
`routing-induced parasitic distortion` (detour is the main but not the only
variable: detour multiplier, via multiplier, layer-assignment tendency, local
coupling/congestion parasitic factor).

## Modeling unit = driver→sink timing ARC (not whole net)

For `a = driver(n) → sink_i(n)` predict:
```
m_len(a) = routed_len / est_len
m_R(a)   = routed_R / est_R
m_C(a)   = routed_C / est_C
m_via(a) = routed via proxy
```
then `R_hat(a)=R_est(a)·m_R(a)`, `C_hat(a)=C_est(a)·m_C(a)` → feed the timer →
`D_hat_route(a)`, `slack_hat`, `WNS_hat/TNS_hat`. The model does NOT black-box
WNS/TNS; it goes through the physical chain congestion → route response →
parasitics → timing.

## Features (per arc + local corridor)

Critical one (captures router reroute response, which static cut-pressure missed):
```
residual_path_ratio = shortest-path cost on residual-capacity grid / geometric shortest length
```
Plus: RUDY, capacity-RUDY, Φ_F cut pressure, gap_meter (decides when Φ_F is
trustworthy), bbox size/aspect, fanout, criticality/slack, macro blockage ratio,
pin density, local layer capacity, estimated FLUTE/HPWL RC.

## Model structure (a DAC-level architecture)

- Spatial encoder: CNN/U-Net over local corridor maps (demand, capacity,
  blockage, pin density, macro, RUDY).
- Arc encoder: MLP/GNN over arc features (length, fanout, slack, driver
  strength, sink cap, topology).
- Physics decoder: outputs m_len, m_R, m_C, via/layer proxy → RC/timer computes
  delay/slack (differentiable propagation).

Multi-task loss, critical-arc weighted (else accurate on non-critical nets but
useless for timing closure):
```
L = L_detour + L_R/C + L_arc_delay + L_slew + L_slack_rank + L_WNS/TNS_proxy
weight(a) = criticality(a)^p
```

## Delta vs prior work (must be explicit)

Detour / pre-route timing prediction is NOT new: Ahn & Kim (detour net
prediction), LaRC-Timer, DTOC, TimingPredict (pre-route timing prediction).
Our delta:
> Prior work predicts detour, congestion, or timing as SEPARATE targets. We
> build a unified route-aware timing model where routing-induced parasitic
> distortion is an explicit MEDIATOR from placement congestion to post-route
> timing degradation — i.e. detour/parasitic distortion becomes a structured
> intermediate layer of the placement-time timing model, not a side prediction.

Also distinct from NV-Place/C3PO/RUPlace/DCGP (separate additive timing &
congestion objectives, or unified place-route without a parasitic-distortion
timing mediator) — pending NV-Place close-read (codex job).

## Must include placement optimization (prediction-only ≈ won't make DAC main)

Plug the surrogate into the Xplace timing loop; update route-aware timing weights
every N iterations. Compare, all judged POST-ROUTE:
```
baselines: Xplace-Timing | Xplace+RUDY | Xplace+capacity-RUDY | Xplace+Φ_F | Xplace+ours
metrics:   post-route WNS, TNS, #violating paths, routed WL, overflow/DRC proxy, runtime
target:    post-route WNS/TNS clearly better than Xplace-Timing; routed congestion
           not worse; HPWL/routed WL only small increase; runtime acceptable
```

## The hidden critical-path item: the DATA ENGINE (my addition)

Everything above needs supervised pairs `(placement features) → (real routed
parasitics, per arc)` at scale, AND the same engine produces the post-route STA
used for evaluation. So build first:
```
place (Xplace, many seeds/designs) → route (CU-GR: tool/cugr_ispd2015_fix, drcu/iccad19gr)
→ extract routed length/via/parasitics per net → per driver→sink ARC labels (m_len,m_R,m_C,m_via)
→ post-route STA (Xplace timer via SPEF, or OpenSTA) for WNS/TNS ground truth
```
This engine gates BOTH training data and the post-route eval baseline. Experiment
1 is its first slice.

## Minimal publishable path

1. Exp 1 — prove detour/parasitic distortion explains the critical-arc timing gap
   (`research/exp1_detour_timing_gap.md`). Doubles as data-engine bootstrap.
2. Build the arc-level route-aware timing predictor (the surrogate).
3. Insert into Xplace timing loop; update weights every N iters.
4. Full benchmark: ICCAD2015 superblue, multiple designs × placement seeds.
5. Ablations: −detour, −residual_path, −gap_meter, RUDY-only, direct black-box timing.
6. Frame as a unified model, not feature engineering.

## Environment (moe-server, built & verified)

`/data/ziheng/wzh/xplace_dac/Xplace`, env `/data/ziheng/wzh/conda_envs/xplace`
(CUDA 11.7, torch 2.0.1+cu117, 2× A800). CU-GR prebuilt at
`tool/cugr_ispd2015_fix/CUGR`. See [[dac2027-congestion-aware-timing-thesis]].
