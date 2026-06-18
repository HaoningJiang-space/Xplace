#!/bin/bash
# bp_multi 3-arm GR-fidelity gain (intermediate-divergence, Spearman 0.776). 2-pass: base route ->
# est/routed criticality -> re-place fairest(est)/routed/union -> GR -> droute_tns. Tests the LAW's
# middle: does intermediate divergence give intermediate gain? No set -u. GPU 1 (GPU0=PPoPP).
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
PY=/data/ziheng/wzh/conda_envs/orfs/bin/python
EST=$B/bpmulti_base_out/bpmulti_base_place_netslack.csv
ROUTED=$B/bpmulti_base_out/bpmulti_base_netslack.csv
UNION=$B/bpmulti_union.csv
$PY $B/blend_crit.py $EST $ROUTED $UNION
declare -A NS=( [fairest]=$EST [routed]=$ROUTED [union]=$UNION )
RES=$B/bpmulti_arms_results.txt; echo "arm hpwl dplace_tns droute_tns" > $RES
for arm in fairest routed union; do
  pref="bpm_$arm"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
  python main.py --custom_json $B/bpmulti.json --load_from_raw True --detail_placement True --write_placement True \
    --oracle_timing_file ${NS[$arm]} --oracle_timing_scale 1.0 --oracle_topk 13000 \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPD/result/*/output/${pref}_bp_multi_top_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  OUTD=$B/bpm_${arm}_out; mkdir -p $OUTD
  export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=bpm_$arm; cd $B
  $OR -no_init -exit xplace_backend_bpmulti.tcl > $B/backend_bpm_$arm.log 2>&1
  dp=$(grep DPLACE_TNS $B/backend_bpm_$arm.log|awk '{print $2}')
  dr=$(grep DROUTE_TNS $B/backend_bpm_$arm.log|awk '{print $2}')
  echo "$arm $hpwl $dp $dr" >> $RES
  echo "DONE $arm hpwl=$hpwl droute_tns=$dr"
done
echo "BPMULTI_ARMS_DONE"; cat $RES
