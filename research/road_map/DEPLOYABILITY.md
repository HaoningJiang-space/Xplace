# Deployability: the "+15.3% oracle" is actually a deployable 2-pass flow (2026-06-18)

A depth-first (#13) provenance trace of the criticality CSVs reframes the thesis's biggest open gate
(GOAL.md "Open gates": *"the +X% uses TRUE routed criticality; without a predictor there is no
deployable method"*). The trace shows the gate is largely **already resolved** — the method is not
oracle-dependent.

## 1. Provenance (code fact, `xplace_backend_ariane.tcl`)
One BASE placement (`XP_TAG=ar_base`) is routed once. From that single base+route the back-end dumps
TWO net-slack CSVs:
- **line 28** `*_place_netslack.csv` = `estimate_parasitics -placement` slacks → the **est** criticality.
- **line 41** `*_netslack.csv` = post-`global_route` `estimate_parasitics -global_routing` slacks → the
  **routed** criticality.

The scored arms (`arm_routed`, `arm_est`, `union`, `fairest`) are **different re-placements** that
consume one of those CSVs as `--oracle_timing_file` (`ariane_arms.sh:6`, `ariane_fair.sh:7`). The
criticality is taken from routing the **base**, NOT from routing the arm being scored.

## 2. Two consequences
1. **No circularity / no leak.** The routed criticality predicts critical nets for a *subsequent,
   different* placement. It is genuinely predictive, not a self-fulfilling readout of the scored arm.
2. **It is a deployable 2-pass flow, not an oracle.** The pipeline is literally:
   ```
   place(base) → route(base) → extract per-net routed slack → re-place(weighted by it) → route
   ```
   This is the standard industrial timing-closure structure (place → trial route → re-place). Nothing
   here requires knowledge unavailable at deployment — pass-1's route is a real route.

## 3. What R33's +15.3% therefore MEANS (corrected framing)
est and routed criticality come from the **same base placement + same route** — the ONLY difference is
whether the pass-1 *routing* result is consulted (routed) or only the pass-1 *placement* estimate (est).
So:

> **+15.3% post-route TNS at signoff = the value of consulting pass-1 routing feedback when weighting
> pass-2 placement, on ariane.** A 2-pass flow that ignores its first route (est) leaves 15.3% on the
> table vs one that uses it (routed/union).

This is a deployable-method claim, not a ceiling claim. The "oracle" label in earlier notes was a
misnomer — it is a first-pass routed criticality, which every 2-pass flow possesses.

## 4. Honest remaining caveats (the real, narrower gates)
1. **Pass-1 ≠ pass-2 routing.** Re-placement changes routing, so pass-1 routed criticality is a
   *predictor* of pass-2's true critical nets, not identical to it. It evidently transfers (+15.3%),
   and **union** (est ∪ routed) is the robust hedge (R23) against nets pass-1 routing de-emphasized.
   → To fully close: a **fixpoint** check (does pass-3 with pass-2's routed criticality gain more, or
   has it converged?). R33 §status flagged a fixpoint experiment; run it for convergence evidence.
2. **Cost.** 2-pass doubles place+GR. Justified for timing closure (industry runs many passes), but
   state it. The cheaper in-loop alternative = feed Xplace's OWN in-loop GGR routed RC to the GPUTimer
   (UNIFICATION bridge) → routed criticality WITHOUT a full external route. That remains the efficiency
   upgrade, not a correctness prerequisite.
3. **Baseline fairness for #12.** The honest comparison is routed-criticality 2-pass vs **est-criticality
   2-pass** (= R33, both 2-pass, same base) — already shows routed/union > est. NOT vs a 1-pass placer
   (that would conflate "2 passes" with "routed criticality"). Keep the 2-pass-vs-2-pass framing.

## 5. Net effect on the roadmap
- The make-or-break "oracle→predictor" gate is **downgraded from blocker to efficiency-optimization**:
  a deployable method already exists (2-pass routed-criticality re-placement, +15.3%). The predictor /
  in-loop-GGR-STA bridge makes it CHEAPER, not POSSIBLE.
- The strong #12 claim becomes attainable purely on existing infra: routed/union 2-pass vs est 2-pass
  (done, +15.3%) and vs production `--timing_opt` force-matched (running). No ML predictor required for
  the first DAC-worthy result; the predictor is a follow-on efficiency contribution.
- **NEXT to harden this:** (a) fixpoint/convergence run (pass-3); (b) confirm the 2-pass framing holds
  on the bp_fe negative control (low divergence → small gain, as predicted); (c) write the method as a
  2-pass flow in the paper, not an oracle.
