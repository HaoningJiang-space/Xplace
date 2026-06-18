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

## ★★★ P1 RESULT (GR fidelity) — CONCERNING: the union-over-est gain does NOT survive matched force norm
ariane, est(metal5) vs union, broadcast vs fanout_norm, at `--oracle_topfrac 0.10 --timing_force_frac 0.1`
(constant fraction + MATCHED force norm). droute_TNS (GR):
| arm | mode | HPWL | droute_TNS |
|---|---|---|---|
| est | broadcast | 2.344e7 | −3168.3 |
| union | broadcast | 2.342e7 | **−3196.8 (WORSE than est)** |
| est | fanout_norm | 2.347e7 | −3160.5 |
| union | fanout_norm | 2.344e7 | **−3196.1 (WORSE than est)** |
- Contrast R29 (raw scale 1.0, NO force_frac): est −2735, union −2454 (+10%). **The +10% GR gain DISAPPEARS
  (slightly reverses) once the timing force NORM is matched.** broadcast≈fanout_norm → not even a fanout
  effect at this force; it's a FORCE-MAGNITUDE effect: at scale 1.0 union pulls harder (more/higher-fanout
  weighted nets) → more timing improvement; equalize the force and the criticality SET stops mattering.
- **This is the autopsy's central risk realized at GR:** the union-over-est advantage was tied to force
  magnitude, not to a better criticality set. frac 0.1 may also just be TOO WEAK (both arms barely perturb:
  HPWL 2.34e7 ≈ no-timing baseline, TNS worse than R29's stronger-force −2735) → a force SWEEP is needed to
  see if ANY matched-force level shows union>est.
- **DECISIVE next (the +15% is a SIGNOFF claim, this is GR):** (a) GR force-frac SWEEP {0.1,0.2,0.3,0.5}
  est-vs-union fanout_norm — does union beat est at ANY matched force? (b) the SIGNOFF (cell-inflate+DR+
  OpenRCX) R33 comparison RE-RUN with force_frac+fanout_norm — does the +15% survive fair controls at
  signoff? If neither shows union>est at matched force → the +15% is a magnitude/fanout artifact (the
  "diagnostic paper" branch, METHOD_DERIVATION §8).

## ★★★ FRAC SWEEP (GR) — the mechanism SURVIVES: union beats est at matched force, frac 0.1 was just too weak
est vs union, fanout_norm, MATCHED force norm (`--timing_force_frac`), constant fraction 0.10, GR:
| frac | est droute_TNS | union droute_TNS | union vs est |
|---|---|---|---|
| 0.1 | −3168 | −3197 | −0.9% (too weak: both ≈ baseline, noise) |
| 0.2 | −3167 | −3088 | **+2.5%** |
| 0.3 | −3395 | −2943 | **+13.3%** |
| 0.5 | −3097 | −3024 | **+2.4%** |
- **At matched force norm AND fanout-neutral weighting, union beats est for all frac ≥ 0.2.** So the
  union-over-est advantage is NOT pure fanout (fanout_norm on) and NOT pure magnitude (force matched) — at a
  SUFFICIENT force level the union criticality SET genuinely helps. **P1's frac-0.1 "collapse" was a
  too-weak-force false alarm; the mechanism (criticality SET) is real.** This is the VCERF-positive branch.
- **Honest caveats:** GR fidelity (not signoff), single seed. est is NON-MONOTONIC/noisy across frac (−3097..
  −3395) → the headline +13.3% at frac 0.3 is partly est-side noise; the robust statement is "union ≥ est for
  frac ≥ 0.2, modestly (+2.5%) to +13%." Needs (a) SIGNOFF confirmation (cell-inflate+DR+OpenRCX at frac 0.3),
  (b) multi-seed to kill the est-noise. Run signoff-fair at frac 0.3 next.

## ★★ METHODOLOGY CORRECTION (user, 2026-06-18): the frac sweep is PARAMETER-TUNING, not a result
The "+13.3% at frac 0.3" is **HARKing**: I tried frac {0.1,0.2,0.3,0.5} and quoted the frac where *est*
happened to be WORST (−3395 vs −3097..−3168 elsewhere). Single-seed point comparisons cannot separate signal
from seed noise, and picking the favorable hyperparameter post-hoc is not evidence. **There has been NO
statistics.** The frac sweep is HYPOTHESIS-GENERATING only.
**The rigorous test (now running, `ariane_stats.sh`):** FIXED frac 0.3, fanout_norm, matched force, 3 arms ×
5 seeds:
- **est, union, and SHUFFLED-criticality** (`shuffle_crit.py`: permute criticality values across net names,
  seeded → a RANDOM net set of the SAME cardinality/force/frac/fanout — everything identical to union EXCEPT
  which nets).
- Report per-arm mean ± std + the PAIRED (same-seed) union−est and **union−shuffled** differences.
- **The decisive comparison is union vs SHUFFLED** (holds frac/force/cardinality/fanout fixed → the frac
  choice becomes IRRELEVANT): union ≪ shuffled ⇒ the ROUTED-CRITICAL nets specifically matter (criticality is
  real); union ≈ shuffled ⇒ any net set at that force helps ⇒ geometry/force, not criticality, and the whole
  union story is an artifact. This is the test that answers the user's "感觉是调参数，有没有概率" — it makes the
  conclusion a statistical claim against a null, not a tuned point.
**Until ariane_stats.sh returns, the "mechanism survives" claim is NOT established** — only "hypothesis from a
noisy sweep." (signoff-fair frac-0.3 single point is also single-seed → corroborating at best, not decisive.)

### codex autopsy review (independent, CONFIRMS user + refines the null) — verdict "mechanism survives? NOT YET"
1. Frac sweep is post-hoc/fragile; +13.3% leans on est being unusually bad at 0.3; +2.4/2.5% may be router noise.
2. Correct test = PAIRED multi-seed: per seed report `TNS_union−TNS_est`, mean/std/CI, sign/paired-t/Wilcoxon;
   report est & union variance separately; if sweeping fracs, PREDECLARE the primary frac or correct for
   selection.
3. **★ `--timing_force_frac` is only a GLOBAL force-budget control — it does NOT equalize effective per-net
   pull.** Union & est differ in selected-net SPAN, WA-grad norm, spatial location, density/congestion overlap,
   #tied nets, dilution. So force-matching removes the crude MAGNITUDE confound but NOT the geometry/SET
   confound. → the SHUFFLED NULL is the real isolating control.
4. A single signoff-fair frac-0.3 win is insufficient. Min bar: PAIRED multi-seed signoff at LOCKED frac,
   0-DRC/backend-complete logs, SAME-STAGE criticality, fanout_norm or endpoint weighting, and negative
   controls that do NOT reproduce the win.
5. **Cleanest decisive: stratified permutation P5 at locked frac, same seed, same cardinality, same
   DEGREE/geometry bins, same force:** est vs union vs shuffled-labels vs **random SAME-DEGREE/same-span nets.**
   If shuffled/random matches union → not criticality. If union beats the null distribution across paired
   seeds → the set claim starts to survive.
**Upgrade to the null (codex #5):** current `shuffle_crit.py` permutes across ALL nets (random degree) — with
fanout_norm that partly controls degree, but codex wants the null DEGREE-STRATIFIED (random nets matched to the
critical set's degree bins), because even fanout_norm leaves a spatial/degree geometry difference. Plan: run the
random-shuffle stats first (cheap first answer); if union beats random-shuffle, STRENGTHEN to a degree-stratified
null (replace each critical net with a random net in its degree decile — needs net-degree, compute in Xplace)
before claiming criticality. If union does NOT beat even the random shuffle → done, it's geometry/force.

## ★★★ SIGNOFF-FAIR (frac 0.3) — union does NOT beat est at signoff under fair controls
ariane, est vs union, fanout_norm, matched force (force_frac 0.3, topfrac 0.10), `--use_cell_inflate`, DR+OpenRCX:
| arm | HPWL | DR-coupling TNS | DR WNS |
|---|---|---|---|
| est | 2.624e7 | **−1236.9** | −0.624 |
| union | 2.782e7 | **−1258.9 (WORSE 1.8%)** | −0.640 (worse) |
- **CONTRADICTS the GR frac-0.3 +13.3%; CONVERGES with P1 frac-0.1** (union ≈ est). 2 of 3 fair-control tests
  (P1 frac-0.1, signoff-fair frac-0.3) show union ≤ est; the GR sweep's union-wins (+2.5/+13.3/+2.4%) now look
  like est-side single-seed NOISE (est was −3097..−3395 across fracs).
- **Emerging honest conclusion (pending multi-seed):** the R33/R36 +15% (measured at raw scale 1.0, BROADCAST,
  unmatched force) does NOT reproduce under fair controls (matched force + fanout-neutral) — it was a
  force-MAGNITUDE / fanout effect, NOT a criticality-SET effect. This is the METHOD_DERIVATION §8 "diagnostic
  paper" branch trending true.
- **NOT yet final:** single-seed. The chained `ariane_stats.sh` (est/union/shuffled × 5 seeds, paired) is the
  decider: if union ≈ est ≈ shuffled across seeds → artifact CONFIRMED; if union ≪ est & ≪ shuffled → criticality
  survives after all. HPWL caveat: union is LOOSER (2.782 vs 2.624) yet times worse → not an area effect either.

## Reframed contribution (until the autopsy resolves the mechanism)
"A 2-pass route-feedback net-weighting that reduces post-route TNS by ~15% on a macro-congested design at
signoff" — an EMPIRICAL result whose MECHANISM and GENERALITY are under active autopsy. Do not write the
mechanism story or the law into the paper until autopsy #2 (per-pin/fanout) and #4 (unified 口径) resolve.
