# Codex CODE-LEVEL chain review (整个链路, 2026-06-18, codex-cli 0.140.0 gpt-5.5 xhigh)

Complements the THESIS-level [CODEX_CHAIN_REVIEW.md](CODEX_CHAIN_REVIEW.md). This pass read the ACTUAL CODE
end-to-end — Xplace net-weight injection (`run_placement_nesterov.py:451-497`), the CUDA actuator
(`wirelength_timing_cuda_kernel.cu`), the ORFS criticality dump (`xplace_backend_bpfe.tcl::dump_netslack`),
the signoff backend, the driver, `blend_crit.py` — and attacked the SIGNAL→OBJECTIVE chain. 11 findings.
Verified fact: in the CUDA kernel `net_weight` is passed but UNUSED; `timing_pin_weight` is the real
multiplier (confirms the run_placement_nesterov.py:449 comment; the `wa_wirelength_hpwl.py` cite is stale —
timing is exported via `core/__init__.py:5` ← `core/timing_opt.py:267`).

## Findings ranked (status = my triage)

### Mechanism-invalidating (the deepest — gain may not be FROM timing). These outrank a 2nd design.
1. **Actuator does not optimize the signoff quantity.** The placement force is route-blind pin-root WA
   wirelength; the objective is post-CTS+DR+OpenRCX setup TNS. Nothing proves shortening the weighted-WA
   proxy improves the weighted net's *routed* slack (can worsen congestion/coupling; can be dominated by
   cell delay/fanout/CTS). → Empirical ariane TNS gain STANDS, but the *mechanism* ("we optimize timing")
   is unproven. **Cheapest close: finite-difference — perturb cells ±along the timing gradient, reroute via
   the exact signoff backend, require routed TNS to move in the predicted direction.**
2. **Per-net worst-slack → all pins.** ORFS collapses each net to min load-pin slack; Xplace assigns it to
   EVERY pin; the kernel pulls every non-root pin toward the first hyperedge pin. This weights noncritical
   sinks + high-fanout geometry, not endpoint/path sensitivity. → The gain could be a fanout/geometry bias.
   **Cheapest close: per-CRITICAL-load-pin weighting vs per-net-min at matched force norm.**
4. **est (pre-CTS) vs routed (post-CTS+DP+GR) are not same-stage.** The "divergence" includes CTS/netlist
   stage effects, not only pre-route-estimate-vs-routed parasitics; CTS-created nets enter the routed CSV
   but can't be weighted by Xplace. → Pollutes the clean "routing reordered the critical set" story.
   **Cheapest close: dump est `estimate_parasitics -placement` AFTER CTS+DP, then route+dump on the same
   post-CTS netlist.**

### Law-invalidating-as-stated (the cross-design "scales with divergence")
3. **Routed-criticality source is GR-fidelity, not signoff.** CSVs use `estimate_parasitics -global_routing`
   (no OpenRCX coupling); the headline gain uses DR+OpenRCX+SPEF. Jaccard & gain at different fidelities.
   **Cheapest close: recompute top-K Jaccard from DR+OpenRCX per-net slack on the pass-1 placement.**
8. **top-K cross-design confound.** Arms use absolute `--oracle_topk 13000` = ~46% of bp_fe's 28k nets vs
   ~10% of ariane's 130k. Design size/macro/congestion/actuation-density can explain the cross-design gain
   difference without invoking Jaccard. (NOTE: DIVERGENCE_LAW.md already moved the *Jaccard table* to a
   consistent top-10%, but the *placement arms* still weight absolute 13k → inconsistent.) **Cheapest close:
   rerun arms at constant top FRACTION + matched force norm; within-design K/Jaccard sweep.**

### Comparison-fairness caveats
5. **Union membership is cross-timer-arbitrary.** Each CSV self-normalized by its own max_neg; `union=max`
   mixes two independently-scaled timers → can prefer "high percentile in est" over "larger absolute routed
   violation." Report top-K overlap under own-norm / common-ns / rank-percentile norm.
6. **"Force-matched top-K" not asserted.** `>= thresh` + cap-by-positive-count → ties/fewer-violating can
   change kept count; equal count still differs in pin-count/gradient-norm. Assert kept==K + matched degree.
7. **Round-trip identity unproven.** `matched X/Y nets` only proves string overlap, not that the top-K
   critical nets matched or that escaped/bus names preserve endpoint identity across the ORFS readback.
   Hash `net→sorted pin fullnames` before/inside Xplace/after ORFS; require 100% on the selected top-K.

### Reproducibility / robustness (cheap fixes)
9.  **Signoff continues after DR failure / dirty DRC.** `detailed_route` is caught then TNS still reported;
    ariane's collector doesn't gate on DRT_FAIL/DRC at all. (bp_fe driver now gates — this run verified
    0-DRC, no DRT_FAIL on all 3 arms.) **Backport the gate to the ariane collector.**
10. **Oracle silent fallback.** A missing `--oracle_timing_file` (or co-set `--timing_opt`) skips the oracle
    with no fatal error → an arm can silently run as no-oracle. **Assert the `Oracle timing_pin_weight: matched…`
    log line + matched/top-K counts in every driver.**
11. **`blend_crit.py` was out-of-repo.** FIXED: committed to `research/server/oracle/blend_crit.py`
    (sha256 5d99bfdf…3438a9). Logic confirmed = per-net max of each CSV's own-normalized criticality.

## Triage → plan (depth over a 2nd design, since mempool is blocked: no SDC/netlist in this ORFS checkout)
The deepest risk is #1/#2/#4: **the ariane +15% might be a geometry/fanout/CTS artifact, not timing
optimization.** A 2nd design cannot rescue the thesis if the mechanism on the ONE positive design is an
artifact. So the load-bearing work shifts to MECHANISM VERIFICATION on the existing ariane positive:
- **P1 (cheapest, recompute-only): #3 + #4** — recompute ariane est-vs-routed top-K Jaccard at (a) DR+OpenRCX
  fidelity and (b) post-CTS same-stage. If the divergence largely survives both → mechanism story holds; if
  it collapses → the "routing reorders criticality" claim was a fidelity/CTS artifact.
- **P2 (#2): per-critical-load-pin weighting vs per-net-min** at matched force norm on ariane — is the gain
  timing or fanout?
- **P3 (#1): finite-difference** — the decisive "do we actually move routed TNS" test.
- **Backport (#9/#10) gates to all collectors; FIXED #11.**
