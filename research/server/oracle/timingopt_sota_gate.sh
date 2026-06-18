#!/bin/bash
# SOTA GATE (user): give Xplace's OWN --timing_opt its BEST shot at signoff (route the existing fmto_w*
# placements across the routable weight range through the validated R33 signoff backend), then compare its
# best DR+OpenRCX TNS to the clock-aware (post-CTS-est) net-weight arm = -830.6 (R43). --timing_opt is a
# 1-pass live pre-CTS path-based STA pull; clock-aware is a 2-pass post-CTS-criticality net-weight. Reuses
# existing placements (CPU-only DR, no GPU, no collision with concurrent bp_quad/signoff_fair). flock guard.
source ~/miniconda3/etc/profile.d/conda.sh
exec 200>/tmp/timingopt_sota.lock; flock -n 200 || { echo "ALREADY_RUNNING"; exit 9; }
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
conda activate /data/ziheng/wzh/conda_envs/orfs
declare -A DEFS PIDS
for w in 0.005 0.01 0.03; do
  DEFS[$w]=$(ls -t $XPD/result/*/output/fmto_w${w}_ariane_dp.def 2>/dev/null | head -1)
  [ -n "${DEFS[$w]}" ] || { echo "WARN no fmto_w$w DEF"; continue; }
  OUTD=$B/sota_to_$w; mkdir -p $OUTD
  ( export XP_DEF=${DEFS[$w]} XP_OUT=$OUTD XP_TAG=sota_to_$w; cd $B
    $OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_sota_to_$w.log 2>&1 ) &
  PIDS[$w]=$!; echo "DR-LAUNCH timing_opt w=$w pid=${PIDS[$w]} $(date +%H:%M:%S)"
done
for w in 0.005 0.01 0.03; do [ -n "${PIDS[$w]}" ] && wait ${PIDS[$w]}; echo "DR-WAITED w=$w $(date +%H:%M:%S)"; done
RES=$B/timingopt_sota_gate_results.txt
echo "method weight dr_coupling_tns dr_wns valid drc" > $RES
echo "clock-aware(post-CTS-est,R43) scale1.0 -830.62 -0.5172 OK viol=0   <- the 2-pass clock-aware arm" >> $RES
echo "timing_opt(fmto,prior) w0.02 -968.90 -0.5723 OK viol=0" >> $RES
for w in 0.005 0.01 0.03; do
  L=$B/backend_sota_to_$w.log; [ -f "$L" ] || continue
  drt=$(grep DROUTE_DR_TNS $L|awk '{print $2}'); drw=$(grep DROUTE_DR_WNS $L|awk '{print $2}'); grt=$(grep DROUTE_GR_TNS $L|awk '{print $2}')
  dn=$(grep -c BACKEND_DR_DONE $L); df=$(grep -c DRT_FAIL $L); v=$(grep -iE "Number of violations" $L|tail -1|grep -oE "= [0-9]+"|tr -d '= ')
  valid=OK; [ "$dn" = 0 ] && valid=NO_DONE; [ "$df" != 0 ] && valid=DRT_FAIL; [ -n "$grt" ] && [ "$drt" = "$grt" ] && valid=STALE
  echo "timing_opt w$w $drt $drw $valid viol=${v:-?}" >> $RES
done
echo "TIMINGOPT_SOTA_GATE_DONE"; cat $RES
