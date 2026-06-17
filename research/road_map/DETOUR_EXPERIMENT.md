# Level-A detour experiment: pre-registration + fidelity gate (2026-06-18)

Pre-registered BEFORE results (avoids post-hoc rationalization, GOAL #13). The differentiable
detour term (`src/core/detour_timing.py`) and its first ariane A/B (`research/server/ariane_detour_arc.sh`,
running). Coordinated with the parallel thread's R29 (GOAL.md): real ariane headroom is layer+detour,
**modest**; the +5.6%-vs-`--timing_opt` win comes from the criticality RANKING, and **detour is only
~4% of TNS on ariane (R18)**.

## 1. What Level-A actually tests
`L = Σ_v κ_v · len_v(x) · (1 + α·ρ_v(x))` adds a **congestion-modulated** criticality-weighted pull:
the working net-weight force (TERM1, the +20% lever), AMPLIFIED on critical pins sitting in congestion
(the pins most likely to be detoured). It does NOT change the criticality ranking (same oracle). So it
is a *geometric pre-emption of detour*, not a new criticality source.

## 2. Pre-registered expectation on ariane (honest, given R18/R29)
- **Most likely: small effect.** Detour is ~4% of ariane TNS (R18); holding criticality fixed and adding
  a detour-magnitude modulation should move post-route TNS only slightly. A LARGE gain would be
  *surprising and suspect* (likely a confound, investigate before believing).
- **Interpretation rule (fixed in advance):**
  - small positive at ~stable HPWL → detour lever has marginal value on ariane (consistent with R18);
    the real test of the detour lever needs a HIGH-detour design (not ariane).
  - flat → detour magnitude too small on ariane = EXPECTED, not a method failure.
  - HPWL blowup / TNS regression → weight too large (R25 lesson); reduce or apply `--timing_force_frac`
    auto-calibration to the detour term.
- **ariane A/B's real purpose** = a does-not-harm + plumbing-correct check on a real design + a magnitude
  sanity. It is NOT the test that can validate the detour mechanism (wrong substrate for that).

## 3. The make-or-break: FIDELITY GATE (codex arch-review risk #4)
The FD self-check only proved the gradient is what we *intended*; it does NOT prove the proxy ρ_v
predicts REAL routed detour. Codex: "elegant differentiation of the wrong simulator" is the first
reviewer attack. Two tiers, cheap first:

**Tier 1 — static correlation (cheap, reuses existing bridge route output):**
Per net/arc, correlate the proxy congestion/detour `ρ_v` (or `len_v·(1+αρ_v)`) at the placed solution
against the REAL routed detour `ℓ_routed/ℓ_est` (from the bridge's OpenROAD route, already dumped).
- Pass: Spearman(ρ_v, real_detour) meaningfully > 0 on critical arcs → the proxy ranks detour-prone
  arcs correctly. Fail: proxy is the wrong signal → replace pin-density ρ with GR-demand/RUDY before IFT.

**Tier 2 — gradient-direction agreement (the rigorous gate):**
Pick K critical arcs; perturb endpoint positions ±δ; for each, run REAL reroute (OpenROAD GR) + STA →
measure Δ(routed TNS). Compare sign / cosine vs the detour term's predicted Δ.
- Pass: sign-agreement on a majority / cosine > 0.3 → the proxy gradient points the right way → IFT
  (IMPLICIT_DIFF_TIMING.md) is worth building. Fail → fix the proxy first; IFT on a wrong proxy is wasted.

## 4. Decision flow
1. ariane A/B (running) → does-not-harm + magnitude. (expect small per §2)
2. Tier-1 correlation (cheap, next) → is ρ_v even the right detour signal?
3. If Tier-1 passes → Tier-2 on a few arcs → then IFT. If Tier-1 fails → swap ρ (pin-density →
   GR-demand from gpugr `dmd_map`/`cap_map`) and re-test BEFORE any IFT investment.
4. Independent of all: the detour lever's true headroom needs a HIGH-detour design (ariane is low-detour,
   R18). Identify one (candidates: congested ISPD/ASAP7-real, or bp_fe at tighter util).

## 5. First-principles note (why this ordering)
The mechanism chain is x → routing-response → parasitics → timing. We have verified the LAST mile
(criticality ranking, +5.6%). The detour term attacks the FIRST mile (x → routing-response) via a
proxy. Validating the proxy against the real router (fidelity gate) BEFORE differentiating it (IFT) is
the correct dependency order — exactly GOAL #13 (understand the mechanism before building on it).

## 6. RESULTS (2026-06-18) — NEGATIVE, and what it does / does not show
ariane, oracle routed criticality fixed (scale 1.0), arc-level detour added:
| arm | HPWL | droute_TNS | wirecap_fF |
|---|---|---|---|
| base (no detour) | 2.4455e7 | **−2400.98** | 542112 |
| +arc w=0.02 | 2.4959e7 (+2.1%) | −2552.4 (worse) | 560337 |
| +arc w=0.10 | 2.5892e7 (+5.9%) | −2904.7 (worse) | 576179 |

- Baseline reproduces the known −2401 routed-oracle result → harness correct.
- The detour force **monotonically HURTS** post-route TNS while inflating HPWL + wirecap.
- **Converges with R15/R18/TERM-2:** the detour-MAGNITUDE lever has no headroom on ariane (detour
  ~4% of TNS); the value is the criticality RANKING, not a detour force. A NEW (differentiable,
  arc-level) mechanism independently re-confirms the established negative for the magnitude lever.
- **CONFOUND (honest, codex R11-audit flaw-2):** the detour force is ADDED on top of the oracle
  net-weight WITHOUT force-matching → HPWL↑ may be "more pull" not "wrong detour direction." So this
  does NOT cleanly isolate the detour signal's direction. A force-matched test (rescale total timing
  force, like --timing_force_frac) is needed to isolate.
