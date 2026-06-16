# Candidate insights — the transferable contribution (not just "we built a placer")
Companion to ROADMAP.md. Goal: identify a field-shaping principle others would cite/reuse, and a test for whether it's real vs hand-wavy. To be stress-tested by codex.

## The deepest candidate (the one to build the paper around)
**FINAL (codex-sharpened): "Only the placement-CONTROLLABLE component of routed-parasitic error should
enter timing gradients."** Controllability is part of the claim, not a caveat — the residual must be
distinct from Steiner RC, distinct from RUDY, AND moved by macro/cell motion in a way that improves
*final routed* STA. Submit framing: *"We formulate timing-driven placement as optimizing the controllable
residual response of the router, proving post-route timing loss is often caused by placement-dependent
parasitic distortion invisible to Steiner timing and aggregate congestion."*

Underlying lens (the reframe that makes it field-shaping):
**"Congestion affects timing only through the router's parasitic response. Placement-time timers are
wrong not because they are weak timers, but because they skip the routing-response layer. The
estimate→routed parasitic residual is a STRUCTURED, placement-controllable signal — not noise."**

Why this is potentially field-shaping (not incremental):
- It **reframes two subfields as one.** Timing-driven placement (better differentiable STA: C3PO/INSTA)
  and routability-driven placement (RUDY/cell-inflation) are both **projections of one latent object: the
  router's response `R(x)`**. Timing-driven optimizes `STA(P_est)`; routability-driven optimizes a proxy
  of `R(x)`; neither models `P_route(x)=R(x)∘P_est`. The contribution is to make `R`'s effect on
  parasitics the **first-class modeled object**.
- It **explains C3PO's own observation** ("routability optimization inherently supports timing") as a
  corollary: reducing congestion changes `R(x)`, which changes `Z`, which changes timing — i.e. their
  empirical coupling is *mediated by the routing response*. Our model makes the mediator explicit and
  per-arc, capturing the part aggregate RUDY misses.
- It **redirects effort:** "stop refining the timer (P_est side); model the router's response (the P_est→
  P_route gap)." That is a transferable directive for the field, independent of our specific implementation.

## Supporting sub-insights
1. **Detour is the first-order observable of `Z`, not the mechanism.** Frame in terms of `Z`
   (R/C/via/layer multipliers) so the contribution survives if via/pin-access turns out to dominate detour.
2. **The routing response is decomposable: placement-controllable vs floorplan/router-determined.** Only
   the controllable part is actionable, and it **concentrates at macros/blockages** (where Steiner ignores
   geometry and the detour is structural). ⇒ a "controllability map" telling future work *where* timing-
   driven placement can help and where it cannot. Doing macro placement turns the macro-channel response
   from determined→controllable (the highest-leverage regime).
3. **The estimate→routed residual is self-supervised and learn-to-generalize.** Modeling the PHYSICS
   residual (`routed_RC − Steiner_RC`, structured, blockage-conditioned) rather than end-to-end timing
   (unstructured) is what should make it generalize across designs — directly answering the standard
   "ML surrogates don't generalize" objection.

## Is the insight REAL? (the falsifiable tests — must pass to claim it)
- **Existence:** routed_RC − Steiner_RC has structure beyond RUDY on critical arcs (Exp1/Gate A).
- **Mediation:** congestion→timing effect is *explained away* by `Z` (path analysis: does conditioning on
  predicted `Z` remove the congestion→Δdelay correlation? If yes, `Z` is the true mediator — strong claim).
- **Controllability:** moving macros/cells changes `Z` predictably, beyond route-seed noise (Causality gate).
- **Structure beats black-box:** the structured residual model generalizes better than direct slack ML (§9).
If all pass, the insight is defensible and transferable; if mediation/controllability fail, it degrades to
"a better congestion proxy" (incremental) → pivot.

## Anti-drift guardrails (so we don't quietly become something incremental)
- If the model starts predicting *timing/slack directly* → we've abandoned the insight (the structured
  mediator) for a black box. Keep the physics decode (Z→RC→STA).
- If features collapse to RUDY/density only → we're a congestion proxy. The blockage-conditioned, per-arc,
  beyond-RUDY signal is the whole point.
- If we refine `P_est` (better Steiner) instead of modeling the `P_est→P_route` gap → wrong side of the
  reframing.
- If wins come from mixed-size quality not the routing-response layer → ablation must expose it.
