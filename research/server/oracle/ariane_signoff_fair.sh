#!/bin/bash
# DECISIVE: does the R33 +15% SIGNOFF gain survive FAIR controls? est vs union, --use_cell_inflate,
# fanout_norm, --oracle_topfrac 0.10, --timing_force_frac $1, DR + OpenRCX coupling. Compare union vs est.
# Usage: bash ariane_signoff_fair.sh <frac>.  No set -u. GPU 1.
FRAC=${1:-0.3}
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge; OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad; XPD=/data/ziheng/wzh/xplace_dac/Xplace
EST=$B/ar_est_metal5_netslack.csv; UNION=$B/ar_union_metal5.csv
RES=$B/ariane_signoff_fair_results.txt; echo "arm frac hpwl dr_coupling_tns dr_wns" > $RES
run () {
  arm=$1; csv=$2; pref="sf_${arm}_f${FRAC}"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
  python main.py --custom_json $B/ariane.json --load_from_raw True --use_cell_inflate True --detail_placement True \
    --write_placement True --oracle_timing_file $csv --oracle_timing_scale 1.0 --oracle_topfrac 0.10 \
    --timing_force_frac $FRAC --oracle_pin_weight_mode fanout_norm --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPD/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  OUTD=$B/${pref}_out; mkdir -p $OUTD; export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_$pref.log 2>&1
  drt=$(grep DROUTE_DR_TNS $B/backend_$pref.log|awk '{print $2}')
  drw=$(grep DROUTE_DR_WNS $B/backend_$pref.log|awk '{print $2}')
  echo "$arm $FRAC $hpwl $drt $drw" >> $RES; echo "DONE $arm frac=$FRAC dr_coupling=$drt"
}
run est   $EST
run union $UNION
echo "SIGNOFF_FAIR_DONE"; cat $RES
