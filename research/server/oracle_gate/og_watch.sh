#!/usr/bin/env bash
# Watch the ariane133/NanGate45 ORFS flow; when 6_final.spef lands, run the
# proven oracle-gate pipeline (PRE/POST/RUDY/seed-causality/Gate-A) into a
# dedicated out dir. Exit if the flow driver dies without producing SPEF.
source ~/miniconda3/etc/profile.d/conda.sh
conda activate /data/ziheng/wzh/conda_envs/orfs
FLOW=/data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow
SPEF=$FLOW/results/nangate45/ariane133/base/6_final.spef
HERE=/data/ziheng/wzh/oracle_gate/scripts
DRV_LOG=/data/ziheng/wzh/oracle_gate/logs/ariane_ng45.log
export OG_OUT=/data/ziheng/wzh/oracle_gate/out_ariane_ng45
export SEEDS="1 2 3"
export OG_NUMCORES=16
mkdir -p "$OG_OUT"

echo "WATCH_START $(date +%T)"
for i in $(seq 1 720); do   # up to ~6h at 30s
  if [ -f "$SPEF" ]; then
    echo "SPEF_FOUND $(date +%T) -> running oracle gate"
    DESIGN_CONFIG=./designs/nangate45/ariane133/config.mk \
      bash "$HERE/run_oracle_gate.sh" > "$OG_OUT/oracle_gate_run.log" 2>&1
    echo "ORACLE_GATE_RC=$? $(date +%T)"
    break
  fi
  # if the flow make has fully ended (driver printed MAKE_RC) and still no spef -> fail
  if grep -q "^MAKE_RC=" "$DRV_LOG" 2>/dev/null && [ ! -f "$SPEF" ]; then
    echo "FLOW_ENDED_NO_SPEF $(date +%T) -- macro/route likely failed; stopping watcher"
    tail -20 "$DRV_LOG"
    break
  fi
  sleep 30
done
echo "WATCH_END $(date +%T)"
