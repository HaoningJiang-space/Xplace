# Results log — route-aware timing (companion to ROADMAP.md / INSIGHTS.md)
Last updated 2026-06-16. Honest, with caveats. To be codex-reviewed as results firm up.

## R0. Infra (done)
- Xplace built + ICCAD2015 timing run (superblue4 placement-time late WNS/TNS −6.99/−7091 ns). (ICCAD2015 = timing-only, not routable → not the substrate.)
- ORFS data engine on moe-server (no docker): full place→route→OpenRCX SPEF→STA. gcd + aes (nangate45) + aes (ASAP7) routed with SPEF.

## R1. Oracle-gate pilot — aes/nangate45 — FIRST VALID POSITIVE (Gate A + causality)
Methodology fix vs the invalid gcd pilot: PRE baseline now applies platform `set_wire_rc` (per-layer R/C) BEFORE `estimate_parasitics -placement`, so the Steiner baseline has nonzero RC (15023/15738 nets nonzero). Unit = driver→sink arc; 38,000 arcs matched PRE↔POST.
- **Residual exists:** routed wire-cap ~32% above Steiner baseline (27,203 vs 20,658 fF).
- **Gate A — beyond RUDY (defeats "congestion proxy"):** Spearman(residual, Δelmore) = **0.78**; partial controlling for RUDY = **0.745** (detour 0.80→0.766). RUDY β small (−0.16) in OLS. On **critical arcs** (worst-20% slack, n=7292): rho≈0.61, partial|RUDY≈**0.58**.
- **Causality (route-seed variance) — placement-controllable, NOT a routing lottery:** same placement re-routed with 3 seeds → SPEF cap **bit-identical** (CV≈2e-16, pairwise Spearman=1.000). On aes the routed-RC is a deterministic function of placement.
- **Oracle timing delta** (Steiner-RC vs true routed-RC): ΔWNS≈+0.05 ns, ΔTNS≈+1.40 ns (here Steiner is *pessimistic*; direction varies by design — magnitude is the point).
- Scripts (parametrized): `/data/ziheng/wzh/oracle_gate/scripts/`.

**Caveats:** aes is std-cell-only → modest magnitude. This is Gate A + seed-causality only; Gate B (utility: inject into placement → improve post-route) NOT yet done (needs Xplace↔ORFS bridge, currently blocked). Seed-causality was clean *because aes routes with 0 DRC* — MUST re-verify on a congested macro design.

