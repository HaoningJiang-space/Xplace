#!/bin/bash
# Re-route the blend & est ariane placements with detailed-route + OpenRCX (coupling). R24 flaw 3.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate /data/ziheng/wzh/conda_envs/orfs
B=/data/ziheng/wzh/bridge; OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad; XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
RES=$B/ariane_dr_results.txt; echo "arm droute_gr_tns droute_dr_tns" > $RES
declare -A DEFS=( [blend]=$(ls -t $XPDIR/result/*/output/bl_ariane_ariane_dp.def|head -1) [est]=$(ls -t $XPDIR/result/*/output/ms_est_s0_ariane_dp.def|head -1) )
for arm in blend est; do
  OUTD=$B/dr_$arm; mkdir -p $OUTD
  export XP_DEF=${DEFS[$arm]} XP_OUT=$OUTD XP_TAG=dr_$arm; cd $B
  $OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_dr_$arm.log 2>&1
  gr=$(grep DROUTE_GR_TNS $B/backend_dr_$arm.log|awk '{print $2}')
  dr=$(grep DROUTE_DR_TNS $B/backend_dr_$arm.log|tail -1|awk '{print $2}')
  echo "$arm $gr $dr" >> $RES; echo "DONE dr_$arm gr=$gr dr=$dr"
done
echo "ARIANE_DR_DONE"; cat $RES
