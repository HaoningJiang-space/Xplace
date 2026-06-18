#!/bin/bash
# THE DECISIVE 4-source experiment (codex F / user): does post-CTS-est (NO routing) tie GR-routed at SIGNOFF?
# All criticality sources dumped on the SAME reference placement (infl_fairest), same actuation as R33
# (cell-inflate, scale 1.0, topk 13000) — vary ONLY the criticality SOURCE. Reference baseline = R33 fair-est
# (pre-CTS est) = -972.5. If post-CTS-est ≈ GR-routed (≈ -832) → route feedback UNNECESSARY (value = clock-aware
# post-CTS criticality); if GR-routed materially beats post-CTS-est → routing adds real info. CPU-DR concurrent.
# Place sequential GPU 1 (GPU0=PPoPP; coexist with concurrent bp_quad/signoff_fair on GPU1 — slower not wrong).
# No set -u. flock single-instance guard.
source ~/miniconda3/etc/profile.d/conda.sh
exec 200>/tmp/ariane_4src.lock; flock -n 200 || { echo "ALREADY_RUNNING"; exit 9; }
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
declare -A SRC=(
  [postcts]=$B/ariane_coupcrit/cc_est.csv                          # post-CTS est (no routing) — THE key arm
  [grrouted]=$B/ariane_samestage2/ss2_samestage_routed_netslack.csv # GR-routed (geometry)
  [coupling]=$B/ariane_coupcrit/cc_coupling.csv                     # DR+OpenRCX coupling-routed
)
declare -A DEFS
# --- 1. place 3 arms (cell-inflate, scale 1.0, topk 13000 = R33 actuation), sequential GPU 1 ---
for arm in postcts grrouted coupling; do
  pref="4src_$arm"; t0=$(date '+%Y-%m-%d %H:%M:%S')
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True --write_placement True \
    --use_cell_inflate True --oracle_timing_file ${SRC[$arm]} --oracle_timing_scale 1.0 --oracle_topk 13000 \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEFS[$arm]=$(find $XPD/result/*/output/ -name "${pref}_ariane_dp.def" -newermt "$t0" 2>/dev/null | head -1)
  [ -n "${DEFS[$arm]}" ] || { echo "FATAL $arm no fresh DEF"; tail -12 $B/place_$pref.log; exit 3; }
  m=$(grep "Oracle timing_pin_weight" $B/place_$pref.log | tail -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  echo "PLACED $arm hpwl=$hpwl DEF=${DEFS[$arm]} | $m $(date +%H:%M:%S)"
done
# --- 2. signoff DR + OpenRCX (validated R33 backend), concurrent ---
conda activate /data/ziheng/wzh/conda_envs/orfs
declare -A PIDS
for arm in postcts grrouted coupling; do
  OUTD=$B/4srcdr_$arm; mkdir -p $OUTD
  ( export XP_DEF=${DEFS[$arm]} XP_OUT=$OUTD XP_TAG=4srcdr_$arm; cd $B
    $OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_4srcdr_$arm.log 2>&1 ) &
  PIDS[$arm]=$!; echo "DR-LAUNCH $arm pid=${PIDS[$arm]} $(date +%H:%M:%S)"
done
for arm in postcts grrouted coupling; do wait ${PIDS[$arm]}; echo "DR-WAITED $arm $(date +%H:%M:%S)"; done
# --- 3. collect (gated: stale DR==GR / DRT_FAIL / DRC) ---
RES=$B/ariane_4src_results.txt; echo "arm gr_tns dr_coupling_tns dr_wns valid drc" > $RES
echo "REFERENCE pre-CTS fair-est (R33) = -972.47 ; routed (R33) = -831.98 ; union (R33) = -823.71" >> $RES
for arm in postcts grrouted coupling; do
  L=$B/backend_4srcdr_$arm.log
  grt=$(grep DROUTE_GR_TNS $L|awk '{print $2}'); drt=$(grep DROUTE_DR_TNS $L|awk '{print $2}'); drw=$(grep DROUTE_DR_WNS $L|awk '{print $2}')
  dn=$(grep -c BACKEND_DR_DONE $L); df=$(grep -c DRT_FAIL $L); v=$(grep -iE "Number of violations" $L|tail -1|grep -oE "= [0-9]+"|tr -d '= ')
  valid=OK; [ "$dn" = 0 ] && valid=NO_DONE; [ "$df" != 0 ] && valid=DRT_FAIL; [ -n "$grt" ] && [ "$drt" = "$grt" ] && valid=STALE
  echo "$arm $grt $drt $drw $valid viol=${v:-?}" >> $RES
done
echo "ARIANE_4SRC_DONE"; cat $RES