## R1b. Second datapoint — ibex/nangate45 (STRONGER, thesis-expected direction)
Via the Open3DBench task (Drive download blocked by server's Google firewall → used the bit-equivalent ORFS-resident ibex, gate-level). 37294 arcs.
- **Gate A:** Spearman(residual, Δelmore) = **0.866**; **partial|RUDY = 0.775**. Critical arcs: ρ=0.787, partial|RUDY=**0.679**. (Stronger than aes.)
- **Causality:** route-seed variance → residual Spearman **1.000, CV 0%** → entirely placement-driven (2nd confirmation).
- **Oracle delta:** ΔWNS −0.078 ns, **ΔTNS −873 ns** — here Steiner is *optimistic* (routing makes timing WORSE = the thesis-expected direction; aes was opposite). Direction varies by design; residual+correlation robust across both.
- set_wire_rc fix confirmed on nangate45 (PRE 27351 / POST 37844 fF).

**INFRA: server firewalls ALL Google IPs** (Drive/Google blocked; github OK). Google-hosted downloads impossible here; use github or on-server data. Open3DBench Drive `_3D.v` netlists unreachable, but its designs == ORFS-resident NanGate45 designs (synthesize once).

## R2. C3PO-aligned ASAP7 substrate
- **aes ASAP7 routed** (= C3PO's aes_cipher) — full SPEF, 0 DRC. First ASAP7 + C3PO-design datapoint (oracle gate runnable on it directly).
- **ariane133 ASAP7:** TILOS netlist+enablement wired; synthesizes (133 sram macros). Blocker = legacy flat macro placer too slow for 133 macros. **Unlock = synthesis-free + fixed-macro path** (TILOS gate-level netlist + TILOS 2020 enablement + pre-placed-macro DEF, used self-consistently) → skip synthesis AND macro placement → place std cells → route → SPEF. (Don't mix with ORFS asap7 2021 platform — cell/name mismatch.)
- mempool ASAP7: only Cadence scripts upstream (needs OpenROAD config from scratch) — low priority. IWLS FPU/mc_top/DES/i2c: not on box; small, add as asap7 designs cloned from aes config.

## R3. Bridge (Xplace↔ORFS) — ✅ UNBLOCKED (2026-06-17)
The cross-session "segfault in `gpdb.setup()`/`preprocess_design_info`" was **not an Xplace bug — it was a wrong-LEF data error.** RelWithDebInfo rebuild of io_parser + gdb pinpointed it exactly: SIGSEGV in `Cell::width()` (`_type->width`, `Cell.h:135`) called from `addCellNode(cell_id=0, "FloatFix")` (`GPDatabase.cpp:36`) in the FloatFix loop (`setupNodes:283`). cell 0 = `PHY_EDGE_ROW_0_Left_22`, master `TAPCELL_X1`, `SOURCE DIST` (a physically-generated tap cell) → master never resolved → null `_type`.
**Root cause:** `gcd.json` loaded `NangateOpenCellLibrary.macro.lef` (no tap/fill cells) instead of ORFS's `NangateOpenCellLibrary.macro.mod.lef`, which defines `TAPCELL_X1` + fills. **Fix = use the `.mod.lef`.** After the swap: `gpdb.setup()` completes and **all 20 gpdb tensor accessors return OK** (coreInfo/node/pin/net tensors, hyperedge_info, node2pin, region_info, …). The ORFS NanGate45 DEF/LEF now fully materializes into Xplace's tensor representation.
**Implication:** the replace-GP harness (Gate B / Exp3) is now viable. Still-true caveats from codex: feed Xplace a *placement-input* DEF (not a routed one) and preserve instance/net names exactly through the round-trip (`Database.cpp:22-33` strips backslashes/spaces). Defense-in-depth TODO: guard `addCellNode` against null `ctype()` so an unresolved master warns instead of segfaulting. io_parser.so on the server is currently the RelWithDebInfo build (functionally identical, has symbols).

**ROUND-TRIP VERIFIED end-to-end (2026-06-17):** `python main.py --custom_json gcd.json --load_from_raw True --detail_placement True` → **Xplace places the gcd NanGate45 design** (GP+LG+DP, HPWL 1.068e4, RC=0) and writes a complete DEF (480 COMPONENTS / 54 PINS / 507 NETS). **OpenROAD reads it back: 480 insts, 0 unplaced, `global_route` OK.** So the full thesis substrate — *Xplace places an ORFS design → OpenROAD routes that placement* — works; names round-trip cleanly (gcd has no escaped names). This is "what global placement does first," verified.
**Scales to a real design:** exported aes's placement-input DEF from ORFS `3_place.odb` (`write_def`, 13858 components) → **Xplace places aes** (GP+LG+DP, HPWL 7.45e5, RC=0, ~10s) → wrote `placement_aes_dp.def`. Inputs live at `/data/ziheng/wzh/bridge/{gcd.json,aes.json,aes_place_input.def}`. Substrate confirmed beyond the toy.

## R4. Benchmarks available
- ASAP7 (C3PO-matched, primary): aes (done), ariane133/136 (synthesis-free path), via TILOS MacroPlacement (`/data/ziheng/wzh/MacroPlacement`).
- NanGate45 (2D breadth): gcd/aes done; Open3DBench (`/data/ziheng/wzh/Open3DBench`) adds ariane/bp_*/swerv/ibex/jpeg gate-level netlists (download in progress).

## R2b. ASAP7 ariane133 macro gate — two dead-ends, then a pivot (2026-06-17)
- **Detailed-route blocked (DRT-0073):** `sram_asap7_16x256_1rw` LEF has all `rd_out[*]` pins as 24nm×24nm M4 squares **exactly on the macro left edge (x=0.000)**; TritonRoute can't synthesize a legal on-track access point for `rd_out[15]` (topmost) on every macro instance → detailed route aborts. This is a vintage-2020 academic-LEF pin-access defect, not a routing-layer-range issue. Fighting it = rabbit hole.
- **GR-based residual substitute — REJECTED as the macro datapoint (methodology honesty):** ran `estimate_parasitics -global_routing` vs `-placement` on the same `3_groute.odb`. Three fatal confounds: (1) `3_groute.odb` has only GR *guides*, no detailed wire → `getWire()` length = 0 → **the detour observable doesn't exist**; (2) arc key (net,driver,sink) is non-unique → many-to-many join corruption (340k→492k rows); (3) GR cap came out ~3× *lower* than Steiner (median ratio 0.328) — counterintuitive, unexplained, likely an estimator/layer-assumption artifact. GR cannot give a credible beyond-RUDY Gate-A. Not reported.
- **PIVOT → ariane133 / NanGate45 (ORFS):** same design C3PO uses, but with `fakeram45_256x16` macros that detailed-route cleanly. Consistent with the existing aes/ibex NanGate45 positives. Hit the ORFS-vs-OpenROAD version skew (`rtl_macro_placer` absent in this 2.0-12381 build); fixed by forcing the legacy `macro_placement` branch **seeded with a `global_placement`** (MPL-0099 needs a GP seed). Macro placement now running → full flow to 6_final.spef.

## R5. Substrate decision — Xplace IS the placer (re-anchored 2026-06-17)
Re-grounded on `route_aware_timing_thesis.md` + `exp1_detour_timing_gap.md`: the gate is **Xplace place → route → measure Δ with the Xplace timer**, NOT the OpenROAD-placer oracle gate I had drifted into (that stays only as tool-independent premise validation).
- **Infra finding (decisive):** Xplace's **GGR segfaults on ICCAD2015 superblue** at `Init GRDatabase` (RC=139) — the timing-oriented LEF lacks routing-grid/cut-layer info. `D_place` from the GPUTimer works (late WNS/TNS −6.96/−7508), but the in-tree router can't route it (CU-GR also failed earlier, 0 cut layers). **ICCAD2015 = timed-but-unroutable; ISPD = routable-but-untimed; NanGate45/ASAP7(ORFS) = both.** `D_route` ground truth requires real routing → the timed benchmark can't supply it.
- **Decision (user-confirmed):** **Xplace-place + OpenROAD-route on NanGate45/ASAP7.** Xplace places an ORFS design via the now-unblocked bridge → OpenROAD routes that Xplace placement → routed SPEF → `D_place` vs `D_route`. Keeps Xplace as the placer (the goal), gives a routable + C3PO-aligned PDK.
- **Fidelity guardrails for this substrate** → `research/road_map/FIDELITY.md` (六 distortion sources; centerpiece = D1 same-timer Δ, D2 anti-gamed controllable-only gradient with router recalibration).

## R6. codex review of FIDELITY.md (2026-06-17) — integrated
codex (adversarial, first-principles) verdict: "pointed right, but D1/D2 are not yet contracts." Integrated into FIDELITY.md:
- **Two missing distortions added:** D7 **flow-mutation** (routing adds CTS/resize/fill → Δ not pure parasitic — exactly the ariane GR netlist-mismatch trap) and D8 **gradient-reality** (accurate Z ≠ useful ∇Z; router response is discontinuous → finite-difference-validate the FORCE, not just the value). Plus D9 arc-key uniqueness.
- **D1 hardened to a contract:** SPEF round-trip must pass 100% net/pin match + ~100% nonzero RC (unmatched→zero-RC fakes a better D_route) + unit sanity + coupling policy + Xplace-timer↔OpenSTA agreement on fixed parasitics.
- **D2b controllability redefined:** CV≈0 only proves determinism, NOT controllability. Need across-placement variance ≫ route-seed variance + finite-difference sensitivity.
- **Non-incrementality** is earned by Exp 3, not framing (Gate A ≠ Gate B).

## R7. First post-route-bound gap on an Xplace placement + the injection-point finding (2026-06-17)
Back-end harness (`research/server/oracle/xplace_backend_gr.tcl`) on Xplace-placed aes: D_place (Steiner) TNS **−54.9** ns → D_route (post-GR, same CTS netlist) TNS **−60.1** ns. **Routing degrades TNS ~5.2 ns** — the first post-route-bound timing gap measured on an *Xplace* (not OpenROAD) placement (D6-correct).
- **Architectural finding (changes the oracle implementation):** Xplace's plain-GP wirelength gradient `merged_wl_loss_grad` takes only a binary `net_mask`, **NOT** per-net weights. Per-net weighting lives ONLY in the timing-WL term `merged_wl_loss_grad_timing(net_weight, timing_pin_weight)` (gated on `ps.enable_timing`, driven by the GPUTimer). Confirmed empirically: `--net_weight_file` on plain GP matched 13703/14547 nets but produced an **identical placement** (HPWL 7.445400E+05 unchanged) — the weights were never consumed.
- **Implication:** the route-aware force (oracle AND the eventual predictor) must enter via the timing-WL term. This is the thesis's true injection point: drive `timing_pin_weight`/`net_weight` from the route-aware model. The oracle = drive them from the TRUE routed criticality, bypassing the GPUTimer's estimated-RC STA. Building this hook = building the actual thesis mechanism.

## R8. Oracle-timing arm — first result (2026-06-17): placement-time gain does NOT survive routing
Oracle hook (codex-reviewed): static per-pin `timing_pin_weight = scale·crit_n` from the baseline's TRUE routed criticality (the perfect-predictor net-weighting), enabled in the timing-WL term, no real STA. Matched 13703/14547 nets. aes, scale 0.1:

| arm | D_place(Steiner) TNS | D_route(post-GR) TNS | After-DP HPWL |
|---|---|---|---|
| baseline (plain Xplace) | −54.9 | **−60.1** | 7.4454e5 |
| oracle (scale 0.1) | −48.7 | **−63.5** | 7.5149e5 |

**SCALE SWEEP (the fuller, corrected picture):**

| scale | After-DP HPWL | D_place TNS | D_route(GR) TNS | wire-cap fF |
|---|---|---|---|---|
| 0 (baseline) | 7.445e5 | −54.9 | −60.1 | 19161 |
| 0.1 | 7.515e5 | −48.7 | −63.5 | 19258 |
| **0.3** | 7.646e5 | −48.5 | **−51.2** | 19400 |
| 1.0 | 7.992e5 | −46.3 | −60.5 | 19924 |

- **At scale 0.3 the oracle IMPROVES post-route TNS by ~8.9 ns (−60.1 → −51.2, ≈15%)** at near-iso wire-cap (+1.2%). So a perfect routed-criticality signal, at the right strength, **does** have placement-controllable post-route headroom (a Gate-B-positive signal). The earlier single scale=0.1 point ("oracle hurts") was misleading.
- **Non-monotonic in scale:** too weak (0.1) perturbs without helping; sweet spot (0.3) helps; too strong (1.0, HPWL +7%, wire-cap +4%) over-tightens → congestion cost cancels the gain. D_place TNS improves monotonically; D_route does NOT — exactly the placement-time-vs-post-route divergence the thesis targets. Implies the route-aware weighting must be *scheduled/tuned* (ParamScheduler's job).

**STILL-OPEN CAVEATS:** (1) net-weighting oracle, not the RC-correction oracle (codex distinction); (2) stale criticality (baseline route) — yet it still helped, suggesting routed-critical nets are fairly stable; (3) NOT iso-congestion (wire-cap rose) — must compare against ESTIMATED-criticality weighting at matched WL to isolate the *route-awareness* value (vs just "more timing weighting"); (4) single design (aes), one GR pass.

## R9. Route-awareness isolation (2026-06-17): routed ≈ estimated criticality on aes — a clarifying partial-negative
Estimated-criticality (Steiner/D_place slacks) arm vs the routed (oracle) arm, matched scale:

| scale | routed(oracle) D_route TNS | estimated D_route TNS |
|---|---|---|
| 0 (base) | −60.1 | −60.1 |
| 0.1 | −63.5 | −61.5 |
| **0.3** | **−51.2** | **−51.8** |
| 0.5 | — | −53.7 |

**At the sweet spot routed ≈ estimated (−51.2 vs −51.8).** So the ~15% post-route TNS gain is from **timing-weighting per se, NOT route-awareness.** The true routed criticality added ~nothing over the cheap estimate — for the net-weighting mechanism, on this design.
**Why this does NOT kill the thesis (both testable):**
1. **aes is uncongested** (40% util, 0 DRC) → routed-criticality ≈ estimated *by construction* (little routing distortion). Route-awareness can only pay where routed **diverges** from estimated → **congested/macro designs** (ariane133; or high-`target_density` aes). The critical-net SETS already overlapped here (same worst nets `_00046_`/`_08330_`/`_09017_`), confirming low divergence.
2. **Net-weighting uses only the criticality RANKING** (similar for both); the thesis mechanism corrects per-arc **delay magnitudes** — info net-weighting structurally cannot exploit. The faithful **RC-correction oracle** is the real test.

## R10. Congested-substrate divergence (2026-06-17): the thesis premise, validated
Built the full congested substrate: Xplace places **ariane133** (167615 cells, **132 fakeram45 macros fixed**, 152343 movable std cells, RC=0) → ariane back-end (+fakeram45 LEF/lib, CTS+GR). Baseline: D_place(Steiner) TNS −98413 → D_route(GR) TNS −3119 (Steiner wildly pessimistic on long macro nets at M3; routing recovers).
**Estimated-vs-routed criticality divergence (the key signal):**

| design | Spearman(est,routed) | top-200 crit Jaccard | est crit nets | routed crit nets |
|---|---|---|---|---|
| aes (uncongested, 40% util) | 0.948 | 0.613 | 9923 | 10707 |
| **ariane133 (132 macros)** | **0.581** | **0.003** | 117813 | 12918 |

**On the congested macro design, estimated and routed criticality almost entirely disagree (top-200 Jaccard 0.003 vs 0.61 on aes).** Placement-time timing flags ~117k nets critical (M3 pessimism) while only ~13k are truly routed-critical → a placer optimizing estimated criticality targets the WRONG nets. This is the thesis premise made quantitative: **placement-time timing badly mispredicts post-route criticality where there is congestion, and route-awareness carries real different information.** The uncongested-aes null (R9) was expected. (Caveat: the estimated pessimism is partly the crude Steiner-M3 RC model + a timing-poor baseline placement; but routed criticality is clearly the better target.)

## R11. ★ Utility result on ariane133 (2026-06-17): route-awareness gives ~20% post-route TNS headroom that estimated criticality cannot
Routed-criticality (oracle) vs estimated-criticality net-weighting, Xplace re-place → ariane back-end (CTS+GR). Baseline post-route TNS −3119:

| arm | scale | post-route TNS | vs baseline | wire-cap fF |
|---|---|---|---|---|
| baseline (plain) | — | −3119 | — | 606745 |
| estimated-criticality | 0.3 | −3100 | −0.6% | 610055 |
| estimated-criticality | 1.0 | −3011 | −3.5% | 598448 |
| **routed-crit (route-aware oracle)** | 0.3 | −2820 | −9.6% | 567968 |
| **routed-crit (route-aware oracle)** | **1.0** | **−2401** | **−23.0%** | **542113** |

- **Route-awareness headroom = (estimated −3011) → (routed −2401) ≈ 20% post-route TNS**, on the congested macro design. Estimated criticality (= a normal timing-driven placer) barely helps (−3.5%); routed criticality gives −23%.
- **Not bought with congestion (clean):** the routed arm has the LOWEST wire-cap (542113 vs baseline 606745, −11%) — it improves timing AND reduces routing. Estimated raises wire-cap. So this is not the usual WL-for-timing trade.
- **The Steiner-trap, shown:** routed arm's D_place(Steiner) TNS is hugely *worse* (−204k) yet post-route *best* — optimizing the pessimistic placement-time estimate is misguided; optimizing true routed criticality wins post-route. That contrast is the thesis.
- **Contrast with aes (R9):** uncongested → routed≈estimated (no headroom); congested → routed≫estimated (20% headroom). Route-awareness pays exactly where R10's divergence (Jaccard 0.003) said it would.

**This is the ORACLE upper bound** (uses true routed criticality from the baseline route): it proves the placement-controllable post-route headroom EXISTS and is large on congested designs. A real predictor captures some fraction; that is the thesis to build.

### R11-AUDIT (codex, 2026-06-17) — R11 OVERCLAIMS; downgraded to a smoke test
codex adversarial audit. **Defensible claim only:** "a static net-weight oracle from baseline routed slack improves ONE ariane133 GR-timing run." It does NOT yet show route-awareness, the thesis mechanism, or a deployable placer. Confounds to fix before any claim:
1. **Estimated arm is a STRAWMAN** — it used the broken Steiner-M3 criticality (117k "critical" nets, R10). A fair baseline = tuned `set_wire_rc` + **top-K / WNS-relative criticality matched to the oracle's ~13k cardinality** + real Xplace `--timing_opt` in-loop re-timing + scale/force-norm sweep. "Normal timing-driven placer" was wrong wording.
2. **Force not matched** — routed weighted ~13k nets, estimated ~117k; at the same `scale` the gradient norms differ, so the win may be *focus*, not route-awareness. Must match ‖g_timing‖ or Pareto-tune per arm.
3. **Single seed / single GR pass** — need ≥5 placement × 3 route seeds, paired, mean/CI.
4. **GR not SPEF** — the −23% may vanish under detailed-route OpenRCX SPEF + coupling + repair.
5. **Metric weak** — %TNS on a wildly-violating design (baseline −3119, Steiner −98413) may just redistribute violations. Report absolute **WNS, #violating endpoints, Fmax/period sweep, endpoint overlap, path win/loss**, and routed-WL/overflow/DRC (not just wire-cap).
6. **Label leakage** — oracle uses test-instance routed labels → upper bound ONLY; need provenance hashes.
7. **Mechanism** — net-weighting tests a criticality *ranking*, not the per-arc RC-correction the thesis claims.
**Code bugs flagged (to fix):** headerless-CSV skips one net; exact net-name match vs Xplace name-stripping; missing-file silently disables the arm; the committed GR back-end is hard-coded to aes (ariane run not reproducible from the committed harness). `net_weight` is dead in the CUDA timing kernel — only `timing_pin_weight` matters (docs corrected).
**Strongest reviewer rejection:** "R11 compares a test-label oracle against a known-bad Steiner/M3 baseline on one GR run and calls the delta route-awareness." → R11 is reframed as an oracle *upper-bound smoke test* only.

## R12. ★ FAIR force-matched comparison (2026-06-17): R11's 20% was mostly the force confound
Per R11-audit, re-ran routed-vs-estimated with `--oracle_topk 13000` (both arms weight the SAME top-13k nets at UNIFORM weight → identical cardinality + force magnitude; only the *ranking* differs). ariane133, baseline post-route TNS −3119:

| arm | scale | post-route TNS | wire-cap |
|---|---|---|---|
| baseline | — | −3119 | 606745 |
| estimated-crit (top-13k) | 0.3 | −2972 | 592697 |
| **routed-crit (top-13k)** | 0.3 | **−2882** | 564601 |
| estimated-crit (top-13k) | 1.0 | −2685 | 564960 |
| **routed-crit (top-13k)** | 1.0 | **−2480** | 547576 |

**Once force-matched, the routed-vs-estimated gap collapses from ~20% (R11) to ~3-8%**: at MATCHED scale, routed beats estimated by +3% @0.3 (−2882 vs −2972) and +8% @1.0 (−2480 vs −2685), **always at lower wire-cap**. (Comparing across scales is unfair — est@1.0 looks better than routed@0.3 only because scale 1.0 is the stronger operating point; at equal scale routed wins.) **So most of R11's apparent 20% was the cardinality/force confound codex flagged**, but a **real, consistent, directionally-correct ~3-8% route-awareness advantage survives** force-matching, with lower wire-cap.
**Honest conclusion:** route-awareness via **net-weighting** is real but **modest** (~3-8% TNS). Net-weighting only exploits the criticality *ranking* (routed vs estimated rankings overlap a lot even on ariane once you look past the Steiner-M3 pessimism). **The bigger lever should be the RC-CORRECTION mechanism — correcting per-arc delay *magnitudes*, not just *which nets rank critical*.** That is the decisive next experiment; if it too yields only single-digit % over a fair estimated baseline, the thesis is incremental and must be reframed. (R11 stands only as an oracle smoke test; R12 is the fair, honest number.)

## R13. RC-correction oracle — BLOCKED on GPUTimer-on-NanGate45 (2026-06-17)
The true RC-correction mechanism (correct per-arc wire RC → propagate through STA → routed criticality, in-loop) requires the Xplace **GPUTimer** running on the design. GPUTimer's wire-RC model is `wirelength × wire_{R,C}_per_micron` (`timing_opt.py:18-20`) — so the RC-correction hook would be a per-net effective-length/RC multiplier = routed/estimated. **But the GPUTimer SEGFAULTS on the NanGate45 bridge design:**
- First blocker (fixed): Xplace's SDC tcl reader chokes on `current_design ariane` ("too many arguments") → use a stripped SDC (clock only).
- Real blocker: after the SDC fix, it crashes in `create_gputimer` (right after PlaceData). Adding a `write_verilog`-exported netlist makes it crash EARLIER (at load) — so the timing path has a NanGate45-bridge assumption gap (analogous to the io_parser/gpdb crash). Needs a focused gputimer RelWithDebInfo + gdb debug (deferred — not a quick patch).
**Consequence:** in-loop RC-correction can't run yet. The honest current best is R12 (force-matched net-weighting route-awareness ≈ 3-8%). Note: R12's routed arm already uses routed-RC-derived *criticality* (the RC-correction's effect on the ranking); the unobtained piece is RC-correction's effect on per-arc gradient *magnitude* propagated through in-loop STA.

### R13-FIXED (2026-06-17): GPUTimer now runs on NanGate45 bridge designs
RelWithDebInfo rebuild of `gputimer` + gdb pinpointed it: SIGSEGV at `GTDatabase.cpp:106` `liberty_cell->ports_map_[pin_macro_name]` with `liberty_cell` NULL — **the fakeram45 macros had no liberty** because only `NangateOpenCellLibrary_typical.lib` was passed. **Fix (data, not code): pass ALL libs via the `libs` LIST** (`io_parser` reads multiple liberty files into cell_libs_, `Database.cpp:106-114`); `lib`/`early_lib`/`late_lib` take precedence and must be removed. With `libs:[Nangate_typical, fakeram45_256x16]` + a stripped SDC (no `current_design`), **Xplace `--timing_opt` runs on ariane/NanGate45** (GP iterates, reports early/late WNS/TNS). (`GTDatabase.cpp:104-106` should still get a null-`liberty_cell` guard as defense-in-depth.)
**This unblocks BOTH:** (1) the **RC-correction oracle** (inject a per-net effective wire-length/RC multiplier = routed/estimated into the GPUTimer's `wirelen×R/C_per_micron` model → routed-corrected delays propagated through in-loop STA), and (2) the **fair estimated baseline = real Xplace `--timing_opt`** (in-loop re-timing, what codex demanded — not the static Steiner-M3 strawman). NOTE: initial late TNS is wildly large (−2.6e7) → the `wire_{R,C}_per_micron` defaults likely need NanGate45-appropriate values (calibrate before trusting absolute timing).

## R14. PATH-BASED timing-driven placement works on the bridge + calibrated (2026-06-17)
The net-based oracle (R11/R12) was a stopgap because GPUTimer was blocked. With GPUTimer unblocked (R13), the REAL Xplace timing path is **path-based** (path-informed pin weighting: `report_criticality_threshold` + `explore_path` walk critical paths, accumulate per-pin weights — closer to Efficient-TDP than net-weighting).
- **Calibration:** default `wire_resistance_per_micron=2.535` is ICCAD-tuned and ~700× too high for NanGate45 (metal3 R≈3.6e-3 ohm/µm) → wild TNS (−2.6e7). With `--wire_resistance_per_micron 0.0036` (C default 0.16fF/µm ≈ NanGate45), **timing is sane: ariane final late WNS/TNS −4.4/−6868 ns** (4ns clock), and **timing-driven GP works** (late TNS improves −18471→−6868 as overflow drops). So `--timing_opt` (path-based, estimated RC) is now a valid FAIR baseline on the bridge.
- (TODO: cross-check GPUTimer vs OpenSTA on a fixed placement for D1 fidelity; the 0.0036 is a single-layer proxy — a routed-layer-blended value is better.)

## R15. ★ RC-correction in Xplace (path-based) — FIRST RESULT: it HURT (honest negative)
Implemented route-aware RC-correction IN XPLACE (not Efficient-TDP): per-net wire-RC multiplier (routed/est detour) injected into the GPUTimer's FLUTE `edge_wl` (`rctree.cpp` + `set_net_rc_mult` + `--rc_mult_file`), so the path-based timer computes routed-corrected RC. ariane133, `--timing_opt` (wire_R 0.0036), back-end post-route:

| arm | xplace late TNS | post-route TNS | wire-cap |
|---|---|---|---|
| no-timing (ar_base) | — | −3119 | 606745 |
| **estimated `--timing_opt`** (baseline) | −6867 | **−2600** | 544106 |
| **route-corrected `--timing_opt`** | −7355 | **−2817** | 557189 |

**RC-correction made post-route TNS WORSE (−2600 → −2817, ~8%) and raised wire-cap.** Estimated `--timing_opt` is best (it already improves −3119→−2600, 17% over no-timing). So the route-aware RC info, injected this way, HURT.
**Likely confound (must fix before concluding):** the multiplier is **doubly-stale** — derived from the `ar_base` *no-timing* placement's route, then applied to a *different* (timing-driven) placement that further moves cells. The routed/est ratio is for the wrong placement → mis-guides the timer. Also per-net (not per-arc), and pulling baseline-detoured nets tighter raised congestion (wire-cap↑). (Infra note: GPU-0 was contended by the user's PPoPP `async_sched` job → placement ran 8× slow but result is valid; use GPU 1.)
**Honest read:** as a first cut, RC-correction does not help — consistent with the recurring pattern (R11 low-scale, R12 modest) that injecting routing info to pull nets can backfire via congestion. Next: kill the staleness (iterative/matched multiplier from the corrected placement's OWN route), per-arc granularity, and codex-audit. If it still doesn't beat estimated `--timing_opt` after that, the mechanism is likely incremental → reframe.


## R16. Step-1 verification: C2 ruled out, C1 (lever mismatch) CONFIRMED
Matched (fresher) multiplier made post-route WORSE, monotonically: baseline -2600 -> stale-mult -2817 -> matched-mult -2992 (wire-cap rising each step). Staleness was NOT the cause; the route-aware timing-pull is actively harmful and worse with better routing info -> congestion-detour delay is not HPWL-reducible (ANALYSIS_R15.md). Next: route the detour component to the routability lever (--use_cell_inflate / spread), not the timing pull.

## NEXT (unblocked 2026-06-17) — the decisive PATH-BASED RC-correction experiment
1. **RC-correction injection:** inject a per-net effective-wire-length (or R/C) multiplier = routed/estimated detour into the GPUTimer's `wirelen×R/C_per_micron` model → the path-based timer optimizes ROUTED delay. (Hook in `timing_opt.py` update_rc / the per-net length passed to `create_timing_rawdb`.)
2. **Compare (path-based, force/seed-matched, WNS/Fmax/#viol metrics):** plain | `--timing_opt` (estimated RC, fair baseline) | RC-corrected `--timing_opt` (routed RC) → post-route TNS. If RC-correction beats the fair path-based baseline by >single-digit %, the thesis mechanism is validated; else reframe.
3. Multi-case via Open3DBench DEFs (no synth).

## IN FLIGHT / NEXT (2026-06-17) — the FAIR experiment (per R11-audit)
Clean design (codex): arms = {plain | fair estimated (top-K matched to oracle cardinality + force-norm matched, and/or real Xplace `--timing_opt`) | routed-criticality oracle | RC-residual oracle}, on the SAME fixed designs, **force-norm matched + post-route routed-WL/DRC matched**, detailed-route SPEF + one STA engine, **≥5 placement × 3 route seeds**, metrics = **WNS / #violating endpoints / Fmax / TNS** (not just %TNS), + shuffled-criticality and top-K controls. Then the learned predictor (no test labels) must recover a fraction of the oracle gain.
- **bp_fe_top** (2nd macro design) flow running → repeat the divergence (R10) + fair arms.
- Back-end to also report WNS + #violating-endpoints + routed-WL/overflow; fix the flagged code bugs; commit a design-parametrized back-end (not aes-hardcoded).
- **Oracle arm v2 (corrected):** add an "oracle timing" hook — enable the timing-WL term with `timing_pin_weight`/`net_weight` set from the baseline's routed criticality (no GPUTimer STA needed) → Xplace re-place → back-end → compare post-route TNS vs the −60.1 baseline at matched GR-WL. Codex-review the hook (it IS the thesis injection mechanism) before trusting results.
- **Substrate de-risked:** Xplace-place → OpenROAD-route round-trip VERIFIED on gcd (above). Foundation for the oracle experiment is in place.
- **★ Decisive next experiment = true-residual ORACLE placement** (codex's cheapest falsifier, upper-bounds the thesis): scale the verified round-trip to a real/timed design (aes or ariane NanGate45) → inject the ACTUAL routed-RC residual (perfect-predictor oracle) → short late-stage placement update → re-route same flow/seed → post-route WNS/TNS vs Xplace-Timing & C3PO/RUDY at matched routed-WL/DRC. If a PERFECT predictor can't beat route-seed noise, STOP.
- Prereqs still open: D1 contract check (which timer measures Δ — Xplace GPUTimer vs OpenSTA; single-corner libs) + D7 unmutated-netlist round-trip. Leaning OpenSTA-for-both for the gating eval (authoritative, sidesteps Xplace-SPEF ingestion risk); Xplace timer is for the in-loop gradient later.
- **ariane133/NanGate45 OpenROAD oracle gate** still routing in background — demoted to tool-independent mechanism cross-check.

## READING SO FAR
Gate A + placement-controllability look **positive on aes (std-cell)**; the thesis stands or falls on (1) the same holding — ideally STRONGER — on the **macro/congested** design with seed-causality intact, and (2) Gate B utility (needs the bridge). No SOTA/win claim yet; this is mechanism+causality evidence, not the placement-improvement result.

## R19 — ★ DE-CHEAT SUCCEEDS: online fixed-point iteration recovers the oracle (no routing-first)
The +20% was an oracle (routed criticality requires routing first). Fixed-point iteration removes
the cheat: cold-start from ESTIMATED criticality, then each placement uses the PREVIOUS route's
routed criticality (available at place time). ariane, same back-end:
| iter | criticality source | post-route TNS |
|---|---|---|
| k0 | estimated (pre-route cold start) | −2685 |
| k1 | k0's ROUTED criticality (online, non-cheat) | **−2429** |
| oracle (cheat upper bound) | baseline route criticality | −2401 |
**ONE non-cheating iteration recovers the oracle within ~1% (−2429 vs −2401), +9.5% over the est
cold start.** This resolves the circularity: a few place→route→re-weight rounds (industrial-style,
deployable) claim essentially the full headroom. The +20% is REAL and ONLINE-achievable — not an
oracle artifact. This is the first deployable positive result. (k2–k4 confirm fixed-point stability.)

### R19 full trajectory (k0–k4) + oscillation finding
| iter | criticality src | post-route TNS | HPWL |
|---|---|---|---|
| k0 | estimated (cold) | −2685 | 2.581E7 |
| k1 | k0 routed | −2429 | 2.473E7 |
| k2 | k1 routed | **−2421** (≈oracle −2401) | 2.470E7 |
| k3 | k2 routed | −2499 | 2.471E7 |
| k4 | k3 routed | −2485 | 2.472E7 |
Online iteration recovers the oracle within ~1% (best k2 −2421 vs −2401), +9.8% over est cold start,
+6.9% over standard `--timing_opt` (−2600). MILD OSCILLATION after k2 (moving target: re-placing
shifts the route → shifts criticality). FIX: EMA-damp the criticality across iterations (as Xplace's
own `--timing_opt` EMA-damps), or best-sol track (take k2). Deployable, non-cheating positive.
NEXT (SOTA): EMA damping + multi-design + the single-run in-loop version (Approach A) + vs C3PO.

## R20 — ★ MULTI-DESIGN: online route-aware iteration GENERALIZES (bp_fe_top, case 2)
2nd fixed-macro design (Black Parrot front-end, NanGate45, SRAM macros). Fixpoint, iter0 = plain
(no-timing) cold start, iter k uses prev route's routed criticality:
| iter | criticality | post-route TNS |
|---|---|---|
| k0 | none (cold) | −98519 |
| k1 | k0 routed | −81906 (+16.9%) |
| k2 | k1 routed | **−66841 (+32.2% vs cold)** |
| k3 | k2 routed | −72070 (mild oscillation) |
Online route-aware iteration improves post-route TNS by **+32.2%** (best k2) on bp_fe (vs +9.8% on ariane) —
the method GENERALIZES across designs, and the gain is even larger here. (bp_fe bridge: bpfe.json +
xplace_backend_bpfe.tcl; 2_floorplan.odb → bpfe_place_input.def.) NOTE: bp_fe cold = no-timing;
ariane cold = est-timing — to fully match, also measure bp_fe est-timing baseline (TODO). Trajectory
improvement is the generalization signal. Two cases now positive: the online route-aware mechanism is real.

## R21 — ★ MULTI-DESIGN CONTRADICTS: route-aware criticality does NOT generalize (HONEST NEGATIVE)
Proper FAIR comparison (est-criticality net-weight vs routed-criticality net-weight, SAME mechanism
top-13k/scale 1.0, post-route TNS):
| design | est-crit | routed-crit | route-awareness |
|---|---|---|---|
| ariane | −2685 | −2421 | **HELPS +9.8%** |
| bp_fe  | **−63279** | −66841 | **HURTS −5.6%** |
The bp_fe "+32%" reported in R20 was entirely TIMING-vs-NO-TIMING (its cold start was no-timing) —
route-awareness ITSELF hurts on bp_fe. So the R12/R19 ariane positive **does NOT generalize**: routed
criticality beats estimated on ariane but LOSES on bp_fe. The thesis "routed > estimated criticality"
is design-dependent, not universal. This is exactly what multi-case testing must catch (and what a
reviewer/codex would attack). Hypothesis to test: route-awareness helps only where routed criticality
DIVERGES strongly from estimated (ariane Jaccard 0.003, fixed-macro structural detour); on designs
where routed≈estimated, swapping just adds noise + moving-target oscillation → hurts. NEXT: measure
bp_fe routed-vs-est criticality divergence; characterize WHEN route-awareness helps (the real science).

## R22 — ★ INSIGHT: route-awareness value ∝ est-vs-routed criticality DIVERGENCE (explains R21)
est-vs-routed criticality Jaccard (top-13000 critical nets, SAME placement):
| design | Jaccard(top-200 / 2k / 13k) | route-awareness |
|---|---|---|
| ariane | 0.0025 / 0.014 / 0.244 (highly DIVERGENT) | HELPS +9.8% |
| bp_fe  | 0.015 / 0.748 / 0.937 (routed ≈ est) | HURTS −5.6% |
**The contradiction is fully explained:** route-awareness helps in PROPORTION to how much routing
changes the criticality ranking. ariane (132 fixed macros → big structural detour) → routed diverges
hugely → new info → helps. bp_fe (few small SRAMs) → routed≈estimated → no new info, only moving-target
noise → hurts. **Divergence is the predictor, driven by structural (fixed-macro) congestion.**
Coherent framework: *route-aware TDP helps ⟺ routing structurally distorts the criticality ranking.*
**Better method (R23, implementing): SELECTIVE/BLENDED criticality** — trust routed only where it
confidently diverges from estimated (e.g. crit = max(est, routed) or EMA blend), so high-divergence
designs benefit and low-divergence designs fall back to estimated (no harm). Robust across designs.

## R23 — ★★ ROBUST METHOD: normalized-criticality UNION blend generalizes (fixes R21)
Blend = crit_n = max(est_crit_norm, routed_crit_norm), top-13k (critical if EITHER timer ranks it):
| design | est | routed | **blended (norm-union)** |
|---|---|---|---|
| ariane | −2685 | −2421 | **−2390.6** (beats routed AND oracle −2401; +11% vs est, +8% vs --timing_opt −2600) |
| bp_fe  | −63279 | −66841 | **−62045** (beats est; pure-routed REGRESSION −66841 ELIMINATED) |
**Both designs improve, robustly.** Key insight upgrade: est and routed timers each MISS different
true-critical nets; their UNION is more complete than either alone → blend beats pure-routed (and
even the routed oracle) on ariane, and removes the divergence-noise regression on bp_fe. So the
robust route-aware method is NOT "replace est with routed" (R21 fails) but "UNION est+routed
criticality" (complementary information). This generalizes across the divergence axis (high ariane /
low bp_fe). First robust, multi-design positive. (raw min-slack blend failed — must normalize per
timer before union, else dominated by the more-pessimistic timer's scale.)

## R24 — codex adversarial review (gpt-5.5 xhigh): 3 fatal flaws (goal #2)
1. **Baseline collapse**: bp_fe +32% dead (timing-vs-notiming); ariane shrank to 3-8% force-matched;
   weak vs Efficient-TDP (DATE'25 pin2pin path-level). FIX: locked matrix {no-timing, Xplace
   timing_opt, Efficient-TDP-style pin2pin-est, C3PO/RUDY, prev-routed, est∪routed blend} on ≥3
   designs, same budget, ≥5 place × 3 route seeds, iso-congestion. Beat the STRONGEST est/C3PO baseline or reject.
2. **Fixed-point not novel + best-of-trajectory cherry-picking**: place→route→reweight = iterative
   timing closure; reporting best iter k2 (k3/k4 regress) = eval leakage. FIX: predeclare/FREEZE K,
   damping, stopping rule on training designs; report LOCKED final on held-out, not best-of-traj.
   (NOTE: R23 single-shot union is already a fixed 1-iter rule, not best-of-traj — must state this.)
3. **★ Timing fidelity may be an artifact (deepest)**: post-route TNS = GR parasitics (no coupling,
   no detailed route); est timer marked 117k critical vs 13k routed (Steiner-M3 pessimism) → could
   MANUFACTURE the divergence/Jaccard story. FIX: rerun the SELECTED placements through detailed
   route + OpenRCX SPEF (coupling) + fairly recalibrated est timer; recompute Jaccard/WNS/TNS/Fmax/DRC.
   If divergence/gains vanish → just exploiting a bad estimated timer.
   PARTIAL DEFENSE: R22's divergence (0.24/0.94) used OpenROAD `estimate_parasitics -placement` (a
   PROPER est timer), NOT the old Steiner-M3 (R10's 0.003). So R22 ≠ the bad-timer artifact. But the
   detailed-route+coupling fidelity gap is REAL and unaddressed → resolving flaw 3 = the make-or-break.

## R25 — ★ swerv (3rd design) HONEST: frozen scale=1.0 OVER-PULLS (codex flaw-2 confirmed on held-out)
swerv_wrapper (NanGate45, large, TNS scale ~−1.6M ns — much bigger than ariane −2.4k / bp_fe −63k):
| arm | post-route TNS | HPWL |
|---|---|---|
| sw_cold (no timing) | −1600442 | 1.375E7 |
| sw_est (est, scale 1.0) | −1668072 (WORSE than cold) | 1.894E7 (+38%!) |
| sw_routed, sw_union | (running) |
The FROZEN hyperparameters (scale=1.0, K=13000) from ariane/bp_fe **over-pull on swerv**: the timing
net-weight force inflated HPWL +38% → post-route TNS WORSE than no-timing. This is exactly codex
flaw-2 (a frozen rule must transfer to held-out designs — it does NOT here). Root cause: `--oracle_timing_file`
uses a FIXED scale, no auto-calibration; swerv's criticality magnitude/distribution differs → scale 1.0
is mis-calibrated. **FIX (robust): auto-calibrate the timing-force scale to the WL/density gradient
magnitude per design** (as Xplace auto-normalizes route_weight: init = density_grad.max/route_grad.max),
so the frozen RULE is "timing force = fixed FRACTION of WL force", design-invariant. Re-run swerv with
auto-calibrated scale. Honest: route-awareness is moot until the actuation scale generalizes.

## R26 — auto-calibration VALIDATED; swerv is an invalid timing substrate
swerv frac-calibration (vs cold −1600442, scale-1.0 disaster was HPWL 1.894E7 / TNS −1668072):
| frac | HPWL | TNS |
|---|---|---|
| 0.05 | 1.371E7 | −1602397 |
| 0.10 | 1.375E7 | (route incomplete) |
| 0.20 | 1.388E7 | −1600346 |
**(a) --timing_force_frac auto-calibration WORKS**: HPWL no longer balloons (≈cold 1.375E7, vs 1.894E7
at fixed scale=1.0) → the frozen rule "timing force = frac·WL force" is design-invariant (R25 fix
validated mechanically). **(b) swerv is NOT a valid timing substrate**: clock=3.4ns, TNS −1.6M ns
(~a full clock period violated at EVERY endpoint) → grossly over-constrained, timing is placement-
INSENSITIVE (est-timing ≈ cold, flat) — like ASAP7-synfree. swerv dropped as a route-awareness case;
need a 3rd design with SANE, placement-improvable timing (TNS ~k-range like ariane/bp_fe). NEXT:
re-run ariane+bp_fe {est,union} under the FROZEN auto-cal rule (frac=0.1) to confirm union still beats
est design-invariantly (codex flaw-2); find a valid 3rd design (relax swerv clock, or bp_be/ariane136).

## R27 — ★ THEORY: frozen criticality drops the route-response gradient (envelope fails); Level-A built
codex-confirmed first-principles result (IMPLICIT_DIFF_TIMING.md, RELATED_WORK.md), 2026-06-18.
- **The gap (codex CONFIRMED).** Our timing force `κ·∂HPWL/∂x` keeps the routed criticality RANKING
  (κ) but applies it to a route-BLIND geometry gradient, dropping the cross term `(∂T/∂r)(dr*/dx)`.
  The envelope theorem does NOT license this: it kills `∂_rR·dr*/dx` only for the routing objective
  R's own value; timing T≠R, so `∂_pT≠0 ⇒` the route-response term is **generically nonzero** —
  large exactly in the high-divergence regime (R22), i.e. where our headroom is. APPROACH_A.md's
  envelope justification was therefore incomplete; this term is the unclaimed signal.
- **Exact fix.** One adjoint solve `Hμ=∂_pT` through the (probability-space, barrier-regularized,
  convex) routing optimum → route-aware `∂T/∂x` (IMPLICIT_DIFF_TIMING.md §5-8). κ stays the sparse
  per-arc `∂T/∂d` (heuristic, not exact STA adjoint — flagged; smoothing/subgradient stated). Costs
  #CG-iters × HVP, critical-support reduction = a Schur-complement approximation (terms named).
- **Positioning (RELATED_WORK.md, grounded survey).** No prior work differentiates through the
  routing layer for timing placement: A (diff-TDP DAC'22, Efficient-TDP DATE'25) = frozen est RC;
  B (DGR DAC'24) = ∂/∂p, no ∂/∂x; C (ML GR→DR parasitic predictors, e.g. arXiv:2305.06917) =
  **standalone non-differentiable annotators, no gradient to x**; D (GP+gate-sizing fusion ICCAD'24,
  DiffCCD) = fuses sizing/clock, not routing (but validates LSE-smoothed STA for our §6).
- **Level-A built (de-risk, one-directional).** `src/core/detour_timing.py`: additive
  `L=Σ w_n·HPWL_n·(1+α·ρ_n)`, gated `--detour_timing_weight` (default 0 → inert). codex: autograd
  correct; net_mask/activation/device fixed. FD self-check `tool/test_detour_timing.py`.
  **NOT YET RUN** (no local torch; runs on moe-server). Granularity (CRITICALITY_GRANULARITY.md):
  net-level is a scaffold (loses driver/sink asymmetry + per-sink detour); arc-level is the correct
  unit and aligns Level-A with the IFT `∂_pT=Σ_a κ_a∂d_a/∂ℓ_a` — go arc-level the moment Level-A shows signal.
- **NEXT (server):** run FD self-check; A/B `--detour_timing_weight {0.5,2.0}` × {ariane,bp_fe} under
  frozen auto-cal (frac=0.1); watch post-route TNS at matched HPWL. Signal → arc-level → IFT.

## R27 — ★★ FOUNDATION CHECK (depth-first, goal #13): the ariane divergence is CONFOUNDED by an over-pessimistic est timer (codex flaw-3 largely CONFIRMED)
Deep analysis of the EXISTING est-vs-routed netslack (no new runs):
| design | est #neg | est TNS | est WNS | routed #neg | routed TNS | routed WNS | est/routed TNS | Spearman |
|---|---|---|---|---|---|---|---|---|
| ariane | **124484 (84.9%)** | −490911 | −20.68 | 14552 (9.9%) | −12547 | −1.27 | **39×** | 0.58 |
| bp_fe | 16119 (56.9%) | −262985 | −54.68 | 16649 (58.8%) | −300266 | −68.73 | 0.88 | **0.99** |
**On ariane the ESTIMATED timer (`estimate_parasitics -placement`) is 39× over-pessimistic** — it marks
85% of nets violating (vs routed 9.9%), WNS −20.7 vs −1.27 ns. This is the R2b layer/RC-model confound:
`-placement` uses a pessimistic single-layer RC, `-global_routing` uses real (lower-R, higher) layers
→ the est-vs-routed gap is dominated by the RC MODEL, not routing detour. Spearman 0.58 (rank-invariant
to the 39× magnitude) shows SOME real reordering, but est's 85%-violating ranking has poor resolution →
0.58 is entangled with est-noise, not cleanly "routing reorders criticality".
**Honest implication:** the ariane "+8% route-aware" is substantially "routed criticality is a sharper/
better-calibrated signal than a BROKEN est timer", NOT proven to be real structural-detour reordering.
The R22 divergence (Jaccard 0.24) is partly a bad-est-timer artifact. **This MUST be resolved before any
SOTA claim.** bp_fe is clean (est≈routed, Spearman 0.99) — consistent (its est timer is well-calibrated).
**DECISIVE NEXT TEST (codex flaw-3 prescription):** recalibrate the est timer to be fair (fix the 39×
pessimism — match the per-layer/GR RC scale so est WNS ≈ routed-magnitude), then recompute Spearman/
Jaccard AND the route-aware gain. If the divergence + gain SHRINK toward bp_fe levels → the ariane win
was a bad-timer artifact (thesis must pivot). If they PERSIST under a fair est → real route-response (thesis holds).

## R28 — ★★ R27 RESOLVED (decisive, depth-first): HALF the ariane divergence is metal3-pessimism artifact, HALF is REAL route-response
Root cause of the 39× est pessimism (R27): `setRC.tcl` sets `set_wire_rc -signal -layer metal3`
(R=3.57e-3) — placement assumes ALL signal wires on metal3, but GR routes long/critical nets on
metal6/7/8 (R down to 1.875e-4, ~19× lower). Re-estimating with a FAIR layer:
| est layer | est WNS | est TNS | Jaccard(top13k) vs routed | Spearman vs routed |
|---|---|---|---|---|
| metal3 (platform default) | −20.68 | −490911 | 0.244 | 0.581 |
| metal5 (fair) | −7.89 | −26081 | **0.459** | **0.761** |
| metal6 (fair) | −7.71 | −24995 | 0.463 | 0.764 |
| (bp_fe est, well-calibrated) | — | — | 0.94 | 0.99 |
**~Half the divergence was the metal3-pessimism ARTIFACT** (Jaccard 0.24→0.46, Spearman 0.58→0.76 under
a fair layer) — codex flaw-3 PARTIALLY confirmed. **But ~half is REAL:** even with a fair-layer est,
Jaccard plateaus at 0.46 (≪ bp_fe 0.94), Spearman 0.76 — routing's per-net LAYER ASSIGNMENT (long/
critical nets → low-R metal7/8) + detour genuinely reorders criticality, unpredictable by any fixed-
layer est. **Thesis SURVIVES but tightened + mechanism clarified:** the real route-response is the
LAYER-ASSIGNMENT channel (CEILING VI) + detour, NOT what a smarter fixed-layer est can predict.
**Mandatory correction:** the honest est baseline is FAIR-LAYER (metal5/6), NOT platform-default metal3.
All route-aware gains must be re-measured vs the fair baseline (will be ~half the vs-metal3 numbers).
NEXT: re-run the placement gain (est_metal5 vs routed vs union criticality) at fair baseline → the honest headroom.

## R29 — ★★ THESIS SURVIVES the flaw-3 deep check: route-aware gain is ROBUST to a FAIR-layer baseline
ariane, same mechanism (net-weight, scale 1.0, top-13k), vary ONLY the criticality source:
| criticality source | post-route TNS | gain vs that baseline |
|---|---|---|
| fair-est (metal5, less-pessimistic layer) | −2735 | — |
| metal3-est (platform default) | −2685 | — |
| Xplace --timing_opt (path-based est) | −2600 | — |
| **routed** | −2480 | +9.3% vs fair-est, +7.6% vs metal3, +4.6% vs --timing_opt |
| **union (metal5-est ∪ routed)** | −2454 | **+10.3% vs fair-est, +9.6% vs metal3, +5.6% vs --timing_opt** |
**KEY:** the route-aware gain holds against the FAIR-layer est (metal5, −2735), NOT just the pessimistic
metal3 (−2685). So codex flaw-3 is ADDRESSED at the PLACEMENT level: the gain is NOT a metal3-pessimism
artifact. Surprising sub-finding: the fair-est PLACEMENT (−2735) is no better than metal3-est (−2685) —
a less-pessimistic criticality RANKING (R28 Jaccard 0.46) does NOT yield a better placement; the gain
comes ONLY from using the ACTUAL routed/union criticality, regardless of which fixed-layer est is the
baseline. Depth-first chain R27(artifact concern)→R28(divergence half-artifact in the METRIC)→R29(but
the placement GAIN is real, +9-10% vs fair baseline, +5-6% vs Xplace --timing_opt). The thesis positive
(route-aware union criticality, layer-assignment+detour mechanism) survived the deepest scrutiny.
Caveat still open: GR-fidelity eval (detailed-route+coupling pending on a tractable design); multi-design
(bp_fe positive, swerv invalid, need a 3rd valid); vs Efficient-TDP pin2pin / C3PO head-to-head.

## R31 — ★★ FIDELITY DEEP-DIVE (depth-first, goal #13 / 不失真): the route-aware comparison runs on placements that are NOT routability-grade — clean DR+coupling signoff is blocked by Xplace's congestion, not by the timing method
Attempted to close the last big caveat (R29): detailed-route + OpenRCX coupling re-eval. Went deep into the
back-end and found a chain of issues, each instructive:
1. **DR init DETERMINISTIC HANG fixed (infra):** my `detailed_route` omitted `-bottom_routing_layer metal2
   -top_routing_layer metal10` (ORFS NanGate45 MIN/MAX_ROUTING_LAYER). Without it DR includes metal1 →
   huge metal1 guide-region pin-query → hangs forever at "Init gr pin query" on the large ariane design
   (3h17m, 0 progress). ORFS does this step in 37s WITH the restriction. Adding the two flags unblocked it
   (init now ~80s, DR proceeds). **bp_fe (10MB DEF) never hung** (small enough) — confirms it is a scale×
   metal1 interaction, not a generic bug. Macros are NOT the cause: ariane's 132 SRAMs are FIXED at the
   *identical* coords as ORFS golden (`(2720480 1702960) N` etc.) — Xplace doesn't move fixed macros; the
   DRT-0419 "no track through macro pin" warnings are inherent to fakeram LEF and appear in ORFS too.
2. **GR over-optimism fixed (infra):** my `global_route` lacked `set_global_routing_layer_adjustment
   metal2-metal10 0.5` (50% capacity reserve for vias/local) + `-congestion_iterations 30` that ORFS uses.
   Without it GR under-estimates congestion → DR explodes.
3. **★ THE REAL FINDING — density-1.0 plain-GP Xplace placements are unroutable-grade.** Even WITH the GR
   adjustment, ariane density-1.0 GR cannot clear overflow (31+ min, "GRT-0103 Extra Run for hard
   benchmark", no convergence; ORFS's own placement GR finishes in 15:24). detailed_route on the
   density-1.0 arms produces **559k–588k DRC violations and RISING** (ORFS golden ariane = 83k initial,
   converges) → would take ~20h to hit the iteration cap, never clean. bp_fe density-1.0 same story
   (75k–138k violations, non-converging). Re-placing union at target_density 0.7 only halved violations
   (166k@50%) AND **hurt timing** (GR-TNS −2824 vs −2454 @1.0). **Root cause: pure analytical timing-GP
   (no `--use_cell_inflate`) yields placements far denser than routability-grade — exactly why
   routability-driven placement exists.** So clean DR+coupling SIGNOFF on these placements is not
   achievable without integrating routability (cell inflation) into the timing flow — a substantial
   experiment, not a back-end tweak.
**Honest status of the fidelity caveat:** NOT fully closeable on the current (plain-GP) placements. What
CAN be stated (R32) is a DR-stage *corroboration*, not a signoff number.

## R32 — ★ DR-stage corroboration: route-aware arms are MORE routable than the fair baseline (same DR effort), consistent with the GR-timing ranking
Routing the R29 fair-baseline arms (fairest/routed/union, density-1.0) through the fixed DR back-end, GR
stage reproduces R29 exactly, and the detailed-route first-pass (DRT-0199) DRC-violation count ranks the
arms the same direction as timing:
| arm | GR post-route TNS (R29, reproduced) | DR first-pass DRC violations |
|---|---|---|
| fair-est (metal5) | −2735 | 588233 |
| routed | −2480 | 559240 |
| union | −2454 | 576737 |
**Both route-aware arms (routed, union) beat the fair-est baseline on BOTH the GR timing-proxy AND
detailed-route routability** (fewer DRC violations). routed has the fewest violations; union the best
timing. This is a genuine detailed-route-stage signal in the thesis's favor — the route-aware criticality
does not merely improve a GR-only proxy, it makes the placement measurably more routable. CAVEAT: the
absolute violation counts are huge (unroutable-grade density-1.0), so this is a *relative-direction*
corroboration, not a coupling-signoff TNS; the 5% violation spread is modest. Full coupling-aware signoff
needs routability-grade placements (next phase: timing + cell-inflation co-run, then DR+OpenRCX).
**Net for SOTA (#12):** the verified positive remains R29 (GR-fidelity, +5.6% vs --timing_opt), now with
DR-routability corroboration; the clean DR+coupling number is deferred to the routability-integrated run.
Infra now ready (layer-restricted + GR-adjusted DR back-end `xplace_backend_ariane_dr.tcl`).

## R33 — ★★★ FIDELITY CAVEAT CLOSED, POSITIVELY: route-aware union gain SURVIVES (grows) at detailed-route + OpenRCX coupling SIGNOFF fidelity
The R31 finding (plain-GP density-1.0 placements are unroutable-grade) was overcome by placing the 3
R29 arms with `--use_cell_inflate True` (Xplace routability mode) + their criticality → routability-grade
placements that **detailed-route to 0 DRC violations** (union & routed reached 0; fairest 0 after opt).
Then OpenRCX coupling extraction + `write_spef`/`read_spef` (the missing step — see below) gives the
true coupling-aware signoff TNS. ariane, cell-inflate, vary criticality source only:
| arm (criticality) | GR-estimate TNS | **TRUE DR+OpenRCX-coupling TNS** | DR WNS |
|---|---|---|---|
| fair-est (metal5) | −3260 | **−972.5** | −0.545 |
| routed | −3048 | **−832.0** | −0.514 |
| **union (metal5∪routed)** | −3016 | **−823.7** | **−0.512** |
**Route-aware union beats the fair-est baseline by +15.3% post-route TNS and +6% WNS at full
detailed-route + coupling signoff fidelity (0 violations, OpenRCX).** routed +14.5%. The gain is NOT a
GR-fidelity artifact — it is LARGER at signoff (+15.3%) than at GR fidelity (+7.5% at this density).
Two more honest observations:
- **GR estimate is ~3.4× pessimistic** vs true coupling-aware DR (fairest −3260→−972, union −3016→−824)
  — the R28 RC-pessimism made absolute GR-TNS far too negative — BUT the RANKING is preserved
  (union<routed<fairest at BOTH fidelities) → validates that R19–R29's GR-fidelity comparisons were
  directionally correct (the contribution is the GP gradient/ranking, judged relatively).
- **THE BUG (不失真, now fixed):** the first cell-inflate run reported DROUTE_DR_TNS == DROUTE_GR_TNS
  *exactly* — `extract_parasitics` writes OpenRCX parasitics into the DB but STA keeps the stale
  GR-estimated ones until `write_spef`+`read_spef` (ORFS final_report.tcl pattern). Caught by the
  identical-to-13-sig-figs coincidence; fixed in `xplace_backend_ariane_dr.tcl`; numbers above are post-fix.
**Status vs SOTA (#12):** the verified positive is now SIGNOFF-fidelity (not just GR): route-aware union
criticality > fair-est baseline by +15.3% post-route coupling TNS on ariane, on a 0-violation detailed
route. Remaining for STRONG SOTA: (a) vs Xplace `--timing_opt` at this same signoff fidelity (run pending —
fair-est is the academic-TDP baseline, --timing_opt is Xplace's own); (b) ≥2 more valid designs at signoff
fidelity; (c) the fixpoint/criticality was from density-1.0 routes (slightly mismatched to inflate density)
→ a consistent inflate-density fixpoint may widen the gain. Infra fully ready (routability-grade place +
layer/GR-adjusted + SPEF-correct DR back-end). Routed ODBs persisted (`infldr2_*_routed.odb`).

## R34 — vs Xplace `--timing_opt` at signoff: ATTEMPTED, blocked by a mechanism-mismatch confound (and an incidental routability finding)
Tried the head-to-head vs Xplace's own `--timing_opt` (full GPUTimer path-based pull) + `--use_cell_inflate`
at signoff fidelity. Outcome: NOT a clean comparison, for a principled reason.
- `--timing_opt`+inflate placed ariane at **HPWL 2.463E7 — DENSER than the route-aware union arm (2.819E7)**:
  the strong GPUTimer pull (exponential criticality terms) over-concentrates critical cells, counteracting
  the cell-inflation spreading. The resulting placement does NOT route cleanly — GR stuck 30+ min in
  "GRT-0103 Extra Run for hard benchmark" with a recurring high-fanout net (net5567, degree 112) error, no
  convergence → no signoff TNS obtainable.
- **Mechanism mismatch = the comparison is not apples-to-apples anyway:** the R33 arms (fairest/routed/union)
  all use the SAME gentle oracle net-weighting at scale 1.0, varying ONLY the criticality source — the clean
  isolation of "routed/union criticality vs estimated criticality". `--timing_opt` is a different, much
  stronger force (different density, different routability). Comparing them conflates force-strength with
  criticality-source. **The mechanism-matched signoff result is R33 (union +15.3% vs the fair-est academic
  baseline), which IS the core thesis claim (route-aware criticality > estimated criticality).**
- **Incidental finding (favors the thesis):** at matched routability mode, the route-aware union placement
  routes to 0 violations while `--timing_opt`'s denser placement does not route cleanly — i.e. the gentle
  route-aware criticality net-weighting yields a MORE routable timing placement than the strong-pull mode.
**Decision:** park the `--timing_opt` signoff head-to-head (confounded); the SOTA comparison vs `--timing_opt`
stays at R29's GR-fidelity (+5.6%, density-1.0, where --timing_opt routed via GR). The signoff-fidelity
positive is R33 (mechanism-matched, +15.3% vs fair-est). NEXT for #12: 2nd valid design at signoff (bp_fe
cell-inflate arms), and a force-strength-matched --timing_opt comparison (lower timing_init_weight so its
density ≈ the net-weight arms) if a direct vs-production number is needed.

## R35 — ★★★ 2nd-DESIGN NEGATIVE CONTROL at SIGNOFF: bp_fe confirms the DIVERGENCE LAW (DIVERGENCE_LAW.md)
The bp_fe analog of R33: place 3 arms (fairest/routed/union) with `--use_cell_inflate` + their criticality,
detailed-route + OpenRCX coupling (SPEF-correct backend). bp_fe is the LOW-DIVERGENCE design — quantified:
**Spearman(est,routed crit)=0.967, top-13k Jaccard=0.937** (vs ariane 0.192 / 0.244). Prediction (pre-
registered in `bpfe_inflate_signoff.sh`): route-awareness carries ~no new info → union ≈ flat vs fairest.
| arm (criticality) | GR-estimate TNS | **TRUE DR+OpenRCX-coupling TNS (signoff)** |
|---|---|---|
| fairest (est) | −93567 | **−17885.1** |
| routed | −100270 | **−17848.3** (marginally BEST) |
| union (est∪routed) | −96267 | **−17900.6** |
**All 3 arms TIED within 0.3% at signoff (range 52 TNS / 17885) → route-awareness gives ~0 gain on
low-divergence bp_fe, EXACTLY as the divergence law predicts.** Contrast ariane (high-divergence) union
+15.3%. This is the confirming NEGATIVE CONTROL — it makes the thesis a PREDICTIVE LAW (gain ∝ 1−agreement),
not "always add routing".
- **GR→signoff washout:** at GR estimate routed looked notably worse (−100270 vs fairest −93567), but at
  signoff all tied (routed marginally best). GR was ~5× pessimistic on bp_fe (worse than ariane's 3.4×);
  the GR-stage apparent routed-harm was a pessimism artifact, gone at coupling-aware signoff.
- **No harm (important):** route-awareness does NOT meaningfully hurt even where it doesn't help (union
  −0.1% vs fairest = noise). So raw union is SAFE at signoff here, though it added nothing.
- **★ INDEPENDENT REPRODUCTION (closes codex flaw-4 single-seed):** a fully independent fresh re-run
  (`bpfe_inflate_signoff.sh`, new placements `bsg_*`, new DR `bsgdr_*`, raw-backend-log verified) reproduced
  all 3 arms to the decimal (fairest −17885.13, routed −17848.27, union −17900.58; all 0 DRC). Two independent
  place+route passes → identical numbers ⇒ Xplace determinism confirmed, so the 0.3% tie is a REAL null, not
  seed noise. (Process note: do NOT `scp` a running driver — mid-run overwrite corrupts bash line-buffered
  step-3; canonical numbers were taken from the openroad backend logs, which are written independently.)
- **Two-point divergence law @ signoff:** ariane (Jaccard 0.244) → +15.3%; bp_fe (Jaccard 0.937) → ~0.
  Direction clean; a 3rd design at intermediate divergence would calibrate the curve (DIVERGENCE_LAW §4).
- **Deployability (DEPLOYABILITY.md):** both designs use the 2-pass place→route→re-place flow with
  criticality from an INDEPENDENT base route (no oracle, no leak). The divergence trigger (Spearman/Jaccard
  of the 2 pass-1 CSVs) is computable oracle-free → adaptive rule: apply route-awareness only when divergence
  is high. **Confidence-weighted union** (`blend_crit_conf.py`, c=est+(1−a)·max(0,routed−est)) operationalizes
  this in one formula (ariane a=0.19→≈union; bp_fe a=0.97→≈est) — staged to test on both anchors.

## R36 — ★★★ CLEAN #12 vs PRODUCTION `--timing_opt` at SIGNOFF: union +15.0%, BOTH 0-DRC (R34 confound RESOLVED)
R34 parked the `--timing_opt` head-to-head as confounded (it over-packs at default weight → won't route).
RESOLUTION = force-match it DOWN (SOTA_COMPARISON_DESIGN.md Option-1): sweep `--timing_init_weight`
{0.05,0.03,0.02,0.01,0.005} with `--use_cell_inflate`. Finding: **`--timing_opt` HPWL SATURATES at ~2.64e7**
(0.05→2.463, 0.03→2.522, 0.02→2.649, 0.01→2.637) — even the weakest pull can't reach the route-aware union
arm's routability-grade 2.819e7; production timing pull is structurally ~6% denser. Routed the loosest
(w=0.02, HPWL 2.649e7, best routability) through the signoff DR+OpenRCX backend. **It DID converge to 0 DRC
violations** (detailed_route opt iterations 105357→…→0). Clean head-to-head at signoff (all `--use_cell_inflate`,
0 DRC, OpenRCX coupling):
| arm (criticality, actuation) | DR-coupling TNS | DR WNS | HPWL |
|---|---|---|---|
| fair-est (est crit, flat net-weight) | −972.5 | −0.545 | ~2.82e7 |
| **`--timing_opt` (est crit, path-based exp pull)** | **−968.9** | −0.572 | 2.649e7 |
| routed (route-aware crit, flat net-weight) | −832.0 | −0.514 | — |
| **union (route-aware crit, flat net-weight)** | **−823.7** | −0.512 | 2.819e7 |
**TWO findings:**
1. **union beats production `--timing_opt` by +15.0% post-route coupling TNS** ((968.9−823.7)/968.9) and
   +10.5% WNS, BOTH at 0 DRC + signoff coupling fidelity. routed beats it +14.1%. **First clean
   SOTA-vs-production datapoint** — the core thesis claim at signoff, vs Xplace's OWN production timing placer.
2. **The two ESTIMATED-criticality methods TIE** (fair-est −972.5 ≈ `--timing_opt` −968.9, within 0.4%)
   despite completely different actuation (flat net-weight vs exponential path-based GPUTimer pull). This
   **isolates the contribution to the criticality SOURCE, not the actuation** (SOTA_COMPARISON_DESIGN.md §2
   prediction confirmed): swapping est→routed/union gives +15%, swapping the force formula gives ~0.
- **HPWL honesty:** `--timing_opt` is DENSER (2.649 vs union 2.819) yet times WORSE — its tightness is a
  wirelength edge that did NOT buy timing. So the +15% is not a "union spent more area" artifact; the looser
  route-aware placement wins timing despite (not because of) area. union↔fair-est is iso-mechanism iso-HPWL
  (the clean +15.3%); union↔`--timing_opt` has a 6% HPWL gap that favors `--timing_opt` on congestion yet it
  still loses on timing.
- **Caveat (honest):** w=0.02 is `--timing_opt`'s loosest routable point; a DR sweep across weights could find
  a marginally better routable `--timing_opt` TNS, but its DEFAULT (0.05) does not route at all → −968.9 is a
  fair representative of its routable operating point. **Still 1 design (ariane);** STRONG SOTA (#12) needs a
  2nd high-divergence design (bp_fe/aes are low-divergence negative controls). Next: bp_be_top (fresh ORFS,
  macro-heavy high-divergence candidate) + Efficient-TDP/C3PO.
- **Status:** ariane now has a clean, signoff-fidelity, 0-DRC, +15% win over BOTH the academic baseline
  (fair-est) AND production Xplace-Timing (`--timing_opt`). Driver: `ariane_timingopt_forcematch_sweep.sh` +
  `ariane_fmto_dr.sh`. Result file `ariane_fmto_dr_results.txt`.
- **★ codex adversarial review (CODEX_REVIEW_R36.md) — claims TEMPERED (results stand, not yet bulletproof):**
  (1) The "looser-yet-better proves area didn't help" argument is WEAK — union's looser HPWL may itself
  buy the lower congestion/coupling/detour that helps timing; and `--timing_opt` was detuned only via
  `timing_init_weight`, not the full routability knob set → R36 is a first datapoint, NOT a Pareto proof.
  Need a 0-DRC signoff PARETO sweep (both methods × density knobs) at matched density/wirelength/via/
  congestion. (2) The fair-est≈`--timing_opt` tie is at ONE detuned point on ONE design → CONSISTENT WITH
  source-dominance but NOT proof (could be a floor/coincidence); the clean proof needs the 2×3 crossed
  matrix (source×formula), i.e. INJECT routed/union criticality into the GPUTimer (Option 2). (3) 2 designs
  ≠ a law; deployability is a stale-label (pass-1→pass-2) transfer → need 4–6 designs + cross-base/fixpoint
  convergence. **The ONE un-criticized clean result remains R33 (+15.3%, source within flat net-weight,
  iso-mechanism iso-HPWL).** Roadmap reordered: bp_be_top (running) → GPUTimer injection (Option 2) →
  Pareto sweep → cross-base convergence.

## R37 — ★★ MULTI-DESIGN SWEEP (3 new designs via fresh ORFS) → the law's METRIC is critical-SET Jaccard, gain regime is NARROW
Built fresh ORFS floorplans (synth via symlinked conda yosys/openroad) + Xplace bridges for 3 independent
designs; measured est-vs-routed criticality divergence (2-pass base) and, for bp_multi, the gain:
| design | #macros | Spearman | top-K Jaccard | route-aware gain |
|---|---|---|---|---|
| ariane133 | 132 | 0.192 | 0.244 (13k) | **+15.3% signoff (R33/R36)** |
| **bp_multi_top** | ~30 | **0.776** (intermed) | **0.878** (5k) | **~0 (GR: union −275052 vs fairest −276274, +0.4%; routed −320436 WORSE)** |
| bp_be_top | ~12 | 0.960 | 0.653 (5k) | unmeasured |
| bp_fe_top | few | 0.967 | 0.937 (13k) | ~0 signoff (R35) |
| aes | 0 | 0.946 | 0.639 (3k) | unmeasured (R18 ρ≈0) |
**★ KEY (bp_multi disambiguates the law's metric): gain-predictor is top-K critical-SET JACCARD, NOT
full-ranking Spearman.** bp_multi has INTERMEDIATE Spearman (0.776) but HIGH Jaccard (0.878), and its gain
is ~0 — matching Jaccard (high→~0), refuting Spearman (intermediate→would predict gain). Mechanistically
sound: net-weighting acts on the top-K critical SET; if est & routed pick the SAME critical nets (high
Jaccard), identical weighting → identical placement → no gain, regardless of within-set rank order. Only
when routed picks DIFFERENT critical nets (low Jaccard, ariane 0.244) is there a gain.
- **Honest consequence — the gain REGIME IS NARROW:** among 5 designs only ariane (Jaccard 0.244) is in the
  gain regime; bp_multi/bp_fe (Jaccard 0.88/0.94) are ~0. The discriminator is HEAVY MACRO-CONGESTION
  (ariane 132 macros forces long nets through detour+layer-reassignment that change WHICH nets are critical).
  The method's value is SCOPED to congestion-dominated designs — and the Jaccard trigger (computable
  oracle-free at pass-1) correctly says "skip route-awareness" on the others.
- **GR-fidelity caveat:** bp_multi gain is GR-stage; on bp_fe the GR routed-harm washed out at signoff (R35)
  but union stayed ~flat → bp_multi union ~0 is likely robust. Signoff confirmation optional (low value:
  union flat at GR).
- **For STRONG SOTA (#12):** still need a 2nd LOW-Jaccard (heavy-macro) design with a POSITIVE gain to prove
  +15% isn't ariane-unique. Tractable many-macro candidates exhausted at NanGate45 except mempool_group
  (4400×4400, heavy) — or accept the scope as "congestion-dominated regime" with ariane as the exemplar +
  the law explaining the negatives. Drivers: `bpmulti_{floorplan,base,arms}.sh`, `bpbe_*`.

## R38 — ★★ CODEX CODE-LEVEL CHAIN REVIEW (整个链路, goal #2) → PIVOT to mechanism verification
Independent reproduction of R35 this session (hardened/audited driver `bpfe_inflate_signoff.sh`: flock
single-instance guard, fresh-DEF guard, DRT_FAIL/DRC gates) CONFIRMS the bp_fe negative control exactly:
fairest −17885.1 / routed −17848.3 / union −17900.6, **all 3 arms 0-DRC, no DRT_FAIL, tied within 0.3%
(range 52.3 / 17885)**. So R35 is robust to a stricter harness.

Then a deep CODE-LEVEL codex pass (read the CUDA actuator + the criticality dump + the injection, not just
the scripts) — full writeup in [CODEX_CHAIN_REVIEW_CODE.md](CODEX_CHAIN_REVIEW_CODE.md). 11 chain flaws; the
**3 deepest are mechanism-invalidating and outrank getting a 2nd design:**
- **#1** the actuator is route-BLIND WA wirelength; nothing proves shortening it improves the *routed* slack
  of the weighted net (could be cell-delay/coupling/congestion dominated). Empirical ariane +15% stands;
  the "we optimize timing" MECHANISM is unproven.
- **#2** per-net-min slack is broadcast to ALL pins → weights high-fanout geometry, not endpoint sensitivity
  → the gain could be a fanout/geometry bias, not timing.
- **#4** est (pre-CTS) vs routed (post-CTS+DP+GR) are different STAGES → the "divergence" is partly a CTS
  artifact, not pure routing reordering.
Plus law-as-stated confounds: **#3** Jaccard measured at GR fidelity but gain at signoff; **#8** arms weight
absolute top-13k (=46% bp_fe vs 10% ariane) while the law table uses top-10% — inconsistent fraction.

**PIVOT (depth-first, goal #13):** mempool_group (the pre-registered 2nd heavy-macro design) is BLOCKED —
only a `config.mk` stub exists in this ORFS checkout (no SDC/netlist/macros) → floorplan fails rc=2. Since a
2nd design cannot rescue the thesis if ariane's +15% is itself a geometry/CTS artifact, the load-bearing work
moves to MECHANISM VERIFICATION on the existing ariane positive: P1 recompute ariane Jaccard at DR+OpenRCX
and post-CTS same-stage (#3/#4, recompute-only, cheapest); P2 per-critical-load-pin vs per-net-min at matched
force (#2); P3 finite-difference along the timing gradient + reroute (#1, decisive). FIXED #11 (committed
`blend_crit.py`); #9/#10 gates added to the bp_fe driver (backport to ariane collector pending).

## R39 — ★★ THE DIVERGENCE-LAW THRESHOLD IS EST-TIMER DEPENDENT (depth-first on codex #3/#8, 不失真)
Recomputed ariane est-vs-routed top-K Jaccard with BOTH est timers vs the SAME routed CSV (`div_frac.py`):
| est timer | top-5% | top-10% Jaccard |
|---|---|---|
| metal3 / default placement-est (`ar_base_place`) | 0.244 | **0.231** ← what DIVERGENCE_LAW.md quotes |
| **fair metal5 est** (= the R33 +15.3% gain baseline) | 0.331 | **0.517** |
**The law's "ariane uniquely below the 0.4 threshold" uses the metal3/default est; the +15.3% gain uses the
fair metal5 est (adopted in R28/R29 because metal3 is ~39× over-pessimistic). Recomputed consistently with
the fair est, ariane is 0.517 — ABOVE 0.4, in the band of the "low-gain" designs (aes 0.545, bp_multi 0.619,
bp_be 0.666).** CORRECTED (verified bp_fe default-est top-10% Jaccard = 0.963 = the table value exactly →
the 5-design table IS internally consistent, all default-est; ariane 0.231 IS genuinely the unique low point
in that metric). Precise scope, narrower than "the law collapses": (1) only ariane's METRIC (default-est,
0.231) differs from ariane's GAIN BASELINE (fair metal5-est, +15.3%); (2) that mismatch is CONSERVATIVE —
gain is vs a STRONGER baseline than the trigger's default est, so a deployed default-est flow sees an
equal-or-larger gain (not a cheat); (3) the real residual = the trigger value is est-sensitive (0.231 default
vs 0.517 fair), so a clean law must name ONE est for trigger+gain — but R29 (fair-est place −2735 ≈ default
place −2685; only ROUTED crit gave +15%) shows the gain mechanism is routed-criticality, robust to est choice
→ SUPPORTS the law. **Honest net: +15% is solid and arguably conservative; the "threshold 0.4" NUMBER is
est-dependent and must not be quoted without naming the est; the DIRECTION (ariane uniquely divergent under
the deployable default-est) holds.** Still needed: name the trigger's est + recompute the table at fair est.

★ MEASUREMENT-HARNESS AUDIT (user-confirmed, 不失真): the TRUE R33/R36 signoff numbers live in
`ariane_infl_dr_true_results.txt` / `backend_infldr2_*` (fair-est −972.5, routed −832.0, union −823.7,
timing_opt w0.02 −968.9; all 0-DRC, no DRT_FAIL). The older `ariane_inflate_fidelity_results.txt` is the
STALE `DR_TNS == GR_TNS` bug output (pre-SPEF-fix) — **must NOT be cited.** +15% is NOT a collector false
positive. Backport the bp_fe driver's DRT_FAIL/DRC/oracle-load gates to the ariane collector. Aligns with
CODEX_CHAIN_REVIEW.md's "post-hoc classifier" worry. Full analysis (with the self-correction):
[DIVERGENCE_METRIC_CONSISTENCY.md](DIVERGENCE_METRIC_CONSISTENCY.md).

Side finding (codex #5, verified, `norm_check.py`): the ariane union top-13k SET is normalization-sensitive
— own-norm vs rank-percentile Jaccard 0.79, own-norm vs raw-ns 0.60 → **20–40% of the union set is a
normalization artifact**. Evaluate `blend_crit_conf.py` under all three norms, or justify own-norm.

## R40 — ★★★ MECHANISM AUTOPSY P3 (DECISIVE, 不失真): the ariane "divergence" is the CTS stage, NOT routing
Same-stage criticality decomposition (`xplace_backend_ariane_samestage.tcl`, `div_frac.py`), three Jaccards:
| comparison | top-5% | top-10% Jaccard | meaning |
|---|---|---|---|
| pre-CTS-est vs routed (the thesis "divergence") | 0.244 | **0.231** | looks highly divergent |
| pre-CTS-est vs post-CTS-est (**CTS alone**) | 0.000 | 0.168 | CTS reorders the critical set almost entirely |
| **post-CTS-est vs routed (ROUTING alone)** | **0.987** | **0.982** | **routing barely reorders it** |
Timing sanity: pre-CTS WNS −42.1/TNS −206126 (pathological — `set_propagated_clock` on an unbuilt clock
tree) vs post-CTS WNS −1.01/TNS −2196 (sane). **The R33 fair-est baseline (`ar_est_metal5`, via
`est_layer_probe.tcl`) AND the divergence-metric est (`ar_base_place`) are BOTH dumped PRE-CTS** (no
`clock_tree_synthesis` in those scripts) → the entire est-vs-routed comparison is pre-CTS-vs-(post-CTS+routed).

**DECISIVE: at the SAME post-CTS stage, the GR-routed critical set is 98% identical to the pre-route estimate
(Jaccard 0.982). The 0.231 "divergence" the thesis attributed to routing is the CTS clock-tree transition.**
A post-CTS ESTIMATE (no routing) recovers 98% of the "routed" critical set. This is apples-to-apples: the
arms' routed criticality (`ar_base_netslack`) is GR-fidelity (`estimate_parasitics -global_routing`), exactly
the fidelity compared here; coupling was only in the signoff EVALUATION, not the criticality SOURCE.

Combined with the concurrent P1 autopsy (commit 7af32ed: at matched force norm `--timing_force_frac 0.1`,
union −3197 does NOT beat est −3168 at GR; broadcast≈fanout_norm → the R29 +10% was a FORCE-MAGNITUDE effect,
not a criticality-SET effect) and R39 (the divergence metric is also est-timer-confounded):
**→ the +15.3% signoff TNS is REAL as a number, but the core "route-feedback reorders the true critical set"
MECHANISM is NOT supported on ariane. The routed criticality ≈ a post-CTS estimate (no routing needed), and
the matched-force gain vanishes.** This is the METHOD_DERIVATION.md §8 diagnostic branch. Decisive remaining
test: `ariane_signoff_fair.sh` (does ANY gain survive matched force + fanout_norm at DR+OpenRCX signoff).
CAVEATS: P3 routing-only Jaccard is on the cell-inflated `infl_fairest` placement (routable; the pre-CTS/CTS
rows are on density-1.0 `dms_base_s0` — different placement, but the 0.982 routing-only overlap is
overwhelming and placement-robust). VCERF's "route feedback" premise needs a design where post-CTS-est vs
routed Jaccard is genuinely LOW; ariane is NOT that design once measured same-stage.

## R41 — autopsy completion: COUPLING adds a modest mid-tier criticality signal; GEOMETRY adds ~none
Coupling-criticality test (`xplace_backend_ariane_coupling_crit.tcl` on cell-inflated infl_fairest, full
detailed_route→0 DRC→OpenRCX→SPEF), Jaccard vs the post-CTS pre-route est, contrasted with R40's GR row:
| routed-criticality source vs post-CTS-est | top-5% | top-10% Jaccard |
|---|---|---|
| GR (geometry only, `-global_routing`) [R40] | 0.987 | 0.982 |
| **DR + OpenRCX coupling** | **0.971** | **0.767** |
Coupling DR: 0 DRC, no DRT_FAIL, signoff TNS −972.47 (= R33 fair-est exactly — infl_fairest IS that arm).
**Reading:** routing GEOMETRY reorders the critical set by ~2% (GR 0.982); adding COUPLING reorders ~23% of
the top-10% set (0.767) but only ~3% of the top-5% (0.971) — i.e. coupling shifts a modest MID-TIER band, not
the most-critical nets. **Crucial:** the actual experiment arms used GR-fidelity routed criticality
(`ar_base_netslack` = `estimate_parasitics -global_routing`, no coupling), which ≈ post-CTS-est (0.982). So
the +15.3% CANNOT be a coupling-criticality effect — the arms never saw coupling crit. **Autopsy verdict
(R40+R41+P1+R39): the +15.3% signoff TNS is REAL but the "route-feedback reorders the true critical set"
mechanism is NOT what produced it — the GR-routed criticality the arms used is 98% a post-CTS estimate, the
"divergence" is the CTS clock-tree stage, and the matched-force gain vanishes (concurrent P1). A NARROW future
angle survives: COUPLING-aware routed criticality (not GR, not used by the current arms) does reorder ~23% of
the top-10% set — a coupling-criticality source is the only place route-feedback could add real timing info on
ariane, and even there it is modest and mid-tier.** Pending the concurrent `ariane_signoff_fair.sh` (does any
gain survive matched force + fanout_norm at signoff) for the final gain verdict.

## R42 — autopsy conclusion, CODEX-REVIEWED + frac-sweep CORRECTION (verdict: sound but was slightly over-claimed)
codex (gpt-5.5 xhigh) reviewed the R40/R41 conclusion: **"sound but slightly over-claimed; directionally right
— the +15.3% is real, but current evidence does NOT support 'GR routing reorders the true critical set' as the
mechanism."** Corrections applied:
- **(D, the main fix) "matched-force gain vanishes" was OVER-READ — and the concurrent frac-sweep REFUTES it.**
  P1 (frac=0.1: union −3197 ≈ est −3168) was a single outlier config. The frac sweep (GR) shows union BEATS est
  at matched force for frac 0.2/0.3/0.5: est −3167/−3395/−3097 vs union −3088/−2943/−3024 = **+2.5% / +13.3% /
  +2.4%**. So a criticality-SET effect DOES survive force-matching; the gain is NOT purely force-magnitude.
- **Reconciliation with R40 (GR-routed ≈ post-CTS-est, 0.982):** union beats est at matched force because the
  est baseline is PRE-CTS (pathological, WNS −42) while union's routed component carries the POST-CTS critical
  set (GR-routed ≈ post-CTS-est). **The surviving advantage is POST-CTS / clock-aware criticality, NOT
  routing-reordering.** Routing adds ~nothing over a post-CTS estimate (0.982); the routed CSV is merely the
  only channel by which the current pipeline injects post-CTS criticality (the est baseline being pre-CTS).
- **(A/B) placement-mismatch caveat:** the 0.982 routing-only row is on infl_fairest; the pre/post-CTS rows on
  dms_base_s0 — so the decomposition is conditional; the full 0.231 cannot be perfectly attributed to CTS on one
  identical placement. (E) coupling "narrow" is correct (top-5% 0.971 barely moves; top-10% 0.767 = ~23% mid-tier).
- **(D, remaining gap) signoff matched-force still pending** (concurrent `ariane_signoff_fair.sh` running): the
  matched-force evidence is GR-fidelity; the signoff matched-force number is not yet in.

**CORRECTED autopsy verdict:** the +15.3% is REAL and survives force-matching (criticality-SET effect, not pure
magnitude), BUT the effective source is **post-CTS clock-aware criticality**, not route-feedback reordering —
GR-routed criticality is 98% a post-CTS estimate, and the est baseline only looked weak because it was dumped
PRE-CTS (pathological). **THE decisive missing experiment (codex F):** on ONE placement, same force-norm, at
SIGNOFF, net-weight by each of {pre-CTS-est, post-CTS-est, GR-routed, coupling-routed} criticality. Prediction:
post-CTS-est ≈ GR-routed ≈ union (route feedback unnecessary; the value is CTS-aware estimation); pre-CTS-est
loses; coupling-routed may add a small top-10% edge. If post-CTS-est ties routed → the "route-aware" headline
is replaced by "clock-aware (post-CTS) criticality net-weighting" + the divergence diagnostic.
