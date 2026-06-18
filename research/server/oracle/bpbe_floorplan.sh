#!/bin/bash
# 2nd HIGH-DIVERGENCE design candidate: produce bp_be_top 2_floorplan.odb via ORFS (synth+floorplan+RTLMP
# macro place), the input for the Xplace bridge (extract place-input DEF -> Xplace places std cells ->
# backend routes -> est/routed netslack -> divergence + signoff arms). No set -u. No () in echo.
source ~/miniconda3/etc/profile.d/conda.sh
conda activate /data/ziheng/wzh/conda_envs/orfs
export TMPDIR=/data/ziheng/wzh/tmp; mkdir -p $TMPDIR
F=/data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow
cd $F
echo "BPBE_FLOORPLAN_START $(date +%H:%M:%S)"
# ORFS Makefile YOSYS_CMD/OPENROAD_EXE default to a non-existent tools/install build -> override to the
# conda orfs binaries (command-line vars survive the recipe unset + propagate to sub-makes).
YOS=/data/ziheng/wzh/conda_envs/orfs/bin/yosys
ORD=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
make YOSYS_CMD=$YOS OPENROAD_EXE=$ORD DESIGN_CONFIG=designs/nangate45/bp_be_top/config.mk floorplan
echo "BPBE_FLOORPLAN_DONE rc=$? $(date +%H:%M:%S)"
ls -la $F/results/nangate45/bp_be/base/2_floorplan.odb 2>/dev/null || echo "NO 2_floorplan.odb produced"
