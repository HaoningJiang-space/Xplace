#!/bin/bash
# METHOD_DERIVATION P1 (decisive mechanism control): ariane est vs union, broadcast vs fanout_norm,
# at CONSTANT FRACTION (--oracle_topfrac 0.10) + MATCHED FORCE NORM (--timing_force_frac 0.1).
# Under matched norm, broadcast vs fanout_norm differ ONLY in force DISTRIBUTION. If union still beats
# est under fanout_norm => gain is about WHICH endpoints (VCERF-valid); if collapses => fanout/geometry.
# No set -u. GPU 1 (GPU0=PPoPP).
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
EST=$B/ar_est_metal5_netslack.csv
UNION=$B/ar_union_metal5.csv
RES=$B/ariane_autopsy_p1_results.txt; echo "arm mode hpwl droute_tns" > $RES
run () {
  arm=$1; csv=$2; mode=$3; pref="p1_${arm}_${mode}"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True --write_placement True \
    --oracle_timing_file $csv --oracle_timing_scale 1.0 --oracle_topfrac 0.10 --timing_force_frac 0.1 \
    --oracle_pin_weight_mode $mode --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPD/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  OUTD=$B/p1_${arm}_${mode}_out; mkdir -p $OUTD
  export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_ariane.tcl > $B/backend_$pref.log 2>&1
  dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}')
  echo "$arm $mode $hpwl $dr" >> $RES
  echo "DONE $arm/$mode hpwl=$hpwl droute_tns=$dr"
}
run est   $EST   broadcast
run union $UNION broadcast
run est   $EST   fanout_norm
run union $UNION fanout_norm
echo "AUTOPSY_P1_DONE"; cat $RES
