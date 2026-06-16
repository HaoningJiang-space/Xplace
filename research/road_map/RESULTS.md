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

## IN FLIGHT (2026-06-17)
- **Exp 1 on the chosen substrate**: verify Xplace GPUTimer handles NanGate45/ASAP7 libs (single-corner vs ICCAD early/late), then Xplace-place an ORFS design → OpenROAD route → SPEF → Δ(detour, ĉ, slack) → PROCEED/PIVOT.
- **ariane133/NanGate45 OpenROAD oracle gate** still running in background — demoted to tool-independent mechanism cross-check (NOT the main gate).

## READING SO FAR
Gate A + placement-controllability look **positive on aes (std-cell)**; the thesis stands or falls on (1) the same holding — ideally STRONGER — on the **macro/congested** design with seed-causality intact, and (2) Gate B utility (needs the bridge). No SOTA/win claim yet; this is mechanism+causality evidence, not the placement-improvement result.
