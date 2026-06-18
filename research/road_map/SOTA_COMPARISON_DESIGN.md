# SOTA comparison design — how to cleanly beat Xplace `--timing_opt` (#12) (2026-06-18)

Written while the bp_fe negative-control signoff runs. Goal: design the **clean** placer-vs-placer
comparison that R34 could not deliver (mechanism-mismatch confound), grounded in the actual code paths.

## 1. The two timing paths are STRUCTURALLY DISJOINT (code fact)
`src/run_placement_nesterov.py:452`:
```python
if getattr(args,"oracle_timing_file","") and os.path.exists(...) and not args.timing_opt:
```
- **Path A — oracle** (our R19–R33 arms): reads a per-net routed/estimated worst-slack CSV → builds a
  STATIC per-pin `timing_pin_weight = scale · crit_n` (flat, graded, optional top-K). Fakes
  `data.gputimer = SimpleNamespace(timing_pin_weight=...)`. NO live STA.
- **Path B — `--timing_opt`** (Xplace production): constructs the REAL `GPUTimer`; `GPUTimer.step()`
  recomputes `timing_pin_weight` every iteration from the live RC/delay model via the 3-term
  **exponential path-based** formula (CLAUDE.md §Timing internals).
- They are **mutually exclusive** (`and not args.timing_opt`). You cannot today run the GPUTimer
  formula on oracle criticality.

**Both paths feed the identical consumer**: `calculator.py` `if ps.enable_timing:` adds the
per-pin-weighted WA gradient. So the ACTUATION (how the weight enters ∇) is the same object.
What differs between A and B is exactly two things:
1. **Weight FORMULA**: flat `scale·crit` (A) vs 3-term exponential, path-discounted (B).
2. **Criticality SOURCE**: a fixed CSV (A: est OR routed OR union) vs live estimated RC (B).

## 2. Therefore: what each existing result actually isolates
- **R33 (union vs fair-est, both Path A, signoff) = CLEAN criticality-SOURCE isolation.** Same flat
  formula, same scale 1.0, same top-K cardinality; vary ONLY est→routed→union. The +15.3% is
  attributable to the SOURCE with no formula confound. **This is the core thesis claim and it is clean.**
- **R34 (Path A union vs Path B `--timing_opt`) = CONFOUNDED.** It changes BOTH the formula (flat→
  exponential) AND drops the source control. The exponential pull over-concentrates (HPWL 2.46 vs
  2.82) → won't route at signoff. The confound is the formula, not the source.

## 3. The #12 question is genuinely a PLACER-vs-PLACER one
"Beat Xplace-Timing" means: our placer (Path A + routed/union source) must beat Xplace's production
timing placer (Path B) on **post-route TNS at iso-congestion**. Two honest ways to get there:

### Option 1 — FORCE-MATCH Path B down (no code; the immediate next run)
Sweep `--timing_init_weight` (default 0.05) DOWN until `--timing_opt`+inflate places at HPWL ≈ the
union arm's 2.82e7 (so both are equally routable / iso-congestion), route at signoff, compare TNS.
- Matches DENSITY (the routability confound R34 hit), still differs in formula+source — but that is
  the FAIR production comparison: "production Xplace-timing, tuned to the same congestion, vs ours."
- Cheap, no code. **This is the next ariane run once GPU 1 frees from bp_fe.**
- Risk: even force-matched, B's path-based formula may be better/worse independent of source → result
  interpretable as "our placer beats tuned production Xplace-timing" but NOT as pure source-isolation
  (R33 already owns the pure source claim).

### Option 2 — INJECT routed criticality INTO the GPUTimer formula (code; the clean version)
Make Path B's GPUTimer compute its exponential weights on ROUTED criticality instead of estimated.
This holds the production FORMULA fixed and swaps ONLY the source → the cleanest "production mechanism
+ our contribution" demonstration. Requires hooking `GPUTimer` to accept an external per-net/per-pin
criticality override (e.g. multiply `report_criticality` output or seed the RC with routed parasitics).
- Heavier; defer until Option 1's force-matched number is in hand (#13 — don't build before the cheap
  test answers whether it's even needed).
- This is ALSO the deployable-method shape (route-aware criticality → production timing engine), so the
  code is not throwaay: it converges with the oracle→predictor bridge (the make-or-break gate).

## 4. The strongest HONEST framing available right now
At SIGNOFF fidelity on ariane:
- **R33: our route-aware union criticality (Path A) = −823.7 TNS, 0 DRC violations.**
- **R34 incidental: production `--timing_opt` (Path B, default weight) does NOT converge to a clean
  route** (over-packs, GR stuck) → no valid signoff TNS at all.
So *even before* force-matching, the honest statement is: **our method yields a routable signoff-quality
timing placement where Xplace's production `--timing_opt` (default) does not.** Force-matching (Option 1)
converts this into a head-to-head TNS number by detuning B until it routes.

## 5. Decision (sequenced, #13)
1. [running] bp_fe negative-control signoff — is the SOURCE gain divergence-predicted (flat on
   low-divergence bp_fe)? Makes the thesis a LAW, not "always add routing".
2. [next, no code] ariane `--timing_opt` `--timing_init_weight` sweep → force-matched HPWL → signoff TNS
   vs union −823.7. The production placer-vs-placer #12 number.
3. [conditional] If Option 1 leaves ambiguity, build Option 2 (routed criticality → GPUTimer formula) —
   the clean production-mechanism source-swap AND the deployable method.
4. C3PO: not runnable here (NVIDIA, unreleased); Xplace-Timing (`--timing_opt`) is the achievable
   production SOTA bar. State this limitation explicitly.
