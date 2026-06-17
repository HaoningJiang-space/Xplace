# Data-structure decision: arc-level vs net-level criticality (first-principles, recursive)

Applies FRAMEWORK §4's "modeling unit = driver→sink ARC, not net" recursively to the route-aware
term we just built (Level-A `detour_timing.py`), which is currently **net-level**. Records why, the
cost of the approximation, and the arc-level upgrade.

## 1. First-principles: what the timing gradient actually acts on
Timing is a property of **arcs** (driver pin → sink pin), not nets:
- delay is per arc: `d_a = f(R_a, C_a)`, and `κ_a = ∂T/∂d_a` is **per arc** (the gputimer already
  produces per-pin/per-arc criticality before any net collapse).
- the routed detour that inflates RC is **per sink**: a net with one near sink and one detoured
  far sink has wildly different per-arc Δ; the net aggregate hides it.
- the corrective force should pull the **critical driver→sink pair**, not shrink the whole net's
  bounding box (which also pulls non-critical sinks and the driver toward irrelevant pins).

So the *correct* modeling unit is the arc. Net-level is a **lossy projection**: it sums/averages
the per-arc signal, discarding (i) driver/sink asymmetry, (ii) per-sink detour, (iii) which sink
gates the path.

## 2. What Level-A currently does (and the exact loss of fidelity)
`L = Σ_n w_n · HPWL_n(x) · (1+α·ρ_n)`:
- `w_n` = net criticality (max/aggregate of per-arc κ) → **loses which arc is critical**.
- `HPWL_n` = net bounding box → **loses driver/sink asymmetry**; its gradient pulls all extreme
  pins, not the critical pair.
- `ρ_n` = congestion at the net **centroid** → **loses per-sink corridor congestion** (the detour
  happens on a specific sink's corridor, not the centroid).

This is the same trap FRAMEWORK §4 flagged (R11 used net-weighting "as a first probe; the real Δ̂
lives on arcs"). Level-A is a deliberate scaffold to validate the *mechanism* (differentiable
detour helps at all) cheaply; it is **not** the final granularity.

## 3. Arc-level form (the upgrade)
Per critical arc `a = (driver pin u → sink pin v)`:
```
L_arc = Σ_a κ_a · len_a(x) · (1 + α · ρ_a(x))
   len_a(x) = ‖pos(u) − pos(v)‖₁                       (driver→sink Manhattan; differentiable)
   ρ_a(x)   = mean congestion sampled along the u→v corridor (bbox of the pair), not net centroid
```
- `κ_a` is already available pre-collapse (`report_criticality_threshold` returns per-pin visited
  weights; net_criticality is their net-wise max — keep the per-arc tensor instead).
- `len_a` is a **2-pin** term → its gradient is the exact pin2pin direction, but driven by our
  route-aware κ (NOT a separate pin2pin method — we are not adopting Efficient-TDP's actuation; this
  is the same net-weight philosophy refined to arc granularity, see RELATED_WORK §A).
- `ρ_a` over the pair's corridor captures the **per-sink detour**, which is exactly where Δ lives.

Cost stays O(#critical arcs) ≈ hundreds (WNS-band, FRAMEWORK §4) — same order as net-level, since
critical nets have few critical arcs.

## 4. Decision
- **Keep Level-A net-level as the cheap mechanism check** (already built, gated, testable under
  `--timing_opt`). If it shows *zero* signal, arc-level (a refinement of the same signal) is
  unlikely to rescue it — fail fast.
- **If Level-A shows signal, immediately go arc-level** (above) before tuning — it is the correct
  unit and removes three distinct approximations at once. Expose the per-arc κ + arc endpoint pairs
  from the timer (the path exploration already walks driver→sink arcs; emit the pairs, do not
  collapse to net).
- Arc-level also makes the IFT term (IMPLICIT_DIFF_TIMING.md §6) exact: `∂T/∂r` is naturally
  per-arc (`Σ_a κ_a ∂d_a/∂ℓ_a`), so arc granularity aligns the Level-A surrogate with the eventual
  implicit gradient — no re-derivation when escalating.

## 5. Data-structure note (FRAMEWORK §4 D9 echo)
Arc key MUST be unique `(net, driver_pin, sink_pin)`. The earlier GR-residual join blew 340k→492k on
non-unique keys. The arc-level tensor must be keyed by sink pin id (unique), not (net,sink_index).

## 6. Data-structure resolution (verified 2026-06-18) — what's available for arc-level
Investigated the timer + db to ground the arc-level upgrade WITHOUT guessing (GOAL #10, #13):
- **Driver pin per net:** `GPPin.getDirection()` IS exposed via pybind (`io_parser/BindHelper.cpp:37`),
  but NOT materialized as a PlaceData tensor. → materialize `data.net_driver_pin` ONCE at setup from
  gpdb pin directions (OUTPUT = driver). **No C++ change, no rebuild** (server build is dirty — avoid).
- **True STA arcs:** the timer's `at_prefix_pin` (`path.cu:28`, arrival-time predecessor per pin) is the
  exact critical-path arc structure (more faithful than netlist driver→sink for combinational dirs),
  but it is C++-internal → exposing needs pybind + rebuild. **Defer** (heavier; do after v1 shows signal).
- **Per-sink criticality:** `timing_pin_weight` (`timing_opt.py:91`, per-pin, len=num_pins) is already
  the per-sink criticality; the oracle path builds only net-level `net_criticality` (broadcast to sinks).

**Arc-level v1 decision (zero C++):** materialize `net_driver_pin` via `getDirection`; per critical
sink pin `v` with driver `u=net_driver_pin[net(v)]`, weight `κ_v=timing_pin_weight[v]` (or net_crit
broadcast):
```
L_arc = Σ_v κ_v · ‖pos(u) − pos(v)‖₁ · (1 + α · ρ_corridor(u,v))     # ρ over the u→v bbox, not net centroid
```
This removes net-level's three approximations (driver/sink asymmetry, per-sink detour, wrong-pin pull)
with no rebuild. **TO VERIFY before coding:** gpdb pin-id ↔ PlaceData pin_id alignment, and that net
driver is unique (tie-breaking for multi-output / no-driver nets — use net_mask + assert).
