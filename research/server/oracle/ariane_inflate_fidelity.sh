#!/bin/bash
# ★ The clean DR+coupling fidelity run (R31 next-phase): place all 3 R29 arms (fairest/routed/union)
# with --use_cell_inflate (routability-grade) + their criticality, then detailed_route TO COMPLETION
# + OpenRCX coupling extraction. Tests whether the route-aware union gain survives at routability-grade
# density AND coupling-signoff fidelity. Gate passed (union inflate DR ~30k viols @60% = ORFS-level).
# Place sequential on GPU 1 (GPU0=PPoPP); DR concurrent (CPU). No set -u.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
declare -A NS=(
  [fairest]=$B/ar_est_metal5_netslack.csv
  [routed]=$B/ar_backend/ar_base_netslack.csv
  [union]=$B/ar_fair_union.csv
)
declare -A DEFS
# --- 1. place all 3 arms with cell inflation (sequential, GPU 1) ---
for arm in fairest routed union; do
  pref="infl_$arm"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True --write_placement True \
    --use_cell_inflate True --oracle_timing_file ${NS[$arm]} --oracle_timing_scale 1.0 --oracle_topk 13000 \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEFS[$arm]=$(ls -t $XPD/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  echo "PLACED $arm DEF=${DEFS[$arm]} hpwl=$hpwl $(date +%H:%M:%S)"
done
# --- 2. DR + OpenRCX all 3 concurrently (CPU) ---
conda activate /data/ziheng/wzh/conda_envs/orfs
declare -A PIDS
for arm in fairest routed union; do
  OUTD=$B/infldr_$arm; mkdir -p $OUTD
  ( export XP_DEF=${DEFS[$arm]} XP_OUT=$OUTD XP_TAG=infldr_$arm; cd $B
    $OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_infldr_$arm.log 2>&1 ) &
  PIDS[$arm]=$!
  echo "DR-LAUNCH $arm pid=${PIDS[$arm]} $(date +%H:%M:%S)"
done
for arm in fairest routed union; do wait ${PIDS[$arm]}; echo "DR-WAITED $arm $(date +%H:%M:%S)"; done
# --- 3. collect (HARDENED per codex #9 + user harness-audit: gate on DR-DONE / DRT_FAIL / DRC, and
#         auto-detect the stale DR_TNS==GR_TNS inert-extraction bug that produced the OLD bogus results) ---
RES=$B/ariane_inflate_fidelity_results.txt; echo "arm gr_tns dr_tns dr_wns valid drc_viol" > $RES
for arm in fairest routed union; do
  L=$B/backend_infldr_$arm.log
  grt=$(grep DROUTE_GR_TNS $L|awk '{print $2}')
  drt=$(grep DROUTE_DR_TNS $L|awk '{print $2}')
  drw=$(grep DROUTE_DR_WNS $L|awk '{print $2}')
  done_ok=$(grep -c BACKEND_DR_DONE $L); drt_fail=$(grep -c DRT_FAIL $L)
  viol=$(grep -iE "Number of violations" $L|tail -1|grep -oE "= [0-9]+"|tr -d '= ')
  valid=OK; [ "$done_ok" = 0 ] && valid=NO_DONE; [ "$drt_fail" != 0 ] && valid=DRT_FAIL
  # STALE-bug guard: if DR coupling TNS == GR TNS exactly, extract_parasitics didn't reach STA (no SPEF readback)
  [ -n "$grt" ] && [ "$drt" = "$grt" ] && valid=STALE_DR==GR
  echo "$arm $grt $drt $drw $valid viol=${viol:-?}" >> $RES
done
echo "ARIANE_INFLATE_FIDELITY_DONE"; cat $RES
