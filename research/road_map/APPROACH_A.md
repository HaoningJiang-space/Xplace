# Approach A — online routed criticality INSIDE one GP run (the differentiable-fusion method)

## Goal
Make the +20% deployable: replace the oracle (route-first) routed criticality with criticality
computed ONLINE by an in-loop router, refreshed every K GP iterations. Pure global-placement
contribution: a route-aware timing-WL gradient whose criticality comes from in-loop routing, not
from a pre-done route. This is the single-run version of the fixed-point iteration (B); B validates
the premise, A is the fast/elegant method.

## Key simplification (learned from the TERM-2 failure)
Do NOT use the route FORCE (it over-spreads → HPWL +12% → hurt, rf0/v1). We only need GGR's routed
WIRELENGTH to inform the TIMER's criticality. So:
```
every K iters:  GGR route (current x)  ->  per-net routed length ℓ_n^routed
                ->  GPUTimer wire RC set from ℓ_n^routed (ranking source = routed slacks)
                ->  routed criticality timing_pin_weight  ->  timing-WL gradient (the +20% lever)
```
No spreading force, no over-spread. The route-awareness enters ONLY through which nets the timer
marks critical (the ranking), which is exactly what the +20% oracle showed works.

## Why this is NOT R15 (which hurt)
R15 fed the routed/estimated RC RATIO → inflated DETOURED nets' RC → timer marked congestion-
detoured (non-pullable) nets critical → HPWL pull on them → hurt (lever mismatch). Approach A feeds
the routed LENGTH → timer recomputes the true routed SLACKS → criticality = the actually-critical
nets (mostly HPWL-pullable long nets), the SAME source as the +20% oracle. Source of criticality is
the difference: routed-slack ranking (A, works) vs detour-ratio magnitude (R15, fails).

## Components (all exist — reuse)
- GGR in-loop: `run_gr_and_fft` (gpugr) — gives per-net routed length. Already runs (run_fft fixed).
- `GPUTimer.set_net_rc_mult(ℓ_routed/ℓ_steiner)` — built in R15; here used to set routed wire RC so
  the timer's slacks reflect routed length (ranking), refreshed every K iters.
- `GPUTimer.update_timing` → routed slacks → `timing_pin_weight` (the existing path-based criticality).
- `merged_wl_loss_grad_timing` — the timing-WL gradient (calculator.py), unchanged.

## Loop integration (run_placement_nesterov)
1. Run `--timing_opt` (GPUTimer active) as the base.
2. Every K iters (after overflow < threshold, like the route trigger): run GGR → per-net routed
   length → `set_net_rc_mult` → `update_timing` → refresh `timing_pin_weight`.
3. Between refreshes, timing_pin_weight is held (cheap). x co-evolves with the refreshed criticality
   → converges to a self-consistent place/route/timing fixed point (no oracle).
Envelope-theorem view: at each refresh the routing r* is (locally) optimal for x; the criticality is
∂T/∂(routed parasitics) evaluated at r*, so the timing-WL gradient is the route-aware ∂T/∂x with the
router treated as converged — no need to backprop through GGR.

## Decision gate (set by fixed-point experiment B, running now)
- If B converges from est (−2685) toward oracle (−2401): online routed criticality recovers the
  prize → build A (fast single-run version), then push to SOTA (multi-design, vs C3PO/Xplace-Timing).
- If B stalls near est: online (non-oracle) criticality at OpenROAD fidelity doesn't help → the
  oracle's advantage was the specific reference route; rethink (maybe needs the magnitude/coupling
  channels of CEILING.md, i.e. a richer in-loop model, or the moving-target is fatal).

## DGR upgrade (Stage 2, for SOTA)
Swap GGR → canonical NVlabs DGR for: (a) differentiable routed parasitics (true ∂/∂x via the soft
pin→GCell splat, not just the envelope approximation), (b) speed, (c) the smooth congestion→detour
surrogate. This is the full two-differentiable fusion (UNIFICATION.md). A with GGR is the bridge.
