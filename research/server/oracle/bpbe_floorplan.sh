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
make DESIGN_CONFIG=designs/nangate45/bp_be_top/config.mk floorplan
echo "BPBE_FLOORPLAN_DONE rc=$? $(date +%H:%M:%S)"
ls -la $F/results/nangate45/bp_be/base/2_floorplan.odb 2>/dev/null || echo "NO 2_floorplan.odb produced"
