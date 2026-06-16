#!/usr/bin/env bash
# og_seeds.sh : re-route the SAME placement with N detailed-route seeds; dump per-arc RC each.
# Usage: og_seeds.sh <DESIGN_CONFIG> <preroute_odb> "<seed1 seed2 ...>"
#   e.g. og_seeds.sh ./designs/nangate45/aes/config.mk 5_2_fillcell.odb "1 2 3"
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ORFS_FLOW="${ORFS_FLOW:-/data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow}"
export E="${E:-/data/ziheng/wzh/conda_envs/orfs/bin}"
export OG_WORK="${OG_WORK:-/data/ziheng/wzh/oracle_gate}"
export OG_OUT="$OG_WORK/out"
DC="$1"; PRE="$2"; SEEDS="$3"
source "$HERE/og_env.sh" "$DC"
export OG_SDC="$OG_RESULTS/4_cts.sdc"; [ -f "$OG_SDC" ] || export OG_SDC="$OG_RESULTS/6_final.sdc"
export OG_PREROUTE_DB="$OG_RESULTS/$PRE"
export OG_NUMCORES="${OG_NUMCORES:-8}"
for s in $SEEDS; do
  export OG_SEED="$s"; export OG_TAG="post_seed${s}"
  echo "==== ROUTING SEED $s ===="
  "$E/openroad" -no_init -exit "$HERE/og_seed_route.tcl" 2>&1 | grep -E "SEED_ROUTE|SEED_DONE|Error|ERROR" || true
done
