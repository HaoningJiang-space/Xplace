#!/bin/bash
# DR-test one existing ariane DEF through the (GR-adjustment-fixed) backend; watch first-pass
# violations (DRT-0199) to decide if the GR 50% layer adjustment fixes the violation explosion.
# args: $1 = DEF path, $2 = tag. No set -u. CPU-only.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
DEF=$1; TAG=$2
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/drtest_$TAG; mkdir -p $OUTD
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$TAG; cd $B
echo "DRTEST start TAG=$TAG DEF=$DEF $(date +%H:%M:%S)"
$OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_drtest_$TAG.log 2>&1 &
ORPID=$!
for i in $(seq 1 50); do   # up to ~25 min
  sleep 30
  if ! kill -0 $ORPID 2>/dev/null; then echo "DR EXITED (FULL DONE) at check $i $(date +%H:%M:%S)"; break; fi
  v=$(grep -E "Number of violations" $B/backend_drtest_$TAG.log 2>/dev/null | tail -1)
  c=$(grep -E "Completing [0-9]+%" $B/backend_drtest_$TAG.log 2>/dev/null | tail -1)
  if [ -n "$v" ]; then echo "check $i: FIRST-PASS DONE -> $v ; killing to decide $(date +%H:%M:%S)"; kill -9 $ORPID 2>/dev/null; break; fi
  echo "check $i: $c"
done
echo "DRTEST_DONE TAG=$TAG"; grep DROUTE_GR_TNS $B/backend_drtest_$TAG.log 2>/dev/null
