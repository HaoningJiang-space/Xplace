#!/usr/bin/env bash
# og_env.sh : resolve ORFS design context into OG_* env vars, fully design-parametrized.
# Usage:  source og_env.sh <DESIGN_CONFIG_relative_to_flow>
#   e.g.  source og_env.sh ./designs/nangate45/aes/config.mk
#         source og_env.sh ./designs/asap7/ariane133/config.mk
# Requires: ORFS_FLOW (flow dir) and E (conda bin dir) in env, OR uses defaults below.
set -euo pipefail
ORFS_FLOW="${ORFS_FLOW:-/data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow}"
E="${E:-/data/ziheng/wzh/conda_envs/orfs/bin}"
DC="$1"
cd "$ORFS_FLOW"
MK="make DESIGN_CONFIG=$DC OPENROAD_EXE=$E/openroad YOSYS_CMD=$E/yosys KLAYOUT_CMD=$E/klayout"
getv(){ $MK print-$1 2>/dev/null | sed -n "s/^$1 = //p" | head -1; }

export OG_PLATFORM="$(getv PLATFORM)"
export OG_DESIGN="$(getv DESIGN_NICKNAME)"
export OG_DESIGN_NAME="$(getv DESIGN_NAME)"
export OG_RESULTS="$(getv RESULTS_DIR)"
export OG_TECH_LEF="$(getv TECH_LEF)"
export OG_SC_LEF="$(getv SC_LEF)"
export OG_ADD_LEFS="$(getv ADDITIONAL_LEFS)"
export OG_LIB_FILES="$(getv LIB_FILES)"
export OG_PLATFORM_DIR="$(getv PLATFORM_DIR)"
export OG_SETRC="$OG_PLATFORM_DIR/setRC.tcl"
# all lefs and libs the extraction must load (tech + sc + any additional)
export OG_LEFS="$OG_TECH_LEF $OG_SC_LEF $OG_ADD_LEFS"
export OG_LIBS="$OG_LIB_FILES"
export OG_MINLAYER="$(getv MIN_ROUTING_LAYER)"
export OG_MAXLAYER="$(getv MAX_ROUTING_LAYER)"
export OG_RCX_RULES="$(getv RCX_RULES)"
echo "OG_PLATFORM=$OG_PLATFORM OG_DESIGN=$OG_DESIGN"
echo "OG_RESULTS=$OG_RESULTS"
echo "OG_SETRC=$OG_SETRC"
