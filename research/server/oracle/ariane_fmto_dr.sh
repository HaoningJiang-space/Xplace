#!/bin/bash
# Route ONE force-matched --timing_opt arm (chosen weight's DEF, $1) through the signoff DR backend
# (detailed_route + OpenRCX coupling, SPEF-correct). Compare DROUTE_DR_TNS vs union -823.7 (R33).
# Usage: bash ariane_fmto_dr.sh <DEF_path> <tag>.  No set -u. CPU-only.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
DEF=$1; TAG=$2
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/fmto_dr_$TAG; mkdir -p $OUTD
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$TAG; cd $B
echo "=== DR $TAG DEF=$DEF $(date +%H:%M:%S) ==="
$OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_fmto_$TAG.log 2>&1
grt=$(grep DROUTE_GR_TNS $B/backend_fmto_$TAG.log|awk '{print $2}')
drt=$(grep DROUTE_DR_TNS $B/backend_fmto_$TAG.log|awk '{print $2}')
drw=$(grep DROUTE_DR_WNS $B/backend_fmto_$TAG.log|awk '{print $2}')
viol=$(grep -iE "Completing 100%|number of violations" $B/backend_fmto_$TAG.log|tail -1)
echo "$TAG gr=$grt dr_coupling=$drt wns=$drw | $viol" | tee -a $B/ariane_fmto_dr_results.txt
echo "FMTO_DR_DONE $TAG"
