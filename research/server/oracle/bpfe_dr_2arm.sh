#!/bin/bash
# bp_fe DR+OpenRCX fidelity, FOCUSED on the 2 thesis-ranking-relevant arms (est_fair vs routed_k2).
# cold_k0 dropped: pathologically congested (70k+ DR violations, slow) and not the ranking question.
# Tests whether the GR ranking (est_fair better at GR) survives DR+coupling. No set -u. CPU-only.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
RES=$B/bpfe_dr_2arm_results.txt
echo "arm gr_tns dr_tns gr_wns dr_wns" > $RES
conda activate /data/ziheng/wzh/conda_envs/orfs
declare -A DEFS=(
  [est_fair]=$(ls $XPD/result/*/output/bpfe_est_bp_fe_top_dp.def | head -1)
  [routed_k2]=$(ls $XPD/result/*/output/bpfp_k2_bp_fe_top_dp.def | head -1)
)
for arm in est_fair routed_k2; do
  DEF=${DEFS[$arm]}
  OUTD=$B/bpfe_dr2_$arm; mkdir -p $OUTD
  export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$arm; cd $B
  echo "=== START $arm DEF=$DEF $(date +%H:%M:%S) ==="
  $OR -no_init -exit xplace_backend_bpfe_dr.tcl > $B/backend_bpfedr2_$arm.log 2>&1
  grt=$(grep BPFE_GR_TNS $B/backend_bpfedr2_$arm.log|awk '{print $2}')
  drt=$(grep BPFE_DR_TNS $B/backend_bpfedr2_$arm.log|awk '{print $2}')
  grw=$(grep BPFE_GR_WNS $B/backend_bpfedr2_$arm.log|awk '{print $2}')
  drw=$(grep BPFE_DR_WNS $B/backend_bpfedr2_$arm.log|awk '{print $2}')
  echo "$arm $grt $drt $grw $drw" >> $RES
  echo "DONE $arm gr=$grt dr=$drt $(date +%H:%M:%S)"
done
echo "BPFE_DR_2ARM_DONE"; cat $RES
