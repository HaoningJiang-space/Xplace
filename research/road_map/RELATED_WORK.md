# Related work and the precise gap (grounded survey, 2026-06-18)

Survey to locate our contribution. Sourced from web search + the locally-analyzed DGR repo; full
PDFs not all readable — claims cited by title/venue/idea, uncertainty flagged.

## The three neighboring lines and what each does NOT do

### A. Differentiable timing-driven placement (the base we extend)
- **Differentiable-timing-driven global placement**, DAC'22 (10.1145/3489517.3530486). Injects an
  additive, per-pin/per-net timing-WL gradient into the analytical placer — exactly Xplace's
  `merged_wl_loss_grad_timing` lineage.
- **Timing-Driven Global Placement by Efficient Critical Path Extraction** ("Efficient-TDP"),
  DATE'25 (NJU LAMDA, lamda.nju.edu.cn/qianc/DATE_25_TDP_final.pdf). Critical-path extraction +
  **pin2pin attraction** on critical driver→sink pairs — a STRONGER actuation than net-weighting.
- **Critical Path Aware TDP for Large-Scale Heterogeneous FPGAs**, arXiv:2512.00038 (2025).

  **What none of A does:** the criticality is computed from **estimated** (HPWL/Steiner) RC —
  route-blind. They improve *how* the timing force is applied (pin2pin) or *which paths*
  (critical-path extraction), but the timing model never sees the **routing response**. Our axis
  is orthogonal: the criticality SOURCE (route-aware UNION), not the actuation.

### B. Differentiable routing (exists, but disconnected from placement timing)
- **DGR: Differentiable Global Router**, DAC'24 (10.1145/3649329.3656530; the repo at
  `/home/abc/3DIC/Differentiable-Global-Router`). Optimizes routing-pattern probabilities `p` by a
  smooth overflow/via/wirelength objective. **Gradient is ∂cost/∂p with pins FIXED — no ∂/∂x**, and
  it is coupled to CUGR2 (see DGR_PLAN.md). Cannot, as-is, give placement a route-aware gradient.
- **Gradient-Guided RC Weighting for Timing-Driven Global Routing**, ISPD'26. Routing optimizes for
  timing (the REVERSE direction: route given placement). Complementary, not the placement gradient.

  **What none of B does:** propagate the routing solution's sensitivity back to **cell positions**.

### C. ML surrogates for routed parasitics / pre-route timing (predict, don't differentiate-into-placement)
- **ML to improve GR↔DR timing consistency**, TODAES'23 / arXiv:2305.06917. Predicts per-sink wire
  delay/slew/π-parasitics from post-GR features (incl. macro-blockage detour features). **Confirmed
  standalone predictor**: operates *after* placement, annotates STA via Tcl, **provides no gradient
  to placement positions.** (Net-delay error 4.27%→0.84%; post-DR worst-slack e.g. swerv −0.48→−0.24ns.)
- **ParaGate** (arXiv:2511.23340), **PreRoutGNN** (arXiv:2403.00012), **UCSD ML wire-parasitic/timing
  prediction** — all cross-stage *predictors* (netlist/placement → layout timing), transfer-learning
  or GNN. Used as annotators, not as a differentiable layer inside the placer.

  **What none of C does:** be **differentiable through placement** — i.e. yield ∂(routed timing)/∂x.
  They answer "what will the routed timing be?", not "which way to move cells to improve it."

### D. Differentiable fusion (closest methodology, different objects)
- **Fusion of Global Placement and Gate Sizing with Differentiable Optimization**, ICCAD'24
  (10.1145/3676536.3676670). GPU-accelerated differentiable fusion of placement + gate sizing;
  uses **Log-Sum-Exp smoothing** of the STA max for differentiability.
