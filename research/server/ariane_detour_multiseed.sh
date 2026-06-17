#!/bin/bash
# Multi-seed decider: is the matched-HPWL arc-detour +1.4% (w=0.002) a real signal or single-seed
# noise? base (no detour) vs arc w=0.002, oracle routed criticality scale 1.0, seeds 0/1/2, GPU 1.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
NS=$B/ar_backend/ar_base_netslack.csv
RES=$B/ariane_detour_multiseed_results.txt
echo "arm seed hpwl dplace_tns droute_tns wirecap_fF" > $RES

run_arm () {
  pref=$1; seed=$2; shift 2; extra="$*"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH
  export PYTHONPATH=$XPDIR:$PYTHONPATH
  cd $XPDIR
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True \
    --write_placement True --oracle_timing_file $NS --oracle_timing_scale 1.0 \
    --seed $seed --output_prefix $pref --gpu 1 $extra > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPDIR/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  export XP_DEF=$DEF XP_OUT=$B/arsweep_$pref XP_TAG=$pref
  cd $B
  $OR -no_init -exit xplace_backend_ariane.tcl > $B/backend_$pref.log 2>&1
  dp=$(grep DPLACE_TNS $B/backend_$pref.log | awk '{print $2}')
  dr=$(grep DROUTE_TNS $B/backend_$pref.log | awk '{print $2}')
  wc=$(grep TOTAL_WIRE_CAP $B/backend_$pref.log | awk '{print $2}')
  echo "$pref $seed $hpwl $dp $dr $wc" >> $RES
  echo "DONE $pref dr=$dr hpwl=$hpwl"
}

for seed in 0 1 2; do
  run_arm dms_base_s$seed   $seed
  run_arm dms_arc002_s$seed $seed --detour_timing_weight 0.002 --detour_arc True
done
echo "DETOUR_MULTISEED_DONE"
cat $RES
