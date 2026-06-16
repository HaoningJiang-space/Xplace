#!/usr/bin/env bash
# og_run.sh : run one extraction pass (single openroad process per db).
# Usage:
#   og_run.sh pre   <DESIGN_CONFIG> <placed_odb_name> <tag>
#   og_run.sh post  <DESIGN_CONFIG> <routed_odb_name> <spef_name> <tag>
#   og_run.sh rudy  <DESIGN_CONFIG> <odb_name> <tag>
# All paths resolved from ORFS via og_env.sh. Outputs -> $OG_WORK/out
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ORFS_FLOW="${ORFS_FLOW:-/data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow}"
export E="${E:-/data/ziheng/wzh/conda_envs/orfs/bin}"
export OG_WORK="${OG_WORK:-/data/ziheng/wzh/oracle_gate}"
export OG_OUT="$OG_WORK/out"
MODE="$1"; DC="$2"

source "$HERE/og_env.sh" "$DC"
export OG_SDC="$OG_RESULTS/6_final.sdc"
[ -f "$OG_SDC" ] || export OG_SDC="$OG_RESULTS/4_cts.sdc"
[ -f "$OG_SDC" ] || export OG_SDC="$OG_RESULTS/3_place.sdc"
[ -f "$OG_SDC" ] || export OG_SDC="$OG_RESULTS/2_floorplan.sdc"

case "$MODE" in
  pre)
    export OG_DB="$OG_RESULTS/$3"; export OG_TAG="$4"; export OG_MODE=pre
    "$E/openroad" -no_init -exit "$HERE/og_extract.tcl"
    ;;
  post)
    export OG_DB="$OG_RESULTS/$3"; export OG_SPEF="$OG_RESULTS/$4"; export OG_TAG="$5"; export OG_MODE=post
    "$E/openroad" -no_init -exit "$HERE/og_extract.tcl"
    ;;
  rudy)
    export OG_DB="$OG_RESULTS/$3"; export OG_TAG="$4"
    "$E/openroad" -no_init -exit "$HERE/og_rudy.tcl"
    ;;
  *) echo "bad mode $MODE"; exit 1;;
esac
