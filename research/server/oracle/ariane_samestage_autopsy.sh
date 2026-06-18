#!/bin/bash
# MECHANISM AUTOPSY step 1 driver (user-directed): run the same-stage backend on a base ariane placement,
# then compute top-5%/10% Jaccard for (pre-CTS est vs routed), (post-CTS est vs routed), (pre vs post-CTS).
# Decomposes the est-vs-routed "divergence" into CTS-stage vs genuine-routing contributions. CPU-only,
# no GPU (won't collide with the concurrent bp_quad). No set -u. flock single-instance guard.
source ~/miniconda3/etc/profile.d/conda.sh
exec 200>/tmp/ariane_samestage.lock; flock -n 200 || { echo "ALREADY_RUNNING"; exit 9; }
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
# a base (no-timing) ariane placement DEF (density-1.0; GR completes for the criticality dump even if dense)
DEF=$(ls -t $XPD/result/*/output/dms_base_s0_ariane_dp.def 2>/dev/null | head -1)
[ -n "$DEF" ] || { echo "FATAL no base DEF"; exit 3; }
OUTD=$B/ariane_samestage; mkdir -p $OUTD
echo "SAMESTAGE_START DEF=$DEF $(date +%H:%M:%S)"
conda activate /data/ziheng/wzh/conda_envs/orfs
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=ss; cd $B
$OR -no_init -exit xplace_backend_ariane_samestage.tcl > $B/backend_samestage.log 2>&1
echo "BACKEND rc=$? done=$(grep -c BACKEND_SAMESTAGE_DONE $B/backend_samestage.log) $(date +%H:%M:%S)"
grep -E "PRECTS_|POSTCTS_|ROUTED_" $B/backend_samestage.log
# --- Jaccard decomposition (div_frac.py: top-5%/10% set overlap) ---
echo "=== Jaccard(est_PRE-CTS, routed) [the current divergence metric] ==="
python3 $B/div_frac.py $OUTD/ss_est_prects.csv $OUTD/ss_routed.csv
echo "=== Jaccard(est_POST-CTS, routed) [routing-only reordering] ==="
python3 $B/div_frac.py $OUTD/ss_est_postcts.csv $OUTD/ss_routed.csv
echo "=== Jaccard(est_PRE-CTS, est_POST-CTS) [CTS-alone reordering] ==="
python3 $B/div_frac.py $OUTD/ss_est_prects.csv $OUTD/ss_est_postcts.csv
echo "ARIANE_SAMESTAGE_AUTOPSY_DONE"
