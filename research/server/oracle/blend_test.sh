#!/bin/bash
# R23: test BLENDED criticality (per-net min slack of est & routed = "critical if EITHER says so")
# vs est vs routed, on a design. Robust-method test. Env: DESIGN=ariane|bpfe
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge; OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad; XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
D=${DESIGN:-ariane}
if [ "$D" = "ariane" ]; then
  JSON=$B/ariane.json; BACKEND=xplace_backend_ariane.tcl; DPSUF=ariane_dp
  EST=$B/ar_backend/ar_base_place_netslack.csv; ROUTED=$B/ar_backend/ar_base_netslack.csv
else
  JSON=$B/bpfe.json; BACKEND=xplace_backend_bpfe.tcl; DPSUF=bp_fe_top_dp
  EST=$B/bpfp_bpfp_k0/bpfp_k0_place_netslack.csv; ROUTED=$B/bpfp_bpfp_k0/bpfp_k0_netslack.csv
fi
BLEND=$B/${D}_blend_netslack.csv
python3 $B/blend_crit.py $EST $ROUTED $BLEND
RES=$B/${D}_blend_results.txt; echo "arm hpwl droute_tns wirecap_fF" > $RES
pref="bl_${D}"
conda activate /data/ziheng/wzh/conda_envs/xplace
export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
python main.py --custom_json $JSON --load_from_raw True --detail_placement True \
  --write_placement True --oracle_timing_file $BLEND --oracle_timing_scale 1.0 --oracle_topk 13000 \
  --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
DEF=$(ls -t $XPDIR/result/*/output/${pref}_${DPSUF}.def 2>/dev/null | head -1)
hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/${pref}_out; mkdir -p $OUTD; export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
$OR -no_init -exit $BACKEND > $B/backend_$pref.log 2>&1
dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}'); wc=$(grep TOTAL_WIRE_CAP $B/backend_$pref.log|awk '{print $2}')
echo "blended $hpwl $dr $wc" >> $RES
echo "BLEND_${D}_DONE dr=$dr"; cat $RES
