#!/bin/bash
# Does union EVER beat est at MATCHED force norm? est vs union, fanout_norm, --timing_force_frac sweep, GR.
# frac 0.1 done (union<=est). If union pulls ahead at higher frac => criticality SET matters at sufficient
# force (VCERF holds, 0.1 too weak). If union stays <=est across fracs => gain was magnitude (artifact).
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge; OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad; XPD=/data/ziheng/wzh/xplace_dac/Xplace
EST=$B/ar_est_metal5_netslack.csv; UNION=$B/ar_union_metal5.csv
RES=$B/ariane_frac_sweep_results.txt; echo "arm frac hpwl droute_tns" > $RES
run () {
  arm=$1; csv=$2; frac=$3; pref="fs_${arm}_${frac}"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True --write_placement True \
    --oracle_timing_file $csv --oracle_timing_scale 1.0 --oracle_topfrac 0.10 --timing_force_frac $frac \
    --oracle_pin_weight_mode fanout_norm --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPD/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  OUTD=$B/${pref}_out; mkdir -p $OUTD; export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_ariane.tcl > $B/backend_$pref.log 2>&1
  dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}')
  echo "$arm $frac $hpwl $dr" >> $RES; echo "DONE $arm frac=$frac dr=$dr"
}
for f in 0.2 0.3 0.5; do run est $EST $f; run union $UNION $f; done
echo "FRAC_SWEEP_DONE"; cat $RES
