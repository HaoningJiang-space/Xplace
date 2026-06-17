#!/bin/bash
# Re-run DR on the existing cell-inflate DEFs with the SPEF-fixed back-end (write_spef+read_spef),
# to get the TRUE DR+OpenRCX-coupling TNS (prior run reported stale GR timing). Concurrent. No set -u.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
conda activate /data/ziheng/wzh/conda_envs/orfs
declare -A PIDS
for arm in fairest routed union; do
  DEF=$(ls -t $XPD/result/*/output/infl_${arm}_ariane_dp.def 2>/dev/null | head -1)
  OUTD=$B/infldr2_$arm; mkdir -p $OUTD
  ( export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=infldr2_$arm; cd $B
    $OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_infldr2_$arm.log 2>&1 ) &
  PIDS[$arm]=$!
  echo "DR-LAUNCH $arm pid=${PIDS[$arm]} DEF=$DEF $(date +%H:%M:%S)"
done
for arm in fairest routed union; do wait ${PIDS[$arm]}; echo "DR-WAITED $arm $(date +%H:%M:%S)"; done
RES=$B/ariane_infl_dr_true_results.txt; echo "arm gr_tns dr_coupling_tns dr_wns" > $RES
for arm in fairest routed union; do
  grt=$(grep DROUTE_GR_TNS $B/backend_infldr2_$arm.log|awk '{print $2}')
  drt=$(grep DROUTE_DR_TNS $B/backend_infldr2_$arm.log|awk '{print $2}')
  drw=$(grep DROUTE_DR_WNS $B/backend_infldr2_$arm.log|awk '{print $2}')
  echo "$arm $grt $drt $drw" >> $RES
done
echo "ARIANE_INFL_DR_TRUE_DONE"; cat $RES
