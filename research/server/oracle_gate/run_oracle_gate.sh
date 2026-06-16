#!/usr/bin/env bash
# run_oracle_gate.sh : END-TO-END oracle-gate pipeline, design-parametrized.
# Re-run on a NEW design by changing DESIGN_CONFIG below (e.g. ariane133):
#   DESIGN_CONFIG=./designs/asap7/ariane133/config.mk bash run_oracle_gate.sh
# Assumes the ORFS flow already produced (or will produce) for that design:
#   4_cts.odb, 5_2_fillcell.odb, 6_final.odb, 6_final.spef
# Steps: (0) full ORFS flow if missing -> (1) PRE -> (2) POST -> (3) RUDY ->
#        (4) seed reroutes -> (5) Gate A + oracle delta + seed variance.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ORFS_FLOW="${ORFS_FLOW:-/data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow}"
export E="${E:-/data/ziheng/wzh/conda_envs/orfs/bin}"
export OG_WORK="${OG_WORK:-/data/ziheng/wzh/oracle_gate}"
export OG_OUT="${OG_OUT:-$OG_WORK/out}"
DC="${DESIGN_CONFIG:-./designs/nangate45/aes/config.mk}"
SEEDS="${SEEDS:-1 2 3}"
mkdir -p "$OG_OUT"

source ~/miniconda3/etc/profile.d/conda.sh; conda activate /data/ziheng/wzh/conda_envs/orfs

# resolve results dir
source "$HERE/og_env.sh" "$DC" >/dev/null
RES="$ORFS_FLOW/$OG_RESULTS"

# (0) run ORFS flow if final artifacts missing. NOTE: comment out EQUIVALENCE_CHECK
#     in the design config first (needs eqy tool). Done once, by hand or:
#     sed -i 's/^export EQUIVALENCE_CHECK/#&/' <design config.mk>
if [ ! -f "$RES/6_final.spef" ]; then
  echo ">> running full ORFS flow for $DC"
  ( cd "$ORFS_FLOW" && make DESIGN_CONFIG="$DC" OPENROAD_EXE=$E/openroad YOSYS_CMD=$E/yosys KLAYOUT_CMD=$E/klayout NUM_CORES="${OG_NUMCORES:-8}" ) || true
fi

echo ">> [1] PRE  (placed 4_cts.odb + set_wire_rc + estimate_parasitics -placement)"
bash "$HERE/og_run.sh" pre  "$DC" 4_cts.odb pre
echo ">> [2] POST (6_final.odb + read_spef)"
bash "$HERE/og_run.sh" post "$DC" 6_final.odb 6_final.spef post
echo ">> [3] RUDY (per-net geometry proxy on placed db)"
bash "$HERE/og_run.sh" rudy "$DC" 4_cts.odb pre
echo ">> [4] SEED reroutes ($SEEDS) on 5_2_fillcell.odb"
bash "$HERE/og_seeds.sh" "$DC" 5_2_fillcell.odb "$SEEDS"
echo ">> [5] ANALYSIS"
python "$HERE/og_analyze.py"   "$OG_OUT" | tee "$OG_OUT/gateA_report.txt"
python "$HERE/og_seed_var.py"  "$OG_OUT" | tee "$OG_OUT/seed_report.txt"
echo ">> DONE. outputs in $OG_OUT"
