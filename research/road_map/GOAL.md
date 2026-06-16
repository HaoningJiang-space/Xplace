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
- [x] **OpenROAD back-end harness built + working** (`bridge/xplace_backend.tcl`): Xplace placement DEF → read LEF/lib/SDC → D_place (Steiner) → CTS (BUF_X4, 562 sinks) → detailed placement → route → SPEF → D_route. First run on Xplace-placed aes: **D_place WNS −0.595 / TNS −54.9 ns**; D_route in progress.
- [ ] Baseline arm post-route TNS (D_route) + DRC + route-seed noise band (re-route N seeds).
- [ ] Oracle form: net-weight oracle via OpenSTA routed-criticality → Xplace `net_weight` (avoids the Xplace-timer-on-NanGate45 uncertainty); faithful routed-RC injection as a later refinement.
- [ ] Oracle arm: oracle weights → Xplace re-place → same back-end → post-route TNS.
- [ ] Verdict: oracle beats baseline beyond seed noise at iso routed-WL/DRC? PROCEED/STOP.

## Done (rolling, newest first)
- 2026-06-17 Substrate verified: Xplace places ORFS NanGate45 (gcd 480, aes 13858) → OpenROAD round-trip route OK.
- 2026-06-17 Bridge unblocked (wrong-LEF root cause; use `.macro.mod.lef`).
- 2026-06-17 FIDELITY.md (D1–D9) written + codex-reviewed + hardened (D7 flow-mutation, D8 gradient-reality).
- Gate A (mechanism) positive on aes/ibex std-cell (beyond-RUDY, seed CV 0%) — premise only, not utility.

## Open gates / risks (the honest blockers)
- Gate A ≠ Gate B: **placement utility unproven** — the oracle falsifier is the bridge.
- Non-incrementality earned only by Exp 3 (route-verified gradient beats Steiner/GR-RC/RUDY/C3PO at iso-congestion).
- Physical risk: placement-controllable parasitic delta may be dominated by cell/slew/buffering/CTS/macro-pin/path-migration.
