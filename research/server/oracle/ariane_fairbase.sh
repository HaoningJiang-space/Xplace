#!/bin/bash
# HONEST fair-baseline gain: ariane, same mechanism (scale 1.0, top-13k), vary ONLY criticality source:
# fair-est(metal5) vs routed vs union(metal5,routed). Does route-aware beat the FAIR est (not metal3)?
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge; OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad; XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
FE=$B/ar_est_metal5_netslack.csv          # fair-layer est criticality
RT=$B/ar_backend/ar_base_netslack.csv     # routed criticality
python3 $B/blend_crit.py $FE $RT $B/ar_fair_union.csv
RES=$B/ariane_fairbase_results.txt; echo "arm hpwl droute_tns" > $RES
for arm in fairest routed union; do
  case $arm in fairest) NS=$FE;; routed) NS=$RT;; union) NS=$B/ar_fair_union.csv;; esac
  pref="fb_$arm"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True --write_placement True \
    --oracle_timing_file $NS --oracle_timing_scale 1.0 --oracle_topk 13000 \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPDIR/result/*/output/${pref}_ariane_dp.def 2>/dev/null|head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log|tail -1|grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  OUTD=$B/fb_$arm; mkdir -p $OUTD; export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_ariane.tcl > $B/backend_$pref.log 2>&1
  dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}')
  echo "$arm $hpwl $dr" >> $RES; echo "DONE $pref dr=$dr"
done
echo "FAIRBASE_DONE"; cat $RES
