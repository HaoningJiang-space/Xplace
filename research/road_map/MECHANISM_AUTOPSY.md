# MECHANISM AUTOPSY — "the result is real, but the explanation isn't yet" (2026-06-18, user-directed)

The user's deep investigation (2026-06-18): R33/R36 signoff numbers are CREDIBLE (verified from the remote
`ariane_infl_dr_true_results.txt` / `backend_infldr2_*` raw logs, NOT the stale `ariane_inflate_fidelity_*`
which still has the DR_TNS==GR_TNS bug — that file must not be cited). **+15% is not a collector false-
positive.** But the MECHANISM EXPLANATION and the DIVERGENCE TRIGGER have 口径 (measurement-basis) problems
big enough to threaten the paper's main line. Priority is NOT a 2nd design — it is mechanism autopsy.

## The 4 confirmed problems
1. **The actuator is NOT an STA timing gradient — it is geometric wirelength pull.** Confirmed in
   `wirelength_timing_cuda_kernel.cu:46` (`wa_wirelength_pin_root_timing_kernel`): `timing_pin_weight[pin_id]`
   (run_placement_nesterov.py:492 = `scale·net_crit` BROADCAST to every pin of the net) is a per-pin
   multiplier on the PIN-ROOTED weighted-average WIRELENGTH gradient (lines 121-123); `net_weight` is unused.
   So the "timing force" = extra WL pull on the pins of selected critical nets. **The +15% may be a weighted
   geometry / fanout effect, not "routed timing reordering."**
2. **The divergence "law" mixes ests.** R33 gain uses FAIR metal5 est baseline; the "Jaccard < 0.4 threshold"
   uses DEFAULT metal3 est. Remote recompute (vs same routed CSV): metal3 top-10% Jaccard 0.231; **fair metal5
   top-10% Jaccard 0.517** (and top-13k 0.459). → ariane is ABOVE 0.4 under the SAME est as its gain. **The
   +15% gain holds; the "0.4 threshold law" does NOT** (also DIVERGENCE_METRIC_CONSISTENCY.md).
3. **top-K is unfair across designs.** Arms use fixed `--oracle_topk 13000`: ariane ≈ 7-10% of nets, bp_fe ≈
   45-46%. Confound (RESULTS.md:646). Key table must be rerun at a CONSTANT FRACTION + matched gradient norm.
4. **est/routed criticality are not the same STAGE.** Backend dumps `estimate_parasitics -placement` BEFORE
   CTS; routed slack AFTER CTS+DP+GR (xplace_backend_bpfe.tcl:29). So measured "divergence" includes
   CTS/netlist/stage changes, NOT pure routing-parasitic reordering.

## One-line judgment (the user's, internalized)
**结果是真的，但解释还没真.** The danger is not a crashed harness — it is that the PAPER CLAIM is bigger than
what the implementation actually proves. The mechanism story ("routing reorders true timing criticality") and
the predictive law are NOT yet earned; only "union-criticality net-weighting → +15% post-route TNS on ariane
at 0-DRC signoff" is earned.

## The autopsy (user-prescribed, ordered) — do THIS, not a 2nd design
1. **Same-stage criticality (fixes #4):** on ONE post-CTS/post-DP netlist, dump est (`estimate_parasitics
   -placement`) BEFORE route and routed (after route+SPEF) — then Jaccard. Removes the CTS/stage confound.
   Is the est-routed divergence still large when stage is held fixed?
2. **★ per-critical-load-pin weighting vs per-net-min broadcast (fixes/tests #1 — the decisive mechanism
   test):** today a net's worst-slack is broadcast to ALL its pins (driver + all sinks) → high-fanout nets
   get more TOTAL pull (geometry/fanout bias). Test weighting ONLY the critical load pin(s), and/or
   FANOUT-NORMALIZING (total pull per net ∝ 1, independent of degree). If the +15% SURVIVES → the gain is
   about WHICH nets (timing-like). If it COLLAPSES → the gain was fanout/geometry. **This is the load-bearing
   experiment.**
3. **Finite-difference mechanism check:** step along the current timing gradient, legalize, reroute through
   the SAME backend, measure real DR+OpenRCX TNS — does it improve in the predicted direction? Validates the
   gradient is a true descent direction for post-route timing, not an artifact.
4. **Redo the divergence table with unified 口径:** single consistent est (fair metal5 for ALL designs),
   single top-FRACTION (not fixed K), matched force norm. THEN re-state any trigger.

## Status of the claims after this critique
- **EARNED:** union-criticality net-weighting beats fair-est by +15.3% post-route coupling TNS on ariane at
  0-DRC signoff (R33), and beats force-matched `--timing_opt` by +15.0% (R36). Numbers verified from raw logs.
- **NOT EARNED (tempered to hypotheses):** (a) the mechanism is "routed-timing reordering" (could be
  fanout/geometry — autopsy #2); (b) the "Jaccard < 0.4 threshold law" (est-dependent — #2/#4); (c) the
  cross-design trigger (unfair top-K, mixed est, mixed stage — #3/#4).
- **Process fix:** backport the bp_fe driver's strict DRC=0 + no-DRT_FAIL gates to the ariane collector; never
  cite `ariane_inflate_fidelity_results.txt` (stale DR==GR bug).

## codex harness audit (independent, same session) — CONFIRMS the user + 2 additions
codex's adversarial audit of divergence.py/div_frac.py/dump_netslack/the arm scripts ranked 3 risks:
1. **Mixed K / fraction / universe invalidates the law calibration** (= user #2/#3). Fix: constant fraction
   (--oracle_topfrac now implemented), single est.
2. **dump_netslack compares different circuit STAGES / key sets** (= user #4: est pre-CTS, routed post-CTS).
3. **Oracle arms can be silently weakened by EXACT net-name matching** (no canonicalization; net_names from DEF
   vs OpenROAD get_full_name). + **Spearman tie bug:** divergence.py's Spearman does NOT average ties and
   includes the huge zero-criticality tie mass → **Spearman is untrustworthy** (so bp_multi's "Spearman 0.776
   disambiguation" is suspect; the Jaccard-based law is unaffected, but demote/scipy-fix Spearman).
**Net-match VERIFIED (codex risk 3 does NOT invalidate the +15%):** ariane est and union arms BOTH match the
SAME **146654/183496 nets** (~80%, identical count across arms) → the est-vs-union comparison weights the same
matchable universe, so the +15% RELATIVE gain is internally fair. Caveat: ~20% of nets (likely escaped-name /
special) get ZERO weight in ALL arms — an absolute-completeness gap, not a relative-comparison bias.

## Reframed contribution (until the autopsy resolves the mechanism)
"A 2-pass route-feedback net-weighting that reduces post-route TNS by ~15% on a macro-congested design at
signoff" — an EMPIRICAL result whose MECHANISM and GENERALITY are under active autopsy. Do not write the
mechanism story or the law into the paper until autopsy #2 (per-pin/fanout) and #4 (unified 口径) resolve.
