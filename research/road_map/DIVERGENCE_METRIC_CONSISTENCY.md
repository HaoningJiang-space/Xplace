# The divergence-law threshold is EST-TIMER dependent (2026-06-18, depth-first / 不失真, goal #13)

Acting on codex chain-review #3/#8 (Jaccard fidelity mismatch) + the prior CODEX_CHAIN_REVIEW.md "post-hoc
classifier" worry, I recomputed ariane's est-vs-routed top-K Jaccard with BOTH est timers against the same
routed CSV (`ar_base_netslack.csv`), using the committed `div_frac.py` logic.

## The finding (verified, recompute-only)
| est timer (vs the SAME routed `ar_base_netslack`) | top-5% Jaccard | top-10% Jaccard |
|---|---|---|
| metal3 / platform-default placement-est (`ar_base_place_netslack.csv`) | 0.244 | **0.231** |
| **fair metal5 est** (`ar_est_metal5_netslack.csv`) — the R29/R33 +15.3% gain baseline | 0.331 | **0.517** |

**DIVERGENCE_LAW.md's headline "ariane top-10% Jaccard 0.231, uniquely below the ~0.4 threshold" is computed
with the metal3/DEFAULT est. But the +15.3% signoff gain (R33) is measured against the FAIR metal5 est** —
the honest baseline adopted in R28/R29 precisely because R28 found the metal3 est is ~39× over-pessimistic
(metal3 R = 3.57e-3 but GR routes critical nets on metal6/7/8, ~19× lower R).

**Recomputed consistently with the fair metal5 est, ariane's top-10% Jaccard is 0.517 — ABOVE the claimed
0.4 threshold.** The other table values (aes 0.545, bp_multi 0.619, bp_be 0.666, bp_fe 0.963) are computed
with each design's DEFAULT placement-est — VERIFIED: recomputing bp_fe default-est vs routed gives top-10%
Jaccard 0.963, matching the table exactly. So **the 5-design table is internally consistent (all default-est);
ariane IS uniquely below 0.4 in that consistent default-est metric.**

## CORRECTED scope (after the bp_fe verification — the earlier "threshold law collapses" was OVERSTATED)
The precise, verified situation is narrower and more nuanced than "the law collapses":
1. The divergence TABLE is consistent (default-est across all 5 designs); ariane (0.231) is genuinely the
   unique low-divergence design IN THAT METRIC.
2. The ONLY mismatch is design-internal to ariane: its METRIC uses default(metal3)-est (0.231) but its GAIN
   BASELINE uses fair metal5-est (+15.3%). **This mismatch is CONSERVATIVE, not inflating** — the gain is
   measured against a STRONGER (fairer) baseline than the default est the trigger sees, so a default-est-using
   deployed flow would see an *equal-or-larger* gain. So the mismatch does NOT cheat the +15%.
3. The genuine residual concern: the TRIGGER value is est-sensitive (ariane 0.231 at default vs 0.517 at
   fair). A clean law must commit to ONE est for both the trigger and the (re-measured) gain. **R29 evidence
   REASSURES here:** fair-est placement (−2735) ≈ default-est placement (−2685) — switching to a
   less-pessimistic est did NOT change the placement; only the ACTUAL ROUTED criticality gave the +15%. So
   the gain mechanism is routed-criticality (robust to est choice), which SUPPORTS the law rather than
   undermining it.
4. Honest net: the **+15% is solid and arguably conservative**; the **"threshold 0.4" NUMBER is est-dependent
   and must not be quoted without naming the est**; the law as a DIRECTION (ariane uniquely divergent under
   the deployable default-est) holds. What's still needed: state the trigger's est explicitly, and ideally
   confirm the direction survives if the whole table is recomputed at a fair est (others' fair-est unknown).

## Why it matters (tempers the "predictive law", does NOT touch the +15.3% gain)
1. **The +15.3% gain stands** — it is union vs fair-est at 0-DRC signoff coupling (R33/R36), unaffected.
2. **The "threshold law / ariane uniquely below 0.4" framing is NOT robust to the est-timer choice.** The
   clean separation of ariane from the pack exists only when the metric uses the pessimistic metal3 default
   est. With the fair est (the one the gain is measured against), ariane is 0.517 — not below 0.4, not an
   obvious outlier.
3. **So the oracle-free TRIGGER is partly a detector of "is the platform-default est badly miscalibrated for
   this design" (a layer-assignment/RC artifact, R28), not a pure routing-divergence signal.** ariane's
   default est is uniquely bad (132 fixed macros force long nets onto low-R upper metals the metal3 est
   can't see) → large default-est-vs-routed divergence → the trigger fires. That is still arguably a
   *deployable* signal (a deployed flow DOES have only the default est), but it is NOT the clean
   "routing reorders true criticality" law the doc claims, and it is **internally inconsistent to quote a
   metal3-est divergence next to a metal5-est gain.**

## Required fix (before the law can be stated)
- Recompute the 5-design divergence table at a SINGLE consistent est fidelity — and the SAME est used as
  each design's gain baseline. Either (a) all default-est (then ariane 0.231 is comparable, but the gain
  baseline must also be default-est — R29 showed metal3-est placement −2685 ≈ metal5-est −2735, so re-measure
  the gain vs default-est too), or (b) all fair-layer est (then ariane 0.517 and the "threshold 0.4" claim
  must be withdrawn or relocated).
- Decide which est the TRIGGER uses and state the gain against the SAME est. Mixed ests = not publishable.
- Honest fallback framing (consistent with CODEX_CHAIN_REVIEW.md): drop "law"; keep "a deployable two-pass
  route-feedback flow with one signoff-validated high-divergence rescue case (ariane, +15%), where the
  pass-1 default-est-vs-routed disagreement is a heuristic indicator that route-feedback is worth a 2nd pass."

## Side finding (codex #5, same session, verified): union top-K is normalization-sensitive
Recomputed the ariane union top-13k SET under three normalizations of the two CSVs:
- own-norm (current `blend_crit.py`, ÷ each file's own max_neg) vs rank-percentile: Jaccard **0.79**
- own-norm vs raw-ns (common scale, no per-file norm): Jaccard **0.60**
- own-norm union leans routed-ward (Jaccard 0.75 with routed top-K vs 0.60 with est top-K).
So **20–40% of the union top-K set is an artifact of the normalization choice** — codex #5 is real. The
"confidence-weighted union" better-method (`blend_crit_conf.py`, staged) should be evaluated against this:
report results under all three normalizations, or justify own-norm.

## Scripts / repro
`div_frac.py` (committed), CSVs `ar_est_metal5_netslack.csv` (metal5), `ar_backend/ar_base_place_netslack.csv`
(metal3 default), `ar_backend/ar_base_netslack.csv` (routed). Normalization check: `norm_check.py`.