- **Implication for IFT:** IFT is a more-exact version of THIS detour lever → on low-detour ariane it
  would also lack headroom. **Do NOT build IFT until (a) a force-matched test isolates direction AND
  (b) a HIGH-detour design shows the lever has headroom.** The fidelity-first ordering just saved the
  IFT build effort — the point of GOAL #13.

## 7. NEXT (diagnose lever-weak vs proxy-wrong, before any IFT)
1. **Tier-1 correlation** (cheap, reuses bridge route): Spearman(proxy ρ_v / detour-factor, REAL
   routed detour ℓ_routed/ℓ_est) on critical arcs. If ≈0 → proxy is the wrong signal (fix ρ:
   pin-density → gpugr GR-demand). If >0 → proxy ranks detour correctly but the lever is just weak
   on ariane → need a high-detour design.
2. **Force-matched re-test** (rescale so ‖timing+detour‖ = ‖timing‖) to remove the over-pull confound.
3. **High-detour design** hunt — ariane is low-detour (R18); the detour lever can only be fairly
   tested where detour is a large TNS fraction.

## 8. CONFOUND RESOLVED (matched-HPWL small-weight sweep) — conclusion REVISED
The §6 "monotonic regression" was dominated by OVER-PULL (force not matched). Small-weight sweep at
≈baseline HPWL:
| arm | HPWL | dplace_TNS | droute_TNS |
|---|---|---|---|
| base | 2.4455e7 | −206126 | −2400.98 |
| arc w=0.002 | 2.4522e7 (+0.27%) | −182857 (better) | **−2368.1 (better, +1.4%)** |
| arc w=0.005 | 2.4424e7 (−0.13%) | −214140 (worse) | −2469.3 (worse) |

- **Direction NOT falsified.** At matched HPWL (w=0.002) the arc-detour term improves BOTH placement-
  stage AND post-route TNS (−2368 vs −2401, +1.4%). The earlier regression was over-pull, not wrong
  direction. The confound mattered — resolving it flipped the conclusion (GOAL #13: don't leave confounds).
- **But the effect is SMALL and weight-sensitive** (w=0.005 is worse on both metrics → likely within
  single-seed noise). Consistent with the pre-registration: detour is ~4% of ariane TNS (R18), so even
  a correct detour force can only move post-route TNS marginally here.
- **Honest status:** marginal positive, NOT yet robust (needs multi-seed to rule out noise; non-monotonic).
- **IFT implication (revised):** the detour direction is plausibly correct → IFT (its exact form) is NOT
  dead. But ariane's headroom is too small to justify the IFT build on its own. Gate IFT on a HIGH-detour
  design showing a LARGE, robust detour effect.

## 9. NEXT (revised)
1. **Multi-seed at w≈0.002** (3 seeds) — is the +1.4% real or noise? (cheap, decides if there's any signal).
2. **Finer weight bracket** (0.001, 0.002, 0.003) at matched HPWL — find the sweet spot / confirm shape.
3. **HIGH-detour design** (the real test, DETOUR_EXPERIMENT §7.3) — only there can the detour lever show
   strong headroom; ariane is structurally low-detour.
4. Tier-1 proxy correlation still wanted (needs per-net routed length dump — add to backend tcl).
