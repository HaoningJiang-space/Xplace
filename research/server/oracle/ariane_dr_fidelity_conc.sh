#!/bin/bash
# ariane DR+OpenRCX coupling fidelity (CONCURRENT): route fb_fairest/routed/union DP DEFs through
# layer-restricted detailed_route + coupling extraction, in parallel (saves wall-clock vs sequential).
# Tests whether route-aware union (GR -2454 > fairest -2735) survives DR+coupling on the gain design.
# No set -u. CPU-only. ~3x16 threads on 52 cores = mild oversubscription, acceptable.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
conda activate /data/ziheng/wzh/conda_envs/orfs
declare -A PIDS
for arm in fairest routed union; do
  DEF=$(ls -t $XPD/result/*/output/fb_${arm}_ariane_dp.def 2>/dev/null | head -1)
  OUTD=$B/ardr_$arm; mkdir -p $OUTD
  ( export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=fbdr_$arm; cd $B
    $OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_ardr_$arm.log 2>&1 ) &
  PIDS[$arm]=$!
  echo "LAUNCH $arm pid=${PIDS[$arm]} DEF=$DEF $(date +%H:%M:%S)"
done
for arm in fairest routed union; do wait ${PIDS[$arm]}; echo "WAITED $arm $(date +%H:%M:%S)"; done
RES=$B/ariane_dr_fidelity_results.txt; echo "arm gr_tns dr_tns dr_wns" > $RES
for arm in fairest routed union; do
  grt=$(grep DROUTE_GR_TNS $B/backend_ardr_$arm.log|awk '{print $2}')
  drt=$(grep DROUTE_DR_TNS $B/backend_ardr_$arm.log|awk '{print $2}')
  drw=$(grep DROUTE_DR_WNS $B/backend_ardr_$arm.log|awk '{print $2}')
  echo "$arm $grt $drt $drw" >> $RES
done
echo "ARIANE_DR_FIDELITY_DONE"; cat $RES
