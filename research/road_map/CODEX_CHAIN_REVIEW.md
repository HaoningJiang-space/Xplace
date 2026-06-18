# Codex review of the WHOLE chain (整个链路) — 2026-06-18 (codex-cli 0.140.0)

Adversarial first-principles review of THESIS.md end-to-end (not line-edits). Verdict: the chain SURVIVES
as a DAC paper only under a NARROWER framing; three weakest links; one decisive experiment.

## (a) The 3 weakest links
1. **The "threshold law" is not yet a law — it's ONE positive outlier (ariane).** The other 4 designs prove
   "no gain when est≈routed," NOT "gain when Jaccard < 0.4 beyond ariane" (aes/bp_be unmeasured for gain,
   bp_multi GR-only). The threshold is effectively drawn between ariane and everyone else → a reviewer calls
   it a **post-hoc classifier** unless a 2nd low-Jaccard design GAINS.
2. **Mechanism ("reordering not magnitude", "strong actuation squanders") is overclaimed.** R33 cleanly
   proves only: under the SAME gentle flat net-weight, routed/union beats fair-est on ariane at signoff. It
   does NOT prove gentle-vs-strong in general — **gentle union may just be a weak timing force that avoids
   congestion damage.** The missing proof is source×actuation at matched routability/Pareto points.
3. **Scope nearly concedes the method away.** "Only ariane of 5 gains" reads as "conditional rescue for rare
   high-macro cases," not "new route-aware placer" — valuable ONLY if the **trigger is framed as THE
   contribution.** One positive + four negatives otherwise reads as a curiosity.

## ★ The soft circularity (the sharpest point — why the 2nd positive is ESSENTIAL, not just nice)
No fatal oracle circularity (pass-1 routed criticality is from an independent base → deployable). BUT a softer
one: **the method weights the top-K set; the "law" says top-K set-disagreement predicts whether the method
CHANGES the placement. That explains placement PERTURBATION, not necessarily timing GAIN.** Low Jaccard
guarantees the placement will be *different*; it does NOT guarantee *better*. → A 2nd low-Jaccard design that
actually GAINS is required to prove the perturbation is beneficial, not merely different. This is the crux.

## Residual mechanism weakness (metal3)
The fair-est/R33 control partly defuses the R28 metal3 RC-pessimism, but ariane's divergence is STILL partly
estimator/layer-assignment mismatch, not purely "routing detour reorders timing." The clean-mechanism story
is therefore softer than THESIS.md §2 implies.

## (b) Survives as DAC — under this framing ONLY
> "A deployable TWO-PASS route-feedback timing placement flow for MACRO-CONGESTED designs, with an
> ORACLE-FREE DIVERGENCE TRIGGER and one signoff-validated high-divergence rescue case."

Does NOT (yet) survive as: a calibrated divergence "law"; broad route-aware placement SOTA; production Pareto
dominance; proof that strong/magnitude actuation is generally wrong. **R33 = clean core. R35 = useful negative
control. R36 = supportive, not Pareto proof. R37 = good hypothesis, not a settled law.** → Demote "law" to
"hypothesis/trigger"; make the TRIGGER + the rescue case the contribution.

## (c) THE one experiment (pre-registered, frozen rules)
Run ONE independent **heavy-macro low-Jaccard** design — preferably **mempool_group**:
1. base place → route → compute top-10% est/routed Jaccard BEFORE the arms (pre-registered prediction).
2. if Jaccard < 0.4 → PREDICT a union gain (else it's not a test of the gain regime).
3. fair-est vs union: identical `--use_cell_inflate`, fixed knobs, fair-layer est, 0-DRC detailed route +
   OpenRCX coupling signoff.
4. SUCCESS = union gives a MATERIAL signoff TNS gain (>8–10%) WITHOUT routability regression.
- low-Jaccard → gain ⇒ chain becomes DAC-plausible (the law predicts gain, not just perturbation).
- low-Jaccard → NO gain ⇒ thesis collapses to "ariane-specific."
- no 2nd low-Jaccard design findable ⇒ regime too narrow for a strong method paper.

## Actions taken
- THESIS.md §0/§6 reframed to the narrower "trigger + rescue case" contribution; "law" → "hypothesis/trigger".
- **mempool_group launched** as the pre-registered decisive experiment (this is now THE load-bearing run).
- Mechanism claim (§2) softened: "gentle union beats fair-est on ariane" is proven; "gentle-vs-strong in
  general" + "reordering-not-magnitude" remain HYPOTHESES needing the source×actuation Pareto test.
