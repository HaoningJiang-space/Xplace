# Server experiment harness (moe-server)

This directory versions the experiment scripts that run on the GPU server
(`ssh -p 10548 ziheng@10.16.52.172`, conda `/data/ziheng/wzh/conda_envs/{orfs,xplace}`),
so the **local** working copy (`/home/abc/3DIC/Xplace`) and the **server** working
copy (`/data/ziheng/wzh/xplace_dac/Xplace`) share one repo.

## Unified git workflow
Both machines track the same remote:
- remote `hj` → `https://github.com/HaoningJiang-space/Xplace.git` (branch `main`)
- local `origin` still points at upstream `cuhk-eda/Xplace` (do not push there)
- server credentials: `credential.helper store` + dedicated SSH key `id_ed25519_haoningjiang` (already configured; no token committed)

Routine: `git pull hj main` before working, `git push hj main` after. Build
artifacts, data, `*.so`, `result/`, large `*.csv/*.json/*.pt` are gitignored — only
scripts, `.md` notes, and small configs are tracked.

## Contents (scripts only; logs/csv/odb live under /data, not in git)
- `oracle_gate/` — the parametrized Gate-A pipeline. `run_oracle_gate.sh DESIGN_CONFIG=...`
  runs PRE (Steiner `set_wire_rc` + `estimate_parasitics -placement`) / POST (routed SPEF) /
  RUDY / seed-causality reroutes / `og_analyze.py` (beyond-RUDY partial) + `og_seed_var.py`.
  Validated on aes & ibex (NanGate45). `og_watch.sh` auto-fires it when a flow's `6_final.spef` lands.
- `ariane133_synfree/` — ASAP7 synth-free extraction (`og_setup/og_setrc_asap7/og_extract_sf`),
  the GR-residual attempt (`run_grresidual.sh`, `run_steiner_rudy.sh` — see RESULTS R2b for why GR was rejected),
  and the detailed-route resume (`og_route.tcl`, blocked by DRT-0073 on the SRAM LEF).
- `bridge/` — Xplace↔ORFS probes (`probe2.py`, `probe_bridge.py`) + `gcd.json`.
  **Key fix:** `gcd.json` loads `NangateOpenCellLibrary.macro.mod.lef` (has TAPCELL_X1/fills),
  NOT `.macro.lef` — otherwise an unresolved tap-cell master → null `Cell::_type` → SIGSEGV in `gpdb.setup()`.

## Key server paths (not in git)
- ORFS flow: `/data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow`
- Oracle-gate work + logs: `/data/ziheng/wzh/oracle_gate/`
- Xplace build: `/data/ziheng/wzh/xplace_dac/Xplace/build`
