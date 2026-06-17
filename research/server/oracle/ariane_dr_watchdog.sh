#!/bin/bash
# Diagnostic: retry ariane detailed_route with a watchdog to decide transient-vs-deterministic hang.
# ORFS golden routes ariane: "Init gr pin query" completes in ~37s, then routing proceeds.
# My prior run hung 3h17m at that step. Watchdog: if no routing progress ("Completing"/violations)
# within 12 min, kill -> deterministic hang (density-1.0 GR-guide pathology). No set -u. CPU-only.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
DEF=/data/ziheng/wzh/xplace_dac/Xplace/result/2026-06-18-01:35:21_mgc_superblue12/output/dms_base_s0_ariane_dp.def
LOG=$B/backend_ariane_dr_wd.log
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/ariane_dr_wd_out; mkdir -p $OUTD
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=ar_wd; cd $B
echo "WD_START $(date +%H:%M:%S) DEF=$DEF"
$OR -no_init -exit xplace_backend_ariane_dr.tcl > $LOG 2>&1 &
ORPID=$!
echo "WD openroad pid=$ORPID"
hung=1
for i in $(seq 1 36); do   # 36 * 20s = 12 min
  sleep 20
  if ! kill -0 $ORPID 2>/dev/null; then echo "WD openroad EXITED at check $i"; hung=0; break; fi
  if grep -qE "Completing [0-9]+%|Number of violations|BACKEND_DR_DONE" $LOG 2>/dev/null; then
    echo "WD PROGRESS past init at check $i ($(date +%H:%M:%S)) -> NOT hung, leaving it to route"
    hung=0; break
  fi
  laststep=$(grep -E "DRT-0179|Init gr pin|pin access|Start routing" $LOG 2>/dev/null | tail -1)
  echo "WD check $i: still in init [$laststep]"
done
if [ "$hung" = "1" ]; then
  echo "WD DETERMINISTIC HANG confirmed (12 min no routing progress) -> killing $ORPID"
  kill -9 $ORPID 2>/dev/null
  echo "WD_RESULT DETERMINISTIC_HANG_AT_INIT"
else
  echo "WD_RESULT PROGRESSED (routing in background, pid=$ORPID)"
fi
echo "=== last 6 log lines ==="; tail -6 $LOG
