# Fidelity discipline — how the route-aware global placer must NOT distort (不要失真)

Goal anchor: **we are building a better GLOBAL PLACER.** The route-aware timing
model is only a means; the deliverable is a global placement that closes
**post-route** WNS/TNS without hurting routed-WL/overflow/DRC. Every design
choice below exists to keep the loop *faithful* — so that an improvement the
optimizer "sees" is an improvement that *survives routing*. Distortion (失真) =
any place where the gradient the placer follows diverges from real post-route
reality. There are six such places; each gets a rule.

---

## D1. Measurement distortion — the gap Δ must isolate parasitics, not timers
`Δ(n) = D_route(n) − D_place(n)` is meaningless if `D_place` is timed by Xplace's
GPUTimer and `D_route` by OpenSTA: then Δ mixes (timer A vs timer B) with
(estimated vs routed RC). On the chosen substrate (Xplace places an ORFS design,
OpenROAD routes it):
> **Rule:** ONE STA engine, identical libs/SDC/delay model. The *only* thing that
> differs between `D_place` and `D_route` is the parasitic source — estimated
> FLUTE/Steiner RC vs the routed SPEF. Prefer feeding the routed SPEF into the
> **Xplace GPUTimer** (`update_rc_spef`) so D_place and D_route share the timer
> the placer's gradient will use.
> **"Exists" ≠ "faithfully ingests" — D1 is a CONTRACT, not a hook.** Before any Δ
> is trusted, pass a hard check on the OpenROAD→Xplace SPEF path: (1) **100%
> net/pin name round-trip** — Xplace pins are `inst:pin` (`GPDatabase.cpp:119`),
> SPEF uses different delimiters and Xplace strips backslashes/spaces
> (`Database.cpp:22`), which can silently *collide* names; (2) **nonzero-RC
> coverage** — unmatched SPEF nets are skipped then assigned ZERO RC with only a
> warning (`rctree.cpp:453`), which fakes a *better* D_route; assert ~100% nets
> get nonzero routed RC; (3) **unit sanity** — the SPEF unit parser matches exact
> strings (`spef.cpp:26`); confirm FF/PF/OHM headers; (4) **coupling policy** —
> `update_rc_spef` appears to add only ground caps, ignoring coupling
> (`rctree.cpp:430`); decide and document; (5) **fixed-parasitics agreement** —
> Xplace-timer vs OpenSTA must agree on the SAME parasitics before either is
> trusted. Until this passes, Δ is confounded by the timer, not the routing.

