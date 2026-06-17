# Path-based pivot — route-aware RC-correction on Efficient-TDP (not net-weighting)

User steer (2026-06-17): "net-based 不太行，多参考 Efficient-TDP 处理方式." Acting on it.

## Why net-based is insufficient (our own data)
R9/R12: net-weighting only uses the criticality *ranking*; force-matched, routed vs
estimated rankings differ by only ~3-8%. Net granularity throws away the path
structure and the per-arc delay magnitude — exactly where route-awareness lives.

## Efficient-TDP = the right path-based vehicle (DATE'25)
"Timing-Driven Global Placement by Efficient Critical Path Extraction" (local at
`/home/abc/3DIC/Efficient-TDP`, DREAMPlace-based). Mechanism (`dreamplace/ops/timing/`):
- **Critical-path extraction** from the OpenTimer raw_timer (`report_timing_traces`).
- **pin2pin attraction** (`net_weighting_scheme="pin2pin"`): attract ADJACENT pin pairs
  *along extracted critical paths*, with momentum (`net_criticality_deltas`,
  `momentum_decay_factor`, `pin2pin_{max,min,accumulate}_weight`). This directly shortens
  critical *paths*, not whole nets — path/arc granularity.
- **LoRe routing-aware budget already present**: `update_net_weights(..., lore_routing_policy
  ="dynamic_lore", lore_pair_budget, lore_skeleton_ratio)` — "a hard budget routed over STA
  graph interactions" (the user's LoRe timing-control work). This is a path-pair selection/
  budgeting hook that is already routing-aware-shaped.

## CORRECTION (user steer 2026-06-17): do NOT reinvent pin2pin
pin2pin attraction is Efficient-TDP's OWN contribution — copying it is not novel. So:
- **pin2pin (or Efficient-TDP's path-based force) = the FIXED VEHICLE / baseline, used AS-IS.**
- **Our contribution = route-aware per-arc RC-correction injected into the TIMING the
  critical-path extraction consumes.** The force model is held constant.
- Cleanest isolation experiment: **Efficient-TDP(pin2pin, ESTIMATED timing) vs
  Efficient-TDP(pin2pin, ROUTE-CORRECTED timing)** on the same design/seed. Identical
  path-based force; the ONLY difference is whether the extracted critical paths come from
  estimated or route-aware delays → the delta is *purely* route-awareness, and our novelty
  (the RC-correction mediator) is orthogonal to their pin2pin.
- Reference = the CLEAN canonical `lamda-bbo/Efficient-TDP` (re-cloned; the local LoRe fork
  was modified). Do NOT build on the possibly-broken LoRe working tree.

## The route-aware RC-correction, path-based (the thesis injection)
Inject route-awareness at the **timing that drives path extraction**, so the extracted
critical paths (and the pin2pin attraction targets) are the ones critical POST-ROUTE:
```
estimated RC ──(route-aware correction Z per ARC: routed/est)──▶ corrected arc delays
   ──▶ OpenTimer arrival/slack ──▶ critical-path EXTRACTION (now routed-critical paths)
   ──▶ pin2pin attraction along those paths (+ LoRe budget) ──▶ placement
```
Granularity = per driver→sink ARC (m_R,m_C per arc), matching the thesis modeling unit and
Efficient-TDP's pin2pin/path structure. The correction changes WHICH paths are extracted and
HOW the pin-pairs are budgeted (LoRe) — not a per-net scalar weight.

## Vehicle decision (recommend Efficient-TDP over Xplace-GPUTimer)
- **Xplace-GPUTimer** (now unblocked, R13/R14): path-INFORMED pin *weighting* — closer to
  net/pin weighting than pin2pin attraction; would need a new attraction force to match
  Efficient-TDP. Keep as a cross-check.
- **Efficient-TDP** (recommended): purpose-built path-based pin2pin + existing LoRe routing
  hooks + a DATE'25 SOTA baseline to extend/beat. The route-aware correction is a natural
  extension of LoRe (route-aware path-pair budgeting / route-corrected extraction).
- **Caveat**: Efficient-TDP targets ICCAD2015 (timed, not routable → post-route eval needs the
  benchmark-fork fix). Decide eval substrate (Open3DBench DEFs / a routable timed flow).

## Infra state (2026-06-17)
- Re-cloned clean canonical `lamda-bbo/Efficient-TDP` locally (cc1d405); haoning remote kept (LoRe safe on remote: `dda4de4` + tags).
- Server `/data/ziheng/wzh/Efficient-TDP-dev` IS built (`build/.../timing_cpp.so` etc.) but the `.so` are **cpython-310 + torch≥2.1**, and **NO available conda env matches**: `xplace`=py3.10+torch2.0.1 (finds the .so but `undefined symbol init_is_contiguous`), `dfv3`/`mxmoe`=torch2.6 but not py3.10 (can't load cpython-310 .so). → **running Efficient-TDP needs a clean rebuild against a pinned env.**

## Next steps
1. **Rebuild Efficient-TDP against a pinned env** (the gating infra step): either build the clean canonical against the proven `xplace` env (py3.10, torch2.0.1+cu117 — IF the code compiles against 2.0.1), or create a py3.10+torch≥2.1 env. Then reproduce pin2pin on superblue1 (sanity).
2. Understand LoRe precisely (`timing_cpp.cpp` update_net_weights pin2pin path; `experiments/timing_objective_lab.py`) — but as REFERENCE only (don't build on the modified LoRe).
3. Inject route-aware ARC RC-correction into the path-extraction TIMING (pin2pin force held fixed); compare Efficient-TDP(estimated) vs Efficient-TDP(route-corrected), post-route, force/seed-matched.
4. codex-review the injection before trusting results.
5. Substrate for post-route eval: Open3DBench DEFs (routable) — ICCAD2015 is timed-not-routable.
