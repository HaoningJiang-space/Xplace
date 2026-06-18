#!/bin/bash
# P3: run the same-stage backend on an existing ariane base DEF, then compute same-stage Jaccard.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
PY=/data/ziheng/wzh/conda_envs/orfs/bin/python
DEF=$(ls -t $B/ar_base_ariane_dp.def 2>/dev/null | head -1)
[ -z "$DEF" ] && DEF=$(ls -t /data/ziheng/wzh/xplace_dac/Xplace/result/*/output/*ariane_dp.def 2>/dev/null | head -1)
echo "DEF=$DEF"
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/ariane_samestage_out; mkdir -p $OUTD
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=ss; cd $B
$OR -no_init -exit xplace_backend_ariane_samestage.tcl > $B/backend_ariane_samestage.log 2>&1
grep -E "SAMESTAGE_EST_TNS|SAMESTAGE_ROUTED_TNS|SAMESTAGE_BACKEND_DONE" $B/backend_ariane_samestage.log
echo "=== SAME-STAGE divergence (est-postCTS vs routed, top-10%) ==="
$PY $B/div_frac.py $OUTD/ss_samestage_est_netslack.csv $OUTD/ss_samestage_routed_netslack.csv
echo "=== vs the MIXED-STAGE divergence (current, est-preCTS) ==="
$PY $B/div_frac.py $B/ar_backend/ar_base_place_netslack.csv $B/ar_backend/ar_base_netslack.csv
echo "ARIANE_SAMESTAGE_DONE"
