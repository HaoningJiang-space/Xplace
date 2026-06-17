#!/bin/bash
# Multi-seed robustness confirmation of the POSITIVE result:
# routed-criticality net-weighting vs estimated-criticality net-weighting (force-matched,
# same mechanism, scale 1.0, K=13000), across 3 placement seeds, on ariane (NanGate45).
# Hardens the +20% fair-isolation positive (ariane_arms_results.txt). GPU 1 (GPU 0 = PPoPP job).
set -u
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
RES=$B/ariane_multiseed_results.txt
echo "arm seed hpwl dplace_tns droute_tns wirecap_fF" > $RES
declare -A NS=( [routed]=$B/ar_backend/ar_base_netslack.csv [est]=$B/ar_backend/ar_base_place_netslack.csv )
SC=1.0
for seed in 0 1 2; do
 for arm in routed est; do
  pref="ms_${arm}_s${seed}"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True \
    --write_placement True --oracle_timing_file ${NS[$arm]} --oracle_timing_scale $SC \
    --seed $seed --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPDIR/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  export XP_DEF=$DEF XP_OUT=$B/arms_$pref XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_ariane.tcl > $B/backend_$pref.log 2>&1
  dp=$(grep DPLACE_TNS $B/backend_$pref.log|awk '{print $2}')
  dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}')
  wc=$(grep TOTAL_WIRE_CAP $B/backend_$pref.log|awk '{print $2}')
  echo "$arm $seed $hpwl $dp $dr $wc" >> $RES
  echo "DONE $pref dr=$dr"
 done
done
echo "MULTISEED_DONE"; cat $RES
