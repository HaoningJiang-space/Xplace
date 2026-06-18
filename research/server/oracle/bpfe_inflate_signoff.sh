#!/bin/bash
# ★ 2nd-design SIGNOFF (goal #12): the bp_fe analog of ariane R33. Place the 3 R23 arms
# (fairest=place-est / routed / union=max) with --use_cell_inflate (routability-grade) + their
# criticality, then detailed_route TO COMPLETION + OpenRCX coupling extraction (SPEF-correct backend).
# THESIS PREDICTION (divergence law): bp_fe est is well-calibrated (Jaccard est~routed 0.94, Spearman
# 0.99) -> route-awareness has little NEW info -> union should be ~flat vs fairest (small gap), and
# pure-routed should NOT beat est. This is the NEGATIVE-CONTROL point: it makes the thesis a predictive
# LAW (big gain only when divergence is high, as on ariane +15.3%), not "always add routing".
# Place sequential GPU 1 (GPU0=PPoPP, do not touch); DR concurrent (CPU). No set -u (per standing rule).
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
EST=$B/bpfp_bpfp_k0/bpfp_k0_place_netslack.csv     # placement-stage (estimate) criticality = fair baseline
ROUTED=$B/bpfp_bpfp_k0/bpfp_k0_netslack.csv         # routed-slack criticality
UNION=$B/bpfe_signoff_union.csv
python3 $B/blend_crit.py $EST $ROUTED $UNION
declare -A NS=( [fairest]=$EST [routed]=$ROUTED [union]=$UNION )
declare -A DEFS
# --- 1. place all 3 arms with cell inflation (sequential, GPU 1) ---
for arm in fairest routed union; do
  pref="bsg_$arm"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
  python main.py --custom_json $B/bpfe.json --load_from_raw True --detail_placement True --write_placement True \
    --use_cell_inflate True --oracle_timing_file ${NS[$arm]} --oracle_timing_scale 1.0 --oracle_topk 13000 \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEFS[$arm]=$(ls -t $XPD/result/*/output/${pref}_bp_fe_top_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  echo "PLACED $arm DEF=${DEFS[$arm]} hpwl=$hpwl $(date +%H:%M:%S)"
done
# --- 2. DR + OpenRCX all 3 concurrently (CPU) ---
conda activate /data/ziheng/wzh/conda_envs/orfs
declare -A PIDS
for arm in fairest routed union; do
  OUTD=$B/bsgdr_$arm; mkdir -p $OUTD
  ( export XP_DEF=${DEFS[$arm]} XP_OUT=$OUTD XP_TAG=bsgdr_$arm; cd $B
    $OR -no_init -exit xplace_backend_bpfe_dr.tcl > $B/backend_bsgdr_$arm.log 2>&1 ) &
  PIDS[$arm]=$!
  echo "DR-LAUNCH $arm pid=${PIDS[$arm]} $(date +%H:%M:%S)"
done
for arm in fairest routed union; do wait ${PIDS[$arm]}; echo "DR-WAITED $arm $(date +%H:%M:%S)"; done
# --- 3. collect ---
RES=$B/bpfe_inflate_signoff_results.txt; echo "arm gr_tns dr_coupling_tns dr_wns drc_viol" > $RES
for arm in fairest routed union; do
  grt=$(grep BPFE_GR_TNS $B/backend_bsgdr_$arm.log|awk '{print $2}')
  drt=$(grep BPFE_DR_TNS $B/backend_bsgdr_$arm.log|awk '{print $2}')
  drw=$(grep BPFE_DR_WNS $B/backend_bsgdr_$arm.log|awk '{print $2}')
  viol=$(grep -iE "violations|number of drc" $B/backend_bsgdr_$arm.log|tail -1)
  echo "$arm $grt $drt $drw | $viol" >> $RES
done
echo "BPFE_INFLATE_SIGNOFF_DONE"; cat $RES
