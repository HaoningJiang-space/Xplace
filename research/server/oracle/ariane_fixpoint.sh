#!/bin/bash
# DE-CHEAT via fixed-point iteration (GP-centric, no oracle): iterate place->route->re-weight.
# Each placement uses the PREVIOUS route's routed criticality (available at place time => NOT
# cheating). Cold start from ESTIMATED criticality (what a deployable flow has pre-route).
# Question: does post-route TNS converge from the est level toward the oracle level (-2401)?
# If yes, the +20% is achievable ONLINE (iterative route-aware placement). ariane, GPU 1, no set -u.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
RES=$B/ariane_fixpoint_results.txt
echo "iter ns_source hpwl droute_tns wirecap_fF" > $RES
# cold start: estimated (pre-route) criticality
NS=$B/ar_backend/ar_base_place_netslack.csv
for k in 0 1 2 3 4; do
  pref="fp_k${k}"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True \
    --write_placement True --oracle_timing_file $NS --oracle_timing_scale 1.0 --oracle_topk 13000 \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPDIR/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  OUTD=$B/fp_$pref; mkdir -p $OUTD
  export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_ariane.tcl > $B/backend_$pref.log 2>&1
  dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}')
  wc=$(grep TOTAL_WIRE_CAP $B/backend_$pref.log|awk '{print $2}')
  echo "$k $(basename $NS) $hpwl $dr $wc" >> $RES
  echo "DONE $pref dr=$dr (ns was $(basename $NS))"
  # this placement's ROUTED criticality becomes the next iter's weight (the fixed-point feedback)
  NEWNS=$OUTD/${pref}_netslack.csv
  if [ -f "$NEWNS" ]; then NS=$NEWNS; else echo "WARN no netslack from $pref, stop"; break; fi
done
echo "FIXPOINT_DONE"; cat $RES
