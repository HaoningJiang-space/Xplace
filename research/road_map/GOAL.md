# GOAL — living objective (adaptively updated)

Last updated: 2026-06-17. This file is rewritten as milestones complete; it is the
single place to see "what we are doing right now and why." History lives in git.

## North star (stable)
Build a **better GLOBAL PLACER**: close **post-route** WNS/TNS that a congestion-blind
timing-driven placer cannot, via a **fidelity-preserving route-aware timing model**
(route-induced parasitic distortion Z(x) as the mediator from placement congestion to
post-route timing). Must be **non-incremental**, **SOTA vs C3PO**, and a genuine
methodological contribution. Target DAC 2027.

## Process invariants (the standing /goal — always on)
1. Update the docs as state changes (this file + RESULTS/ROADMAP/FIDELITY).
2. Think from first principles; **let codex adversarially review before continuing**.
3. Always anchor on **global placement** — Xplace is the placer; everything serves it.
4. **不要失真** — obey the FIDELITY.md distortion rules (D1–D9); a gain the placer
   "sees" must survive routing.
5. **git-manage** — commit + push to `HaoningJiang-space/Xplace` (remote `hj`).

## Current objective (ADAPTIVE — this is the live target)
**Build + run the true-residual ORACLE falsifier on aes NanGate45** (codex's cheapest,
thesis-upper-bounding experiment). Decision: if a PERFECT routed-RC predictor cannot
beat route-seed noise on post-route WNS/TNS at matched routed-WL/DRC → **STOP**.

Sub-steps (update as each lands):
- [x] Back-end harness (GR-based, fast): Xplace DEF → CTS → global route → GR parasitics → STA. Baseline on Xplace-placed aes: **D_place TNS −54.9 → D_route(GR) TNS −60.1** (routing degrades ~5.2 ns). First post-route-bound gap on an Xplace placement.
- [x] **Injection-point finding:** plain GP ignores `net_weight`; route-aware force MUST enter via the timing-WL term (`merged_wl_loss_grad_timing`, net_weight+timing_pin_weight). `--net_weight_file` on plain GP = identical placement (confirmed).
- [ ] **Oracle hook v2:** enable the timing-WL term with timing_pin_weight/net_weight set from baseline routed criticality (no GPUTimer STA) — THIS is the thesis injection mechanism. **Codex-review it before trusting.**
- [x] Oracle arm + scale sweep: **scale 0.3 improves post-route TNS −60.1 → −51.2 (~15%)** at near-iso wire-cap; non-monotonic (sweet spot). Placement-controllable post-route headroom EXISTS (Gate-B-positive signal).
- [x] **Isolation on aes (uncongested):** routed≈estimated (R9) — no route-awareness value where there's no congestion (expected).
- [x] **Congested substrate (ariane133, 132 macros):** est-vs-routed criticality diverge (top-200 Jaccard 0.003) — premise validated (R10).
- [x] **★ Utility (ariane133):** routed-criticality oracle −23% post-route TNS at LOWER wire-cap; estimated only −3.5% → **route-awareness ≈20% headroom on congested designs** (R11). Oracle upper bound; placement-controllable headroom EXISTS.
- [ ] Rigor: multi-seed, 2nd macro design, RC-correction oracle (delay magnitudes vs ranking).
- [ ] Build the differentiable route-aware predictor → Exp3 full-flow PPA vs C3PO/Xplace-Timing.

## Done (rolling, newest first)
- 2026-06-17 Substrate verified: Xplace places ORFS NanGate45 (gcd 480, aes 13858) → OpenROAD round-trip route OK.
- 2026-06-17 Bridge unblocked (wrong-LEF root cause; use `.macro.mod.lef`).
- 2026-06-17 FIDELITY.md (D1–D9) written + codex-reviewed + hardened (D7 flow-mutation, D8 gradient-reality).
- Gate A (mechanism) positive on aes/ibex std-cell (beyond-RUDY, seed CV 0%) — premise only, not utility.

## Open gates / risks (the honest blockers)
- Gate A ≠ Gate B: **placement utility unproven** — the oracle falsifier is the bridge.
- Non-incrementality earned only by Exp 3 (route-verified gradient beats Steiner/GR-RC/RUDY/C3PO at iso-congestion).
- Physical risk: placement-controllable parasitic delta may be dominated by cell/slew/buffering/CTS/macro-pin/path-migration.
