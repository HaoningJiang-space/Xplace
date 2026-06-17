#!/bin/bash
# FAIR baseline for bp_fe: est-criticality net-weight (the proper TDP baseline), to isolate the
# route-aware gain from the timing-vs-notiming gain. Uses iter0's PLACE (estimated) netslack.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge; OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad; XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
EST=$B/bpfp_bpfp_k0/bpfp_k0_place_netslack.csv
RES=$B/bpfe_estbase_results.txt; echo "arm hpwl droute_tns wirecap_fF" > $RES
pref="bpfe_est"
conda activate /data/ziheng/wzh/conda_envs/xplace
export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
python main.py --custom_json $B/bpfe.json --load_from_raw True --detail_placement True \
  --write_placement True --oracle_timing_file $EST --oracle_timing_scale 1.0 --oracle_topk 13000 \
  --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
DEF=$(ls -t $XPDIR/result/*/output/${pref}_bp_fe_top_dp.def 2>/dev/null | head -1)
hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/bpfe_est_out; mkdir -p $OUTD; export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
$OR -no_init -exit xplace_backend_bpfe.tcl > $B/backend_$pref.log 2>&1
dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}'); wc=$(grep TOTAL_WIRE_CAP $B/backend_$pref.log|awk '{print $2}')
echo "est_netweight $hpwl $dr $wc" >> $RES
echo "BPFE_EST_DONE dr=$dr"; cat $RES
