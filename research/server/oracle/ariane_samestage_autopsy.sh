#!/bin/bash
# MECHANISM AUTOPSY P3 (clean, user-refined backend): on a CELL-INFLATED (routability-grade) ariane
# placement, dump SAME-STAGE est (post-CTS/post-DP, pre-route) and routed (post-CTS, post-GR), then compute
# top-5%/10% Jaccard(est_postCTS, routed) = the ROUTING-ONLY reordering of the post-CTS critical set.
# Cell-inflated so GR converges (density-1.0 stalls at "GRT-0103 hard benchmark", R31). CPU-only. flock guard.
source ~/miniconda3/etc/profile.d/conda.sh
exec 200>/tmp/ariane_samestage.lock; flock -n 200 || { echo "ALREADY_RUNNING"; exit 9; }
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
# a cell-inflated (routability-grade, 0-DRC capable) ariane placement from R33
DEF=$(ls -t $XPD/result/*/output/infl_fairest_ariane_dp.def 2>/dev/null | head -1)
[ -n "$DEF" ] || { echo "FATAL no infl_fairest DEF"; exit 3; }
OUTD=$B/ariane_samestage2; mkdir -p $OUTD
echo "SAMESTAGE2_START DEF=$DEF $(date +%H:%M:%S)"
conda activate /data/ziheng/wzh/conda_envs/orfs
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=ss2; cd $B
$OR -no_init -exit xplace_backend_ariane_samestage.tcl > $B/backend_samestage2.log 2>&1
echo "BACKEND rc=$? done=$(grep -c SAMESTAGE_BACKEND_DONE $B/backend_samestage2.log) $(date +%H:%M:%S)"
grep -E "SAMESTAGE_EST_|SAMESTAGE_ROUTED_" $B/backend_samestage2.log
echo "=== P3 DECISIVE: Jaccard(est_postCTS, routed) = ROUTING-ONLY reordering ==="
echo "   (contrast: pre-CTS-est vs routed = 0.231 total; pre-CTS vs post-CTS = 0.000/0.168 CTS-alone)"
python3 $B/div_frac.py $OUTD/ss2_samestage_est_netslack.csv $OUTD/ss2_samestage_routed_netslack.csv
echo "ARIANE_SAMESTAGE2_DONE"
