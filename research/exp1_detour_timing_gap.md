# Experiment 1 — Does routing-detour congestion explain the placement→post-route timing gap?

This is the **physics gate** for the "congestion-aware timing-driven placement"
thesis. We do NOT build any new placer here. We only test one hypothesis on
existing Xplace + CUGR infrastructure. If it fails, the thesis pivots.

## Hypothesis

For **timing-critical nets**, the gap between placement-time estimated net delay
and post-route actual net delay is **explained by routing-congestion-induced
detour** (a congested critical net is detoured → longer wire → larger RC →
larger delay), and a **cheap local residual-capacity signal** can predict which
critical nets will suffer this gap.

Formally, per net `n`:
- `D_place(n)` = placement-time net delay (Xplace timer, estimated/FLUTE RC).
- `D_route(n)` = post-route net delay (Xplace timer fed routed parasitics).
- `Δ(n) = D_route(n) − D_place(n)`  (the timing gap we claim is congestion-driven).
- `detour(n) = routed_len(n) / est_len(n)`  (the mechanism: elongation).
- `ĉ(n)` = cheap congestion signal over net `n`'s bbox/corridor
  (RUDY, capacity-RUDY, cut-pressure Φ_F). Candidate **predictor** of Δ(n).

H1: on critical nets, `Δ(n)` is large and positively driven by `detour(n)`.
H2: `ĉ(n)` (placement-time, cheap) predicts `detour(n)` and `Δ(n)`.
H3: post-route WNS/TNS degradation concentrates on **congested critical nets**,
not uniformly.

## Why this is the right gate

If H1–H3 hold, the thesis has a real physical basis: a placer that anticipates
detour-RC for the few hundred critical nets can pre-empt the post-route timing
loss that congestion-blind timing-driven placers (DREAMPlace/Xplace-Timing/
DATE'25) cannot see. If they fail (gap is noise, or dominated by cell delay /
slew / buffering, or ĉ has no signal), we stop before building gradients.

## Benchmarks

ICCAD2015 contest designs (`superblue*`) — the standard timing-driven set Xplace
already supports (`--dataset iccad2015`, has `.sdc`/libs). Start with 2–3
designs (e.g. superblue1, superblue4, superblue18). The `iccad2015.ot` variant
(OpenTimer path) is the fallback if SPEF ingestion is needed.

## Pipeline (per design, per placement)

1. **Place.** Run Xplace to a placed solution. Two arms to widen the range of
   congestion: (a) plain `--timing_opt True`; (b) routability-relaxed (e.g.
   higher `--target_density`, no cell inflation) to deliberately create
   congested critical nets. Write DEF + guide.
   ```
   python main.py --dataset iccad2015 --design_name superblue4 --timing_opt True \
       --detail_placement True --write_placement True
   ```
2. **D_place(n).** From `src/core/timing_opt.py::GPUTimer` after GP/DP: capture
   per-net (or per-sink-pin) arc delay using the estimated RC path
   (`update_timing` / `update_rc_flute`). Dump `pin_arrival`, `pin_slack`, and
   per-net delay to CSV keyed by `data.net_names`.
3. **Route.** Run the router to get real routed wirelength per net:
   - in-tree: `--final_route_eval True` (invokes GGR), or
   - external CUGR (`tool/cugr_ispd2015_fix/`-style flow) for routed guides.
   Compute `routed_len(n)` and `est_len(n)` (HPWL or FLUTE) → `detour(n)`.
4. **D_route(n).** Re-time with routed parasitics:
   - preferred: generate SPEF from routed result and use the timer's SPEF path
     (`GPUTimer.update_timing_spef` / `tool/timer.py` `spef` option), OR
   - approximate: scale each net's wire R,C by `detour(n)` (R,C ∝ length) and
     re-run `update_timing` — this is the cheap-but-honest proxy and also
     exactly the model the future gradient would use, so agreement here is
     itself informative.
5. **Join** on net id: `Δ(n)`, `detour(n)`, `ĉ(n)`, slack rank → one CSV.

## Analysis

- Restrict to **critical nets**: worst-`K` endpoints' fan-in nets (use the same
  `report_criticality_threshold` machinery, thrs=0.9/0.99).
- **H1**: rank correlation `corr(detour(n), Δ(n))` on critical nets; report the
  magnitude of Δ relative to design WNS/TNS (is detour-delay a material fraction
  of the violation, or negligible vs cell/slew delay?).
- **H2**: rank correlation `corr(ĉ(n), detour(n))` and `corr(ĉ(n), Δ(n))` for
  ĉ ∈ {RUDY, capacity-RUDY, Φ_F-bbox}. Which cheap signal predicts detour best?
- **H3**: bucket critical nets by `ĉ(n)` (high/low congestion); compare ΣΔ and
  contribution to post-route TNS across buckets.
- **Φ_F-tightness check** (ties in the cut-pressure theory): per critical net,
  does the gap_meter (cheap residual flow / Φ_F) predict WHERE ĉ is trustworthy
  vs where the router reroutes and Δ stays small despite high static demand?

## Controls (falsification-first)

- **Negative control**: shuffle `ĉ(n)` across nets → correlation must collapse.
- **Cell-delay control**: also report `Δ` decomposed into wire-delay vs
  cell/slew-delay change; if Δ is dominated by non-wire effects, the thesis
  mechanism is wrong even if Δ is large.
- **Non-critical nets**: same correlations; expect signal but lower stakes.
- **Iso-HPWL**: where possible, compare placements with matched HPWL but
  different congestion (reuse the `placement/` HPWL-close variant tooling).

## Decision criteria

- **PROCEED** if, on critical nets across ≥2 designs: `corr(detour, Δ) > ~0.4`,
  Δ is a material fraction of WNS/TNS, AND at least one cheap `ĉ` predicts
  detour/Δ with rank correlation clearly above the shuffled control.
- **PIVOT** if Δ is dominated by cell/slew/buffering (not wire), or no cheap ĉ
  beats the shuffled control (then static congestion can't anticipate detour →
  fall back to a bounded per-critical-net residual-flow emulator, or drop the
  thesis).

## Deliverable

`research/artifacts/exp1/<design>_detour_gap.csv` (one row per net) + a short
notes file with the four correlation numbers, the Δ-decomposition, and the
PROCEED/PIVOT call. No new placer code until this gate passes.

## Open infra questions to resolve first

- Confirm the Xplace timer can ingest routed parasitics (SPEF path in
  `tool/timer.py` / `GPUTimer.update_rc_spef`) for the chosen ICCAD2015 design;
  if not, use the detour-scaled-RC proxy in step 4 and note the approximation.
- Confirm CUGR/GGR produces per-net routed length on ICCAD2015 DEF/LEF.
- Decide critical-net set size K (start ~ top 1% endpoints).
