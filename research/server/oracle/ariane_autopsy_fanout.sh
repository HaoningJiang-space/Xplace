#!/bin/bash
# MECHANISM AUTOPSY #2 (decisive): does the union-over-est gain survive FANOUT-NORMALIZATION?
# 4 arms: {est_metal5, union(metal5,routed)} x {broadcast, fanout_norm}, topk 13000, scale 1.0, GR fidelity.
# broadcast win reproduced => geometry-suspect; fanout_norm win SURVIVES => about WHICH nets (timing-like).
# No set -u. GPU 1 (GPU0=PPoPP).
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
PY=/data/ziheng/wzh/conda_envs/orfs/bin/python
EST=$B/ar_est_metal5_netslack.csv
ROUTED=$B/ar_backend/ar_base_netslack.csv
UNION=$B/ar_union_metal5.csv
$PY $B/blend_crit.py $EST $ROUTED $UNION
RES=$B/ariane_autopsy_fanout_results.txt; echo "arm mode hpwl droute_tns" > $RES
run () {
  arm=$1; csv=$2; mode=$3; pref="aut_${arm}_${mode}"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True --write_placement True \
    --oracle_timing_file $csv --oracle_timing_scale 1.0 --oracle_topk 13000 --oracle_pin_weight_mode $mode \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPD/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  OUTD=$B/aut_${arm}_${mode}_out; mkdir -p $OUTD
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
echo "AUTOPSY_FANOUT_DONE"; cat $RES
