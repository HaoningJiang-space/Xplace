# The essential method — derived from the failures (R10–R17)

## 1. The fundamental decomposition of a critical arc's routed delay
```
routed_delay(arc) = cell_delay + wire_delay
wire_delay ∝ routed_length × R/C  ;  routed_length = HPWL_length + DETOUR
DETOUR(arc) = extra length forced by routing AROUND congestion / blockages in the arc's corridor
```
Two components, two DIFFERENT controllabilities:
- **HPWL_length** is **locally** controllable — pull the net's own pins together.
- **DETOUR** is a **global, field** property — set by the congestion in the corridor between
  driver and sink. It is NOT reducible by pulling the net's own pins.

## 2. The fundamental tension (why everything failed)
Local timing-pull and global detour-reduction are **OPPOSED**:
- **R15/R16 (timing-pull on detoured nets) HURT, monotonically with accuracy.** Pulling a
  congestion-detoured net's pins together *adds cells into its corridor* → MORE congestion →
  MORE detour. You are fighting the detour by amplifying its cause. The better you model the
  detour and pull, the worse it gets. ← this is the smoking gun.
- **R17 (uniform cell-inflation) didn't help.** Uniform spreading relieves congestion
  everywhere equally — it does not preferentially clear the *timing-critical* corridors, and on
  a cell-sparse design it barely engages.
- **Estimated `--timing_opt` (−2600) wins** because it only pulls HPWL-reducible nets (where
  pulling genuinely shortens routed length) and doesn't chase the uncontrollable detour.

## 3. THE ESSENCE — routing resource is scarce; allocate it by timing criticality
The real object the placer fights over is the **routing-congestion field**: low-congestion
("clear") corridors are a scarce resource. Plain placement (WL + uniform density) allocates this
resource **timing-blind** — it lets congestion fall wherever density happens to pile up,
including across timing-critical paths. **That is the "HPWL bug": the scarce clear-corridor
resource is not allocated to the paths that need it.**

> **Essential method: timing-criticality-weighted congestion allocation.**
> Keep the timing-critical arcs' corridors CLEAR (repel *non-critical* cells out of them, so the
> critical net routes straight = minimal detour), and PUSH the congestion into timing-slack
> regions (let them pack). I.e., the density/congestion penalty becomes **spatially modulated by
> the timing criticality of the nets routing through each region** — strong spreading where
> critical paths run, weak where slack is plentiful.

This is the exact INVERSE of R15: not "pull the critical net" (adds corridor congestion), but
"clear the critical net's corridor of *other* cells" (removes detour at its source). And it is
TARGETED, unlike R17's uniform spread.

## 4. Why this is the right, controllable, non-incremental method
- **Controllable (resolves the R17 concern):** ariane is 38% util → 62% whitespace. The detour
  IS placement-controllable — by *relocating non-critical cells* out of critical corridors, not
  by pulling critical pins. The lever exists; we were using the wrong one.
- **Explains every result:** R15 fails (adds corridor congestion), R17 fails (untargeted),
  estimated-timing wins (HPWL-only), and predicts the win comes from criticality-targeted
  congestion relief.
- **Non-incremental:** prior timing-driven placement = net-weighted WIRELENGTH (pull). Prior
  routability = uniform congestion penalty (spread). The essence is their missing cross-term:
  **timing-weighted congestion penalty** — allocate the clear-corridor resource by criticality.
  This is the "congestion-aware timing" the thesis named, made mechanistically precise, and it
  is exactly where naive approaches (pull, or uniform-spread) leave value on the table.
- **Matches the original instinct** ("HPWL is congestion/route-blind"): the fix is to make the
  *density/congestion* term timing-aware, NOT to make the *wirelength* term timing-aware (that
  is the standard net-weighting that R12 showed is only 3-8%, and R15 showed backfires when fed
  routed RC).

## 5. The differentiable mechanism (how it plugs into Xplace)
Xplace already has: eDensity density force + GGR route-force/congestion map + GPUTimer path
criticality. The essence = **modulate the route-force / density penalty spatially by per-region
timing criticality**:
```
congest_force(bin) *= 1 + α · crit(bin)      crit(bin) = max criticality of nets routing through bin
```
Critical congested bins get a stronger spreading/repulsion force on the cells in them (esp. the
non-critical "aggressor" cells), clearing the corridor. Slack bins keep packing. Differentiable,
reuses route_force + the timer; the new piece is the criticality→spatial-weight coupling.

## 6. Decisive test (next)
On a design with real, placement-controllable congestion (cell-congested high-util, e.g. high
`--target_density` aes, or a routability benchmark): compare post-route WNS/TNS of
{ plain | `--timing_opt` | `--use_route_force` (uniform) | **timing-weighted route-force (this)** }.
Prediction: only the timing-weighted congestion force beats `--timing_opt` at iso-routed-WL,
because it is the only one that reduces critical-arc DETOUR without adding corridor congestion.
If it does not, the placement-controllable detour is genuinely too small (D5/§5) and the thesis
reframes to "diagnosis of why route-aware timing-driven placement is counterproductive" (itself
a publishable negative, given R15/R16's monotonic evidence).
