#!/bin/bash
# Parallel placement-variant sweep on aes/nangate45 -> the real Gate-A validation
# (within-net fixed-effects regression needs the SAME net at many positions).
set -u
source ~/miniconda3/etc/profile.d/conda.sh
conda activate /data/ziheng/wzh/conda_envs/orfs
E=/data/ziheng/wzh/conda_envs/orfs/bin
export TMPDIR=/data/ziheng/wzh/tmp
cd /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow
SWEEP=/data/ziheng/wzh/oracle_gate/aes_sweep
mkdir -p "$SWEEP/logs"
# ensure equivalence check off (needs missing eqy)
sed -i 's/^export EQUIVALENCE_CHECK/# &/' designs/nangate45/aes/config.mk 2>/dev/null

run_variant() {
  local d=$1 u=$2
  local v="d${d}_u${u}"
  /usr/bin/time -v make DESIGN_CONFIG=./designs/nangate45/aes/config.mk \
    FLOW_VARIANT="$v" PLACE_DENSITY="$d" CORE_UTILIZATION="$u" NUM_CORES=3 \
    OPENROAD_EXE=$E/openroad YOSYS_CMD=$E/yosys KLAYOUT_CMD=$E/klayout \
    > "$SWEEP/logs/$v.log" 2>&1
  local rc=$?
  # confirm SPEF produced
  if ls results/nangate45/aes/"$v"/6_final.spef >/dev/null 2>&1; then
     echo "OK   $v"; else echo "FAIL $v rc=$rc"; fi
}
export -f run_variant; export E SWEEP

MAX=16; N=0
for d in 0.55 0.65 0.72 0.80 0.88; do
  for u in 30 40 50 65; do
    run_variant "$d" "$u" &
    N=$((N+1))
    if (( N % MAX == 0 )); then wait; fi
  done
done
wait
echo "===SWEEP_DONE==="
echo "variants with SPEF:"
ls -d results/nangate45/aes/d*_u*/ 2>/dev/null | while read p; do
  ls "$p/6_final.spef" >/dev/null 2>&1 && echo "  $(basename $p)"
done
