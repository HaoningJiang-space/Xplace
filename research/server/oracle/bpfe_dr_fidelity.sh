#!/bin/bash
# bp_fe DR+OpenRCX fidelity probe: route 3 existing placement arms through detailed_route +
# coupling-aware extraction; compare GR-estimate TNS vs DR+coupling TNS (delta = fidelity gap).
# Arms reuse already-produced DP DEFs (no re-placement). No set -u. OpenROAD is CPU-only.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
RES=$B/bpfe_dr_fidelity_results.txt
echo "arm gr_tns dr_tns gr_wns dr_wns" > $RES
conda activate /data/ziheng/wzh/conda_envs/orfs
declare -A DEFS=(
  [cold_k0]=$(ls $XPD/result/*/output/bpfp_k0_bp_fe_top_dp.def | head -1)
  [est_fair]=$(ls $XPD/result/*/output/bpfe_est_bp_fe_top_dp.def | head -1)
  [routed_k2]=$(ls $XPD/result/*/output/bpfp_k2_bp_fe_top_dp.def | head -1)
)
for arm in cold_k0 est_fair routed_k2; do
  DEF=${DEFS[$arm]}
  OUTD=$B/bpfe_dr_$arm; mkdir -p $OUTD
  export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$arm; cd $B
  echo "=== START $arm DEF=$DEF ==="
  $OR -no_init -exit xplace_backend_bpfe_dr.tcl > $B/backend_bpfedr_$arm.log 2>&1
  grt=$(grep BPFE_GR_TNS $B/backend_bpfedr_$arm.log|awk '{print $2}')
  drt=$(grep BPFE_DR_TNS $B/backend_bpfedr_$arm.log|awk '{print $2}')
  grw=$(grep BPFE_GR_WNS $B/backend_bpfedr_$arm.log|awk '{print $2}')
  drw=$(grep BPFE_DR_WNS $B/backend_bpfedr_$arm.log|awk '{print $2}')
  echo "$arm $grt $drt $grw $drw" >> $RES
  echo "DONE $arm gr=$grt dr=$drt"
done
echo "BPFE_DR_FIDELITY_DONE"; cat $RES
