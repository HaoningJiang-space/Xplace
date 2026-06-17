#!/bin/bash
# A/B: does the arc-level differentiable detour term improve post-route TNS on ariane, on top of
# the routed-criticality net-weight baseline? Isolates the DETOUR effect (oracle routed criticality
# held fixed at scale 1.0; toggle --detour_arc + weight). GPU 1 ONLY (GPU 0 = PPoPP). No `set -u`.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
NS=$B/ar_backend/ar_base_netslack.csv          # routed-criticality oracle (the +9.8% baseline source)
RES=$B/ariane_detour_arc_small_results.txt
echo "arm hpwl dplace_tns droute_tns wirecap_fF" > $RES

run_arm () {
  pref=$1; shift; extra="$*"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH
  export PYTHONPATH=$XPDIR:$PYTHONPATH
  cd $XPDIR
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True \
    --write_placement True --oracle_timing_file $NS --oracle_timing_scale 1.0 \
    --output_prefix $pref --gpu 1 $extra > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPDIR/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  export XP_DEF=$DEF XP_OUT=$B/arsweep_$pref XP_TAG=$pref
  cd $B
  $OR -no_init -exit xplace_backend_ariane.tcl > $B/backend_$pref.log 2>&1
  dp=$(grep DPLACE_TNS $B/backend_$pref.log | awk '{print $2}')
  dr=$(grep DROUTE_TNS $B/backend_$pref.log | awk '{print $2}')
  wc=$(grep TOTAL_WIRE_CAP $B/backend_$pref.log | awk '{print $2}')
  echo "$pref $hpwl $dp $dr $wc" >> $RES
  echo "DONE $pref dr=$dr hpwl=$hpwl"
}

run_arm ardet_base2
run_arm ardet_arc0005 --detour_timing_weight 0.005 --detour_arc True
run_arm ardet_arc0002 --detour_timing_weight 0.002 --detour_arc True
echo "DETOUR_ARC_DONE"
cat $RES
