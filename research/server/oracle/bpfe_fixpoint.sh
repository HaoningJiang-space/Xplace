#!/bin/bash
# Multi-design (case 2): fixed-point iteration on bp_fe_top (Black Parrot front-end, NanGate45,
# fixed SRAM macros). iter0 = plain placement cold start (no timing); iter k>=1 uses the PREVIOUS
# route's routed criticality. Tests if R19 (online route-aware recovers headroom) GENERALIZES.
# No set -u. GPU 1.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
RES=$B/bpfe_fixpoint_results.txt
echo "iter ns_source hpwl droute_tns wirecap_fF" > $RES
NS=""   # iter0 cold: no timing
for k in 0 1 2 3; do
  pref="bpfp_k${k}"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPDIR:$PYTHONPATH; cd $XPDIR
  EXTRA=""
  if [ -n "$NS" ]; then EXTRA="--oracle_timing_file $NS --oracle_timing_scale 1.0 --oracle_topk 13000"; fi
  python main.py --custom_json $B/bpfe.json --load_from_raw True --detail_placement True \
    --write_placement True $EXTRA --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPDIR/result/*/output/${pref}_bp_fe_top_dp.def 2>/dev/null | head -1)
  if [ -z "$DEF" ]; then DEF=$(ls -t $XPDIR/result/*/output/${pref}_*_dp.def 2>/dev/null | head -1); fi
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  OUTD=$B/bpfp_$pref; mkdir -p $OUTD
  export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_bpfe.tcl > $B/backend_$pref.log 2>&1
  dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}')
  wc=$(grep TOTAL_WIRE_CAP $B/backend_$pref.log|awk '{print $2}')
  src="cold"; if [ -n "$NS" ]; then src=$(basename $NS); fi
  echo "$k $src $hpwl $dr $wc" >> $RES
  echo "DONE $pref dr=$dr (ns=$src)"
  NEWNS=$OUTD/${pref}_netslack.csv
  if [ -f "$NEWNS" ]; then NS=$NEWNS; else echo "WARN no netslack from $pref"; break; fi
done
echo "BPFE_FIXPOINT_DONE"; cat $RES
