#!/bin/bash
# 3rd-design locked-matrix on swerv_wrapper: cold(no-timing) -> est, routed, union arms. R23/R24.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge; OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad; XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
JSON=$B/swerv.json; BACKEND=xplace_backend_swerv.tcl; DPSUF=swerv_wrapper_dp
RES=$B/swerv_matrix_results.txt; echo "arm hpwl droute_tns wirecap_fF" > $RES
place_route() {  # $1=pref $2=extra-args
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
  python main.py --custom_json $JSON --load_from_raw True --detail_placement True --write_placement True \
    $2 --output_prefix $1 --gpu 1 > $B/place_$1.log 2>&1
  local DEF=$(ls -t $XPDIR/result/*/output/$1_${DPSUF}.def 2>/dev/null|head -1)
  local hpwl=$(grep "After DP, HPWL" $B/place_$1.log|tail -1|grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  local OUTD=$B/sw_$1; mkdir -p $OUTD; export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$1; cd $B
  $OR -no_init -exit $BACKEND > $B/backend_$1.log 2>&1
  local dr=$(grep DROUTE_TNS $B/backend_$1.log|awk '{print $2}'); local wc=$(grep TOTAL_WIRE_CAP $B/backend_$1.log|awk '{print $2}')
  echo "$1 $hpwl $dr $wc" >> $RES; echo "DONE $1 dr=$dr"
}
# 1) cold (no timing) -> produces est (place_netslack) + routed (netslack)
place_route sw_cold ""
EST=$B/sw_sw_cold/sw_cold_place_netslack.csv
ROUTED=$B/sw_sw_cold/sw_cold_netslack.csv
# 2) est arm  3) routed arm  4) union arm
place_route sw_est    "--oracle_timing_file $EST --oracle_timing_scale 1.0 --oracle_topk 13000"
place_route sw_routed "--oracle_timing_file $ROUTED --oracle_timing_scale 1.0 --oracle_topk 13000"
python3 $B/blend_crit.py $EST $ROUTED $B/swerv_blend_netslack.csv
place_route sw_union  "--oracle_timing_file $B/swerv_blend_netslack.csv --oracle_timing_scale 1.0 --oracle_topk 13000"
echo "SWERV_MATRIX_DONE"; cat $RES