- **DiffCCD: Differentiable Concurrent Clock & Data Optimization**, ICCAD'25. Differentiable,
  LSE-smoothed STA, joint skew + placement.

  **What none of D does:** fuse **routing** into the placement timing gradient. They fuse gate
  sizing / clock — variables that do not require differentiating through a *routing optimum*.
  (They DO validate our §6 choice: LSE-smoothed STA is the established way to make the timing
  adjoint a true gradient — IMPLICIT_DIFF_TIMING.md §6.)

  **Sharpened (2026-06-18 deep-read):** the ICCAD'24 fusion (Du, Guo, Lin et al., DREAMPlace group;
  +77% TNS / +43% WNS vs OpenROAD) is a **single JOINT differentiable objective** co-optimizing
  placement + gate-sizing (continuous-relaxed sizes) with LSE-smoothed timing on **placement-stage
  estimated RC** — NOT a bilevel implicit-differentiation through a lower-level argmin, and **no
  routing**. So our IFT-through-the-routing-optimum (a true bilevel, IMPLICIT_DIFF_TIMING.md §5) is
  methodologically distinct from their joint-objective fusion, AND attacks a variable (routing
  response) none of the EDA-differentiable line touches. Our "co-descent" alternative (the heavier
  Level-B) is the analogue of their joint objective; the IFT is the cheaper/exacter bilevel form.

### E. Bilevel / implicit-differentiation (the borrowed ML machinery — GOAL #9b)
Implicit differentiation of an argmin is standard ML (OptNet, Deep Equilibrium Models; bilevel via
IFT: arXiv:2205.03076, arXiv:2302.14473, AAAI'23). The recipe — model the lower optimum as an
implicit layer, get gradients via the IFT with a Vector-Jacobian-Product / adjoint solve (no explicit
Hessian inverse), unrolled-diff as the alternative when the optimum isn't reached — is EXACTLY
IMPLICIT_DIFF_TIMING.md §5–8. **Contribution = applying this established bilevel machinery to the
place↔route↔timing coupling** (the lower problem = the router; the upper = timing), which the EDA
literature has not done. Borrowing the ML discipline (well-posedness, VJP adjoint, unrolled-vs-implicit
trade-off) de-risks the derivation and is the "abstract to a high-level problem, read other fields"
move (GOAL #9b).

## The gap (our two contributions, neither covered above)
1. **Route-response timing gradient via implicit differentiation** (IMPLICIT_DIFF_TIMING.md).
   The cross term `(∂T/∂r)(dr*/dx)` — how moving a cell changes the *routing response* and thus
   routed timing — is dropped by all of A (frozen est RC), unobtainable from B (no ∂/∂x), and only
   *predicted* (not differentiated-into-placement) by C. We compute it exactly via one adjoint solve
   `Hμ=∂_pT` through the routing optimum. **No prior work differentiates through the routing layer
   for timing-driven placement.**
2. **UNION criticality source** (FRAMEWORK R23). est and routed timers each miss different
   truly-critical nets; the route-aware criticality is their union — distinct from A's estimated-only
   critical paths and from C's pure routed prediction.

The amortized form (P-gate, IMPLICIT_DIFF_TIMING.md §9) is C made **differentiable-through-placement
and trained to the IFT route-response direction** — the missing differentiable bridge between C's
predictors and A's placer.

## Honesty / to verify
- Could not extract the Efficient-TDP and ICCAD'24-fusion full PDFs (binary/paywall); method claims
  from abstracts + search summaries + prior notes. Verify the exact pin2pin formulation and whether
  the fusion paper uses implicit differentiation (vs unrolling) before final positioning.
- ISPD'26 "Gradient-Guided RC Weighting" is the nearest routing-side neighbor — read it to ensure
  our route→placement direction is genuinely unclaimed.

## Sources
- https://dl.acm.org/doi/10.1145/3489517.3530486 (Differentiable-timing-driven GP, DAC'22)
- http://www.lamda.nju.edu.cn/qianc/DATE_25_TDP_final.pdf (Efficient-TDP, DATE'25)
- https://arxiv.org/pdf/2512.00038 (Critical-Path-Aware TDP for FPGAs)
- https://dl.acm.org/doi/10.1145/3649329.3656530 (DGR, DAC'24)
- https://dl.acm.org/doi/10.1145/3676536.3676670 (GP + gate-sizing fusion, ICCAD'24)
- https://ieeexplore.ieee.org/document/11240631/ (DiffCCD, ICCAD'25)
- https://dl.acm.org/doi/full/10.1145/3626959 , https://arxiv.org/html/2305.06917 (ML GR↔DR timing)
- https://arxiv.org/pdf/2511.23340 (ParaGate) , https://arxiv.org/html/2403.00012v2 (PreRoutGNN)
- https://vlsicad.ucsd.edu/Publications/Conferences/392/c392.pdf (UCSD ML parasitics/timing)
