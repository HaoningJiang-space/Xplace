# What placement REALLY controls in post-route timing (correcting the "4% ceiling" error)

## The error being corrected
Earlier I framed the route-aware ceiling as the detour wire-RC effect (R18: ~4% of TNS on ariane).
That is ONE channel (III below). It is NOT the ceiling. Placement controls each critical net's
ROUTED PARASITICS P_n(x) = (routed length ℓ_n, coupling C_couple, layer/via R), and timing is highly
sensitive to P. Standard TDP uses an ESTIMATED P_est (Steiner length, zero coupling, no layer); the
route-aware headroom is the FULL gap from using true P_routed, across ALL channels — not just detour.

## The full gradient (first principles)
Driver arc of net n:  d_a = D_cell(C_n, slew_in) + D_wire(R_n, C_n),
C_n = c·ℓ_n + Σ_sink C_pin + C_couple_n,   ℓ_n = ℓ_n^HPWL(x) + Δ_n(detour via congestion).
```
∂T/∂x = Σ_a w_a ∂d_a/∂x
∂d_a/∂x = [∂D_cell/∂C_n · c + ∂D_wire/∂ℓ]·∂ℓ_n/∂x   (load→cell-delay + wire-RC, via routed length)
        + ∂D_cell/∂C_n · ∂C_couple/∂x                 (coupling, via spacing)
        + slew-propagation terms
```

## Channels (and what standard TDP misses)
| # | channel | standard TDP | measured? |
|---|---|---|---|
| I  | load→cell-delay via HPWL length | CAPTURED (net-weighted HPWL) | — |
| II | load→cell-delay via DETOUR | missed (route-aware) | in the 4% |
| III| wire-RC delay via HPWL+detour | partial | 4% (this only) |
| IV | COUPLING cap (spacing)→cell+wire delay | MISSED entirely (pre-route has no coupling) | NO |
| V  | criticality RANKING (w_a from routed vs est slack) | missed (uses estimated) | +20% |
| VI | layer/via assignment (routed-layer R) | missed | NO |

The dominant cell-delay channel via TOTAL length (I) is captured by standard TDP. The route-aware
INCREMENT = V (ranking, +20% shown) + II/III (detour, ~4% on ariane) + **IV (coupling) + VI (layer),
UNMEASURED** + the magnitude correction of the load estimate. "Placement influences a lot" lives in
IV (controllable via spacing) and VI — both ~0 at NanGate45 (relaxed) but LARGE at advanced nodes.

## True ceiling experiment (replaces the narrow detour oracle)
Oracle = recompute timing with **full routed parasitics** (routed length + coupling), optimize
placement against THAT, vs standard estimated TDP. Expected gap >> +20% on a coupling-relevant node.
This is the correct ceiling; the 4% was an artifact of measuring only channel III on a relaxed node.

## Why the differentiable router-in-loop fusion is the right vehicle
Its value is NOT fixing the 4% detour; it is supplying the FULL P_routed(ℓ, congestion, coupling,
layer) online → the FULL ∂T/∂x (all channels) via the envelope theorem at the routing optimum. The
prior TERM-2 prototype was too narrow (detour-RC only). The fusion must carry the whole routed
parasitic → timing chain into the placement gradient.

## Honest substrate note
IV (coupling) and VI (layer) need an ADVANCED node (ASAP7) with real coupling extraction; the
NanGate45 ariane substrate under-represents them, so its measurable ceiling (~+20% ranking) is a
LOWER bound on the true headroom, not the ceiling. Fixing the ASAP7 (real-synthesis, routable)
substrate is now a priority to demonstrate the full ceiling.
