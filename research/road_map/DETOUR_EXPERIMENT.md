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
