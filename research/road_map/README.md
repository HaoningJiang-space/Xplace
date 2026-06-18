# Road Map Index

This directory is the research notebook for route-aware timing placement. It now has many historical
branches, so use this file as the entry point.

## Current Canon

Read in this order:

1. [METHOD_DERIVATION.md](METHOD_DERIVATION.md) — current method definition and decisive falsification plan.
2. [MECHANISM_AUTOPSY.md](MECHANISM_AUTOPSY.md) — why the ariane result is real but the explanation is not
   fully proven.
3. [THESIS.md](THESIS.md) — paper-level story, kept but tempered by the autopsy.
4. [RESULTS.md](RESULTS.md) — append-only experiment log; use latest numbered entries first.
5. [RELATED_WORK.md](RELATED_WORK.md) — positioning against C3PO, Efficient-TDP, DGR, and timing/routing
   literature.

Current one-line state:

> The signoff +15.3% ariane result is credible, but the publishable method must be framed as
> verifier-calibrated route-feedback criticality selection, not as a proven post-route timing gradient.

## Active Questions

The next experiments should resolve these in order:

1. Does the ariane gain survive `--oracle_topfrac`, `--timing_force_frac`, and
   `--oracle_pin_weight_mode=fanout_norm`? Script: `research/server/oracle/ariane_autopsy_p1.sh`.
2. Does endpoint or critical-sink-only weighting preserve the gain with less fanout/geometry bias?
3. Does same-stage estimated-vs-routed divergence remain large after removing CTS/stage confounds?
4. Does a finite-difference step along the route-feedback force improve real DR+OpenRCX TNS?
5. Can the adaptive skip rule hold on low-divergence designs while finding a second high-divergence positive?

## File Map

### Current Method And Claims

- [METHOD_DERIVATION.md](METHOD_DERIVATION.md): primary method proposal, math, congestion/timing relation,
  and P1-P5 falsifiers.
- [THESIS.md](THESIS.md): coherent paper story, but its mechanism/law claims must be read through
  [MECHANISM_AUTOPSY.md](MECHANISM_AUTOPSY.md).
- [MECHANISM_AUTOPSY.md](MECHANISM_AUTOPSY.md): current truth boundary: result real; mechanism and law under
  autopsy.
- [DEPLOYABILITY.md](DEPLOYABILITY.md): two-pass deployability framing.
- [DIVERGENCE_METRIC_CONSISTENCY.md](DIVERGENCE_METRIC_CONSISTENCY.md): estimator/fidelity caveat for the
  Jaccard trigger.
- [DIVERGENCE_LAW.md](DIVERGENCE_LAW.md): older divergence-law statement; useful, but threshold language is
  not authoritative without the consistency caveats.

### Evidence Logs And Reviews

- [RESULTS.md](RESULTS.md): append-only result ledger. Do not treat old entries as current without checking
  later corrections.
- [CODEX_CHAIN_REVIEW.md](CODEX_CHAIN_REVIEW.md): thesis-level adversarial review.
- [CODEX_CHAIN_REVIEW_CODE.md](CODEX_CHAIN_REVIEW_CODE.md): code-level chain review; key for actuator and
  fairness flaws.
- [CODEX_REVIEW_R36.md](CODEX_REVIEW_R36.md): adversarial review of R33-R36 and SOTA comparison caveats.
- [SOTA_COMPARISON_DESIGN.md](SOTA_COMPARISON_DESIGN.md): how to compare against Xplace `--timing_opt`.
- [EXPERIMENT_PROTOCOL.md](EXPERIMENT_PROTOCOL.md): locked protocol notes; partially superseded by the P1-P5
  plan in [METHOD_DERIVATION.md](METHOD_DERIVATION.md).

### Mechanism Analyses

- [MATH.md](MATH.md): first-principles gradient decomposition and timing-priced congestion.
- [FIDELITY.md](FIDELITY.md): measurement and gradient-reality rules.
- [CRITICALITY_GRANULARITY.md](CRITICALITY_GRANULARITY.md): why endpoint/arc criticality is the right unit.
- [ANALYSIS_R15.md](ANALYSIS_R15.md): why route-aware RC correction hurt.
- [ANALYSIS_TERM2.md](ANALYSIS_TERM2.md): why raw route/congestion force hurt and how to price congestion.
- [DETOUR_EXPERIMENT.md](DETOUR_EXPERIMENT.md): detour-force experiments; current conclusion is weak/noisy
  value on ariane.
- [CEILING.md](CEILING.md): placement-controllable timing channels.

### Architecture Ideas And Parked Branches

- [FRAMEWORK.md](FRAMEWORK.md): older system synthesis; useful background, not the current entry point.
- [ROADMAP.md](ROADMAP.md): older broad roadmap; superseded by this index plus
  [METHOD_DERIVATION.md](METHOD_DERIVATION.md).
- [ESSENCE.md](ESSENCE.md), [INSIGHTS.md](INSIGHTS.md), [GOAL.md](GOAL.md): historical synthesis notes.
- [APPROACH_A.md](APPROACH_A.md), [BIDIRECTIONAL.md](BIDIRECTIONAL.md),
  [IFT_ROUTE_RESPONSE.md](IFT_ROUTE_RESPONSE.md), [IMPLICIT_DIFF_TIMING.md](IMPLICIT_DIFF_TIMING.md),
  [UNIFICATION.md](UNIFICATION.md), [DGR_PLAN.md](DGR_PLAN.md), [PROTOTYPE.md](PROTOTYPE.md): differentiable
  router/IFT/TERM-2 ideas. Parked until endpoint/fanout and finite-difference checks pass.
- [PATH_BASED_PIVOT.md](PATH_BASED_PIVOT.md): Efficient-TDP/path-based pivot notes; background for endpoint
  actuation, not the current implementation plan.

## Do Not Cite As Current

- `ariane_inflate_fidelity_results.txt` in remote result discussions: stale `DR_TNS == GR_TNS` output.
- Fixed `topK=13000` as cross-design evidence: use constant top fraction and matched force norm.
- A bare "Jaccard < 0.4 law": name estimator fidelity, stage, and top fraction.
- Claims that the current CUDA actuator is a true post-route STA gradient: it is a route-blind pin-root
  weighted wirelength pull.

## Update Rules

- Put new measured numbers in [RESULTS.md](RESULTS.md), then update this README only if the current canon or
  next actions change.
- If a result changes the main story, update [METHOD_DERIVATION.md](METHOD_DERIVATION.md) or
  [MECHANISM_AUTOPSY.md](MECHANISM_AUTOPSY.md), not only the result log.
- Mark old claims as caveated or superseded in place. Do not delete historical notes unless all references are
  audited.
- Prefer adding scripts and exact commands beside `research/server/oracle/`; keep road-map files for claims,
  evidence summaries, and decisions.
