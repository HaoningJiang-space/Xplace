#!/bin/bash
# TERM-2 v1 test (corrected mechanism): per-bin critical-corridor concentration + aggressor-only
# push. vs nw baseline (-2401). Does surgical critical-corridor clearing beat net-weighting alone?
# Lower route_weight too (v0's rw=1.0 over-spread; v1 is surgical so should inflate WL less).
# NO set -u. Resumable via BACKEND_DONE.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
NS=$B/ar_backend/ar_base_netslack.csv
RES=$B/ariane_term2v1_results.txt
echo "arm route_w timing_route_w hpwl dplace_tns droute_tns wirecap_fF gr term2v1" > $RES
run() {
  local arm=$1 rw=$2 trw=$3
  local pref="t2v1_${arm}"
  if grep -q BACKEND_DONE $B/backend_$pref.log 2>/dev/null; then echo "SKIP $pref"; return; fi
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True \
    --write_placement True --oracle_timing_file $NS --oracle_timing_scale 1.0 \
    --use_route_force True --route_weight $rw --congest_weight $rw --timing_route_weight $trw \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  local DEF=$(ls -t $XPDIR/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  local hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  local gr=$(grep -c "Start GR" $B/place_$pref.log)
  local t2=$(grep -c "TERM-2 v1" $B/place_$pref.log)
  conda activate /data/ziheng/wzh/conda_envs/orfs
  export XP_DEF=$DEF XP_OUT=$B/t2v1_$pref XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_ariane.tcl > $B/backend_$pref.log 2>&1
  local dp=$(grep DPLACE_TNS $B/backend_$pref.log|awk '{print $2}')
  local dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}')
  local wc=$(grep TOTAL_WIRE_CAP $B/backend_$pref.log|awk '{print $2}')
  echo "$arm $rw $trw $hpwl $dp $dr $wc $gr $t2" >> $RES
  echo "DONE $pref dr=$dr gr=$gr t2v1=$t2"
}
run a 1.0 1.0
run b 0.3 1.0
run c 1.0 2.0
echo "TERM2V1_DONE"; cat $RES
