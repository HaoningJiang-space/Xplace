#!/bin/bash
# Find the design-invariant timing-force fraction on swerv (the over-pull case). est arm, frac sweep.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge; OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad; XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
EST=$B/sw_sw_cold/sw_cold_place_netslack.csv
RES=$B/swerv_fraccal_results.txt; echo "frac hpwl droute_tns" > $RES
for fr in 0.05 0.1 0.2; do
  pref="swfc_$fr"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
  python main.py --custom_json $B/swerv.json --load_from_raw True --detail_placement True --write_placement True \
    --oracle_timing_file $EST --oracle_timing_scale 1.0 --oracle_topk 13000 --timing_force_frac $fr \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPDIR/result/*/output/${pref}_swerv_wrapper_dp.def 2>/dev/null|head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log|tail -1|grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  OUTD=$B/swfc_$fr; mkdir -p $OUTD; export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_swerv.tcl > $B/backend_$pref.log 2>&1
  dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}')
  echo "$fr $hpwl $dr" >> $RES; echo "DONE frac=$fr hpwl=$hpwl dr=$dr"
done
echo "SWERV_FRACCAL_DONE"; cat $RES
