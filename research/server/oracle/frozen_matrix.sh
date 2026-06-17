#!/bin/bash
# Validate the FROZEN auto-cal rule (--timing_force_frac 0.1) on the 2 valid designs: est vs union.
# codex flaw-2: a frozen, design-invariant rule must keep the route-aware (union) gain.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge; OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad; XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
FRAC=0.1
RES=$B/frozen_matrix_results.txt; echo "design arm hpwl droute_tns" > $RES
run() { # design json backend dpsuf est routed
  local D=$1 JSON=$2 BACKEND=$3 DPSUF=$4 EST=$5 ROUTED=$6
  python3 $B/blend_crit.py $EST $ROUTED $B/${D}_fz_blend.csv
  for arm in est union; do
    local NS=$EST; [ "$arm" = union ] && NS=$B/${D}_fz_blend.csv
    local pref="fz_${D}_${arm}"
    conda activate /data/ziheng/wzh/conda_envs/xplace
    export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
    python main.py --custom_json $JSON --load_from_raw True --detail_placement True --write_placement True \
      --oracle_timing_file $NS --oracle_timing_scale 1.0 --oracle_topk 13000 --timing_force_frac $FRAC \
      --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
    local DEF=$(ls -t $XPDIR/result/*/output/${pref}_${DPSUF}.def 2>/dev/null|head -1)
    local hpwl=$(grep "After DP, HPWL" $B/place_$pref.log|tail -1|grep -oE "[0-9.]+E[+][0-9]+")
    conda activate /data/ziheng/wzh/conda_envs/orfs
    local OUTD=$B/fz_$pref; mkdir -p $OUTD; export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
    $OR -no_init -exit $BACKEND > $B/backend_$pref.log 2>&1
    local dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk "{print \$2}")
    echo "$D $arm $hpwl $dr" >> $RES; echo "DONE $pref dr=$dr"
  done
}
run ariane $B/ariane.json xplace_backend_ariane.tcl ariane_dp $B/ar_backend/ar_base_place_netslack.csv $B/ar_backend/ar_base_netslack.csv
run bpfe $B/bpfe.json xplace_backend_bpfe.tcl bp_fe_top_dp $B/bpfp_bpfp_k0/bpfp_k0_place_netslack.csv $B/bpfp_bpfp_k0/bpfp_k0_netslack.csv
echo "FROZEN_MATRIX_DONE"; cat $RES
