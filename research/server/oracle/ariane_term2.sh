#!/bin/bash
# TERM-2 prototype test on ariane (oracle routed criticality, same back-end as the +20% arms).
# Does adding the timing-weighted congestion (route) force on top of the routed net-weighting
# (-2401, the +20% positive) further improve post-route TNS? And does the TIMING-WEIGHTING of the
# route force (vs uniform) matter? Arms (all use routed-criticality net-weight, scale 1.0):
#   nw   : net-weight only                         (= -2401 baseline; rerun for matched env)
#   rf0  : + uniform route force (alpha=0)         (--use_route_force, timing_route_weight 0)
#   rf1  : + timing-weighted route force (alpha=1) (--timing_route_weight 1.0)   <- TERM-2
#   rf2  : + timing-weighted route force (alpha=2)
# NO set -u (conda orfs deactivate refs unbound ZSH_VERSION). Resumable via BACKEND_DONE.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
NS=$B/ar_backend/ar_base_netslack.csv   # routed criticality (the winning source)
RES=$B/ariane_term2_results.txt
[ -f "$RES" ] || echo "arm route_w timing_route_w hpwl dplace_tns droute_tns wirecap_fF gr_engaged term2_on" > $RES
run() {
  local arm=$1 rw=$2 trw=$3 extra=$4
  local pref="t2_${arm}"
  if grep -q BACKEND_DONE $B/backend_$pref.log 2>/dev/null; then echo "SKIP $pref"; return; fi
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True \
    --write_placement True --oracle_timing_file $NS --oracle_timing_scale 1.0 \
    $extra --route_weight $rw --congest_weight $rw --timing_route_weight $trw \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  local DEF=$(ls -t $XPDIR/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  local hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  local gr=$(grep -c "Start GR" $B/place_$pref.log)
  local t2=$(grep -c "\[TERM-2\]" $B/place_$pref.log)
  conda activate /data/ziheng/wzh/conda_envs/orfs
  export XP_DEF=$DEF XP_OUT=$B/t2_$pref XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_ariane.tcl > $B/backend_$pref.log 2>&1
  local dp=$(grep DPLACE_TNS $B/backend_$pref.log|awk '{print $2}')
  local dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}')
  local wc=$(grep TOTAL_WIRE_CAP $B/backend_$pref.log|awk '{print $2}')
  echo "$arm $rw $trw $hpwl $dp $dr $wc $gr $t2" >> $RES
  echo "DONE $pref dr=$dr gr=$gr term2=$t2"
}
run nw  0   0   ""
run rf0 1.0 0   "--use_route_force True"
run rf1 1.0 1.0 "--use_route_force True"
run rf2 1.0 2.0 "--use_route_force True"
echo "TERM2_DONE"; cat $RES
