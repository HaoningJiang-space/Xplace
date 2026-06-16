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
> **Xplace GPUTimer** (`update_rc_spef`, confirmed to exist) so D_place and
> D_route share the timer the placer's gradient will use; cross-check once
> against OpenSTA on a fixed-parasitics case to bound timer disagreement.

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
>     Decompose Z into a placement-determined part and a router-lottery part;
>     gate the force on the controllable part. The empirical license for this is
>     the seed-causality test (re-route a fixed placement with N seeds → routed
>     RC CV≈0 ⇒ the component IS a deterministic function of placement; measured
>     CV 0% on aes/ibex — must re-confirm on the macro/congested design).
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
- D1: D_place(Xplace timer, est RC) vs D_place(OpenSTA, est RC) agree within ε.
- D2b: seed CV of routed RC ≈ 0 on the macro/congested design (controllability).
- D2c: surrogate Z̃ vs router Z error stays bounded across recalibration steps.
- D3: removing criticality weighting degrades post-route TNS (ablation).
- D4: applying the force from iter 0 degrades HPWL/overflow vs scheduled entry.
- D5: routed-WL/overflow/DRC not worse than Xplace-Timing at the reported WNS/TNS.