## D2. Surrogate exploitability — the gradient must point at PHYSICAL improvement
The differentiable route-aware surrogate predicts routing-induced parasitic
distortion `Z(x)` (detour/via/layer/coupling multipliers per arc). The #1 risk:
the optimizer reduces *predicted* timing by moving cells in ways that shrink Z's
*prediction* but not the *real* routed timing — a gamed, fake gain.
> **Rule (three parts):**
> (a) Go through the physical chain `congestion → route response → parasitics →
>     delay`, never a black-box `net → delay` map — a physically-mediated
>     gradient points toward real reductions.
> (b) **Only the placement-CONTROLLABLE component of Z enters the gradient.**
>     Operational definition (NOT the weak CV test): write
>     `Z(x, seed) = E_seed[Z | x] + noise`. Seed-causality CV≈0 only bounds
>     `noise` (determinism) — it does NOT prove `∂E[Z|x]/∂x` is large, smooth, or
>     useful. A detour deterministically forced around fixed macro pins is
>     CV≈0 yet *uncontrollable* by standard-cell motion. **Controllability test:
>     (i) variance of `E_seed[Z|x]` ACROSS placements must dominate route-seed
>     variance, and (ii) finite-difference sensitivity — perturb placement along
>     the proposed force, re-route with the SAME flow/seed, and confirm real
>     routed STA actually moves the predicted way.** Only the component passing
>     both enters the gradient.
> (c) **Online recalibration** against the true router every K iterations (mirror
>     Xplace's `update_timing_calibrated`): re-route, compare surrogate Z̃ to the
>     router's actual response, correct the surrogate before drift accumulates.
>     A surrogate that is never re-grounded will be exploited.

## D3. Criticality distortion — accuracy on the wrong nets is useless
A surrogate accurate on all nets but whose force spreads over non-critical nets
wastes placement capacity and can worsen the paths that set WNS/TNS.
> **Rule:** criticality-weighted, slack-relative, self-shrinking band (reuse
> `report_criticality_threshold`'s WNS-relative selection). The route-aware force
> concentrates on the few hundred arcs that gate timing — which is also what
> makes it cheap enough to run inside the GP loop.

## D4. Scheduling distortion — respects what GP does at iter 0
Global placement starts from a cold center init; early iterations have no spatial
structure, so detour/congestion signals are pure noise. Injecting the route-aware
force early distorts the wirelength/spreading dynamics that GP must do first.
> **Rule:** the route-aware term enters only after overflow drops below a
> threshold (spatial structure has emerged), and is *ramped*, not stepped —
> exactly how `ParamScheduler` ramps the density weight. This is the concrete
> meaning of "respect what global placement does at the beginning."

## D5. Objective distortion — augment the placer, don't replace it
The route-aware timing force is ADDED on top of WA-wirelength + eDensity. If it
dominates, HPWL/routed-WL/legality degrade and the "timing win" is a Pyrrhic one.
> **Rule:** bounded, weight-floored additive correction. Acceptance is a
> *joint* criterion: post-route WNS/TNS clearly better than Xplace-Timing AND
> routed-WL / overflow / DRC-proxy not worse AND runtime acceptable. A timing
> gain bought with congestion is a distortion, not a result.

## D6. Substrate distortion — measure the placer we are improving
Measuring the gap on an OpenROAD placement tells us nothing about *Xplace's*
improvable gap. (This is the drift the OpenROAD oracle gate fell into; kept only
as tool-independent premise validation.)
> **Rule:** the placement under test is always **Xplace's output**. The chosen
> substrate (Xplace places ORFS NanGate45/ASAP7 via the unblocked bridge →
> OpenROAD routes → SPEF) guarantees this while giving a routable, C3PO-aligned
> PDK — since the timed-but-unroutable ICCAD2015 (GGR segfaults on its LEF) and
> the routable-but-untimed ISPD are each insufficient alone.

## D7. Flow-mutation distortion — routing must not mutate the netlist/state
(codex-found.) D1 ("vary only parasitics") is insufficient if the routing flow
*also* changes the design between `D_place` and `D_route`: CTS buffers, gate
resizing, tie/filler/antenna insertion, route/timing repair, clock propagation,
detailed-placement movement. Then `Δ` mixes parasitic distortion with netlist
mutation — exactly the trap the ariane GR-residual attempt hit (1_placed had no
CTS, 3_groute did → 114890 vs 117169 nets, join corrupted).
> **Rule:** freeze the netlist across the Δ measurement. Take `D_place` on the
> **same post-CTS, post-resize netlist** that is then routed, so the only delta is
> estimated-RC → routed-SPEF. Any cell the router adds/resizes after the D_place
> snapshot invalidates that net's Δ — drop it or re-snapshot. Report the fraction
> of arcs surviving an unmutated round-trip.

## D8. Gradient-reality distortion — accurate Z does not imply useful ∇Z
(codex-found, the deepest one for a *placer*.) The router's response is
discontinuous in placement (a net flips to a different track/layer/detour). A
surrogate can predict `Z` values accurately yet have a `∇Z` that points nowhere
real — the placer would chase a smooth gradient across a step function.
> **Rule:** validate the GRADIENT, not just the value. Finite-difference check:
> perturb the placement along the proposed route-aware force, re-route with the
> same flow/seed, and confirm the *real* routed STA improved in the predicted
> direction and magnitude. A force that fails this is distortion regardless of how
> well `Z` is fit. This is promoted to a first-class fidelity rule (was only a
> ROADMAP §14 footnote).

## D9. Arc-identity distortion — the supervised target must have unique keys
(codex-found.) The thesis predicts per driver→sink arc. If `(net, driver, sink)`
keys are non-unique, the label set is corrupted at the source (the ariane GR join
blew 340k arcs → 492k via many-to-many — `RESULTS.md` R2b).
> **Rule:** enforce unique arc keys; deduplicate/disambiguate multi-driver and
> repeated-pin cases before any correlation or training. Non-unique keys are a
> data-integrity bug, not a nuisance.

---

## THE GATING EXPERIMENT (do this before building any predictor)
codex's cheapest falsifier, and it upper-bounds the entire thesis: a
**true-residual oracle placement**. Take a real Xplace placement on one
macro-heavy ORFS design; inject the *actual* routed-RC residual from the SPEF as
if the predictor were **perfect**; run a short late-stage placement update along
that oracle force; re-route with the SAME flow/seed; compare post-route WNS/TNS
against Xplace-Timing and a C3PO-style/RUDY baseline **at matched routed-WL/DRC**.
> If even a PERFECT predictor cannot beat route-seed noise at iso-congestion,
> **STOP** — no learnable surrogate can rescue it (this is the D5/§5 physical
> risk: the placement-controllable parasitic delta may be dominated by
> cell/slew/buffering/CTS/macro-pin-access/path-migration). Gate A (residual
> exists) is NOT Gate B (placement utility); this experiment is the bridge.

---

## Why this is a contribution, not feature engineering
The novelty is not "add a timing term." It is a **fidelity-preserving coupling**
of a differentiable routing-response model into the global-placement gradient:
physically-mediated (D2a), controllable-component-only (D2b), router-recalibrated
(D2c), criticality-gated (D3), overflow-scheduled (D4), and bounded (D5), with the
gap measured by a single timer varying only parasitics (D1) on the placer's own
output (D6). The claim that survives review: *a placement-controllable, anti-gamed
routing-response timing model is the right intermediate layer between placement
congestion and post-route timing* — and it makes a global placer that closes
post-route timing a congestion-blind timing-driven placer cannot.

## Falsifiable checks (each rule has a test)
- D1: 100% net/pin SPEF round-trip + ~100% nonzero routed RC + unit sanity +
  Xplace-timer vs OpenSTA agree within ε on fixed parasitics. (Contract, not hook.)
- D2b: across-placement variance of E_seed[Z|x] ≫ route-seed variance, AND
  finite-difference: perturb→re-route→real routed STA moves as predicted.
- D2c: surrogate Z̃ vs router Z error stays bounded across recalibration steps.
- D3: removing criticality weighting degrades post-route TNS (ablation).
- D4: applying the force from iter 0 degrades HPWL/overflow vs scheduled entry.
- D5: routed-WL/overflow/DRC not worse than Xplace-Timing at the reported WNS/TNS.
- D7: report fraction of arcs surviving an unmutated (no CTS/resize) round-trip.
- D8: finite-difference gradient-reality holds (perturb along force → routed STA).
- D9: arc keys unique; dedup before any correlation/training.

## Non-incrementality is earned by Exp 3, not by framing (codex point 4)
Until the **oracle gating experiment** passes AND the learned controllable
residual yields a route-verified placement gradient that beats matched
Steiner-RC / global-route-RC / RUDY / C3PO-style baselines at iso routed-WL/DRC,
a reviewer correctly reads this as "C3PO + a learned routed-RC estimator." The
"parasitic-distortion mediator" is terminology until Exp 3 shows route-verified
placement utility. **Gate A (residual exists) ≠ Gate B (placement utility).**
