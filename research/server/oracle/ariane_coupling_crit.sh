#!/bin/bash
# Run the coupling-criticality autopsy on the cell-inflated infl_fairest placement, then Jaccard the
# post-CTS est vs the DR+OpenRCX coupling-routed criticality. Closes whether COUPLING (the part GR misses)
# reorders the critical set more than GR did (R40: GR vs post-CTS-est = 0.982). CPU-only. flock guard.
source ~/miniconda3/etc/profile.d/conda.sh
exec 200>/tmp/ariane_coupling_crit.lock; flock -n 200 || { echo "ALREADY_RUNNING"; exit 9; }
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
DEF=$(ls -t $XPD/result/*/output/infl_fairest_ariane_dp.def 2>/dev/null | head -1)
[ -n "$DEF" ] || { echo "FATAL no infl_fairest DEF"; exit 3; }
OUTD=$B/ariane_coupcrit; mkdir -p $OUTD
echo "COUPCRIT_START DEF=$DEF $(date +%H:%M:%S)"
conda activate /data/ziheng/wzh/conda_envs/orfs
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=cc; cd $B
$OR -no_init -exit xplace_backend_ariane_coupling_crit.tcl > $B/backend_coupcrit.log 2>&1
echo "BACKEND rc=$? done=$(grep -c BACKEND_COUPLING_CRIT_DONE $B/backend_coupcrit.log) drt_fail=$(grep -c DRT_FAIL $B/backend_coupcrit.log) $(date +%H:%M:%S)"
grep -E "CC_EST_|CC_COUPLING_|Number of violations" $B/backend_coupcrit.log | tail -5
echo "=== Jaccard(post-CTS-est, COUPLING-routed) — vs R40 GR-routed 0.982 ==="
python3 $B/div_frac.py $OUTD/cc_est.csv $OUTD/cc_coupling.csv
echo "ARIANE_COUPCRIT_DONE"
