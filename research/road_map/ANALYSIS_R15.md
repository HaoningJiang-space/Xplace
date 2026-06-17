# Why route-aware RC-correction HURT post-route timing (R15 root-cause analysis)

Clean evidence (post-route, same back-end timer for both arms — the only fair comparison):
`route-corrected --timing_opt` post-route TNS **−2817** vs `estimated --timing_opt` **−2600**
(worse by ~8%), and routed **wire-cap rose** (557189 vs 544106). Estimated `--timing_opt`
itself helps (no-timing −3119 → −2600). (Placement-time late-TNS numbers are NOT comparable:
the corrected arm's timer uses inflated RC, a different metric — ignore them.)

So: up-weighting routing-detoured nets in the timing force made things worse, with MORE routing.
Five candidate causes, ranked by how fundamental:

## C1 (deepest, likely primary) — LEVER MISMATCH: detour ≠ HPWL
The RC-multiplier (routed/est, mean 1.6×) inflates RC for **detoured** nets → the timer marks
them more critical → the timing-WL force pulls **their pins closer (reduces their HPWL)**.
**But a net's detour is set by the CONGESTION it must route around, not by its own HPWL.**
Pulling a congestion-detoured net's pins closer does NOT shorten its *routed* length (the
router still detours around the same blockage/congestion), so the "fix" yields ~no real delay
reduction — while the extra cell motion **adds local congestion** (wire-cap↑ confirms) → MORE
detour elsewhere → worse post-route. The placer's lever (shrink HPWL) is the wrong lever for
the detour component of delay.
- **Why estimated `--timing_opt` works but this doesn't:** estimated criticality targets nets
  whose delay is HPWL-driven (genuinely *pullable* — shortening HPWL shortens routed length
  too). RC-correction *redirects* the force toward congestion-detoured nets, which are NOT
  pullable. So route-awareness, fed to an HPWL-puller, points at exactly the nets the placer
  cannot help — and trying hurts.
- This is the **placement-controllability** principle (FIDELITY D2b) violated concretely: we fed
  the *uncontrollable* (congestion-structural) component of routed delay into a per-net pulling
  gradient. Only the placement-controllable component should drive the timing force.

## C2 (real confound) — STALE / MISMATCHED multiplier
The multiplier was computed on the `ar_base` **no-timing** placement's route, then applied to a
**different** (timing-driven) placement that keeps moving cells. The timer sees routed/est for
the WRONG placement, and uses it from center-init onward → the timing gradient is misdirected
for most of GP. C2 alone could explain a degradation; it must be removed to test C1 cleanly.

## C3 — granularity: per-net, not per-arc
The multiplier scales the whole net's wire RC uniformly; detour is per driver→sink ARC. Coarse
attribution spreads the (already wrong-lever) force over all the net's pins.

## C4 — positive feedback into congestion
C1+C2 both concentrate cells on detoured nets → congestion↑ → detour↑ → the next timer view is
even more pessimistic on those nets → more pulling. A divergent loop, not a corrective one.

## C5 — calibration / scale
wire_R 0.0036 is a single-layer proxy; if mis-scaled, the multiplier's absolute effect is off.
Lower priority (the estimated baseline used the same wire_R and behaved sensibly).

## The reframing this implies (the actual thesis insight)
Route-aware delay must be **decomposed and routed to the right lever**:
- **HPWL-reducible component** (net is "long" because its pins are far) → timing-WL pull (what
  estimated `--timing_opt` already does well).
- **Congestion-detour component** (net is "long" because it routes around congestion) → this is
  NOT fixable by pulling; it needs a **congestion/routability response** (spread, cell inflation,
  density re-weighting, or move the *aggressor* cells out of the corridor) — Xplace's
  `--use_cell_inflate`/route-force lever, not the timing-WL lever.
The contribution is then: *predict the congestion-detour component of critical-arc delay and
drive it to the routability lever, while the HPWL-reducible component drives the timing lever.*
Naively adding detour-RC to the timing force (R15) does the opposite and backfires.

## Falsifiable tests to confirm the ranking
1. **Isolate C2:** re-derive the multiplier from the corrected placement's OWN route (iterate
   place→route→re-mult→re-place). If still worse → C1 dominates (mechanism issue, not staleness).
2. **Isolate C1:** split nets into HPWL-long vs congestion-detoured (detour/HPWL high but pins
   already close). Apply RC-correction ONLY to HPWL-long critical nets. If that recovers/helps →
   confirms the detoured-net force is the culprit.
3. **C4:** log wire-cap / overflow per GP iter for both arms; corrected should show rising
   congestion on the up-weighted nets.
4. **Lever test:** route the detour component to `--use_cell_inflate` (spread the congested
   corridor) instead of the timing-WL pull; compare post-route.
