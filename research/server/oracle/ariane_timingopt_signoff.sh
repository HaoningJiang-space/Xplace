#!/bin/bash
# SOTA head-to-head at SIGNOFF fidelity: Xplace's OWN --timing_opt (real GPUTimer path-based timing)
# + --use_cell_inflate (routability-grade) -> DR + OpenRCX coupling. Compare vs the route-aware union
# arm (R33: union DR-coupling TNS -823.7). fair-est is the academic-TDP baseline; --timing_opt is
# Xplace's own — the comparison that matters for #12. No set -u. Place GPU 1 (GPU0=PPoPP).
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
pref="infl_timingopt"
conda activate /data/ziheng/wzh/conda_envs/xplace
export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
python main.py --custom_json $B/ariane_timed.json --load_from_raw True --timing_opt True \
  --use_cell_inflate True --detail_placement True --write_placement True \
  --wire_resistance_per_micron 0.0036 --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
PLRC=$?
DEF=$(ls -t $XPD/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
echo "PLACED rc=$PLRC DEF=$DEF hpwl=$hpwl $(date +%H:%M:%S)"
if [ -z "$DEF" ]; then echo "PLACE FAILED tail:"; tail -20 $B/place_$pref.log; echo "TIMINGOPT_SIGNOFF_DONE"; exit 1; fi
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/infldr2_timingopt; mkdir -p $OUTD
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=infldr2_timingopt; cd $B
$OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_infldr2_timingopt.log 2>&1
grt=$(grep DROUTE_GR_TNS $B/backend_infldr2_timingopt.log|awk '{print $2}')
drt=$(grep DROUTE_DR_TNS $B/backend_infldr2_timingopt.log|awk '{print $2}')
drw=$(grep DROUTE_DR_WNS $B/backend_infldr2_timingopt.log|awk '{print $2}')
echo "timingopt $grt $drt $drw" >> $B/ariane_infl_dr_true_results.txt
echo "TIMINGOPT_SIGNOFF_DONE gr=$grt dr_coupling=$drt wns=$drw"