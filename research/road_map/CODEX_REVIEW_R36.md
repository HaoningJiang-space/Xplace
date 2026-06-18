# Codex adversarial review of R33–R36 (2026-06-18) — 3 valid critiques + settling tests

codex-cli 0.140.0, first-principles adversarial pass (GOAL #2). Verdict: results stand but **claims are
not yet bulletproof**. Three issues, each with the test that settles it. Claims tempered accordingly.

## Issue 1 — the R36 production baseline is NOT yet fair (the HPWL argument is weak)
- **Critique:** "union is looser (2.819e7) yet times better, so area didn't buy timing" is UNSOUND. The
  looser HPWL may itself buy the very thing that helps timing — lower congestion, cleaner layer
  assignment, less coupling, fewer detours. "Looser-yet-better" does not prove area is neutral. AND I
  only detuned `--timing_init_weight`; a real user tuning production `--timing_opt` would also sweep
  `target_density`, cell-inflation strength, and route/congestion force.
- **Settling test (0-DRC signoff Pareto sweep):** sweep `--timing_opt` over
  `timing_init_weight × target_density × route_force/inflation`; sweep `union` over weight/scale/top-K/
  density to hit BOTH HPWL ≈2.65e7 AND ≈2.82e7. Compare best OpenRCX-coupling TNS **at matched density,
  matched routed-wirelength, via count, congestion, and DR effort.** If tuned `--timing_opt` reaches
  ≈−823.7, the SOTA claim collapses. → This is the real #12 experiment; R36's single matched-ish point
  is a first datapoint, not the Pareto proof.
- **Tempered claim:** R36 shows that *at its loosest routable operating point*, `--timing_opt` (−968.9)
  is beaten by union (−823.7); it does NOT yet show union Pareto-dominates a fully-tuned `--timing_opt`.

## Issue 2 — "fair-est == timing_opt ⇒ source not actuation" is OVERCLAIMED
- **Critique:** the tie (fair-est −972.5 ≈ `--timing_opt` −968.9) is at ONE detuned operating point on
  ONE design. It could be a timing floor, a routability floor, a TNS-redistribution coincidence, or a
  bad estimated-criticality ceiling that both est arms hit. It does NOT prove actuation is irrelevant.
  R33 cleanly isolates SOURCE only *within* the flat net-weight mechanism — not against the production
  GPUTimer exponential formula.
- **Settling test (the 2×3 crossed matrix at matched force/density):**
  | source | flat net-weight | production GPUTimer exponential |
  |---|---|---|
  | est | ✓ (fair-est) | ✓ (`--timing_opt`) |
  | routed | ✓ (R33) | **needs build** |
  | union | ✓ (R33) | **needs build** |
  The two missing cells require **injecting routed/union criticality into the GPUTimer path** (Option 2,
  SOTA_COMPARISON_DESIGN.md). If SOURCE gives +15% under BOTH formulas and the formula delta stays ≈0,
  the source claim holds. Also check WNS, #violating endpoints, endpoint overlap, period sweep — if both
  est arms fail on the SAME immovable endpoints, the tie is just a floor.
- **Tempered claim:** the tie is *consistent with* source-dominance but is not proof; the crossed matrix
  is required. This makes Option 2 (inject routed crit → GPUTimer) a PRIORITY, not optional.
- **★ DEEPER (first-principles, reading `timing_opt.py::step`): the matrix is PARTLY PRE-FILLED, and it
  REFUTES "source not actuation".** `step()` computes per-pin weight from the LIVE STA on ESTIMATED RC
  (slacks/delay_k/delay_1/pin_visited) via a 3-term EXPONENTIAL path formula. The ONLY way to feed it
  routed criticality is `set_net_rc_mult` (routed RC into the model) — which is **exactly R15/R16**, and
  R15/R16 HURT MONOTONICALLY (−2600→−2817→−2992 at GR; route-aware RC into the GPUTimer over-concentrates,
  adds congestion). So the crossed matrix already reads:
  | source | flat net-weight | GPUTimer exponential |
  |---|---|---|
  | est | −972 (fair-est) | −969 (`--timing_opt`) |
  | routed | **−832 (R33) BEST** | ≈ R15/R16 (HURT) |
  → The honest claim is NOT "source not actuation". It is: **routed criticality is only harvestable with a
  GENTLE (flat, top-K) actuation; the production EXPONENTIAL path-pull squanders it (over-concentrates →
  congestion, R15).** BOTH source and actuation matter, in a specific interaction: (routed source × gentle
  actuation) is the unique winning cell. This is a STRONGER, more mechanistic claim than the overclaimed
  "source not actuation" — and it explains why production `--timing_opt` (exponential) can't naively
  benefit from route-awareness. **Option 2's clean test = the (routed × exponential) signoff cell to
  confirm R15's GR-fidelity negative holds at signoff; R15 strongly predicts it does.**

## Issue 3 — the divergence law + deployability are UNDERPOWERED
- **Critique:** two anchor designs (ariane high-div, bp_fe low-div) do not establish a law; bp_fe may
  just be an operating point where all methods saturate. Deployability is not circular in the obvious
  sense, but it IS a stale-label transfer claim: pass-1 routed criticality must predict pass-2's critical
  nets *after the re-placement changes routing*.
- **Settling tests:**
  1. **Pre-register 4–6 designs / density variants spanning divergence**, ESPECIALLY an
     intermediate-divergence MACRO design. For each: compute pass-1 agreement BEFORE pass-2, predict
     apply/skip, measure 0-DRC signoff gain. (bp_be_top floorplan now running = step 1 of this.)
  2. **ariane cross-base / fixpoint matrix:** extract routed criticality from {cold, fair-est,
     timing_opt, union} bases → drive pass-2 from each → then pass-3 from pass-2's route. If gains depend
     on the chosen base OR don't converge, the 2-pass method is a fragile ariane-specific route
     fingerprint, not a deployable law.
- **Tempered claim:** the divergence law is a strong 2-point DIRECTION with a confirming negative
  control, not yet a calibrated multi-design law; deployability is a 1-pass-route stale-label transfer
  that works on ariane but needs cross-base robustness + convergence evidence.

## Action priority (reorders the roadmap)
1. **bp_be_top** (running) → 3rd design + intermediate-divergence candidate (Issue 3.1).
2. **Option 2: inject routed/union criticality into the GPUTimer** → the 2×3 crossed matrix (Issue 2).
   This is now load-bearing for the central source-vs-actuation claim, not a nice-to-have.
3. **ariane Pareto sweep** (timing_opt × density knobs vs union × density) at 0-DRC signoff (Issue 1) —
   matched density/wirelength/via/congestion, not a single point.
4. **ariane cross-base/fixpoint convergence** (Issue 3.2).
All four are pre-conditions for a defensible STRONG-SOTA (#12) claim. R33's +15.3% (source within flat
net-weight, iso-mechanism iso-HPWL) remains the ONE clean, un-criticized result; everything else needs
the hardening above.
