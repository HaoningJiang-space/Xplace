#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh
conda activate /data/ziheng/wzh/conda_envs/orfs
E=/data/ziheng/wzh/conda_envs/orfs/bin
export TMPDIR=/data/ziheng/wzh/tmp
cd /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow
sed -i "s/^export EQUIVALENCE_CHECK/# &/" designs/nangate45/ariane133/config.mk 2>/dev/null
echo START $(date +%T)
/usr/bin/time -v make DESIGN_CONFIG=./designs/nangate45/ariane133/config.mk NUM_CORES=16    OPENROAD_EXE=$E/openroad YOSYS_CMD=$E/yosys KLAYOUT_CMD=$E/klayout
echo MAKE_RC=$? $(date +%T)
ls -la results/nangate45/ariane133/base/6_final.spef 2>/dev/null && echo SPEF_OK || echo SPEF_MISSING
