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
