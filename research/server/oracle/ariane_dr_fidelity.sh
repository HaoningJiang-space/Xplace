#!/bin/bash
# ariane DR+OpenRCX coupling fidelity test of the R29 fair-baseline arms (fairest/routed/union).
# Closes the GR-fidelity caveat ON THE GAIN-BEARING DESIGN: does route-aware union (GR -2454 >
# fairest -2735) survive detailed-route + coupling-aware extraction? Reuses fb_* DP DEFs (no
# re-placement). Layer-restricted DR (metal2-metal10) — the fix that unhung "Init gr pin query".
# No set -u. CPU-only. Sequential (each DR ~1-2h on ariane; concurrent would oversubscribe).
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
RES=$B/ariane_dr_fidelity_results.txt
echo "arm gr_tns dr_tns dr_wns" > $RES
conda activate /data/ziheng/wzh/conda_envs/orfs
for arm in fairest routed union; do
  DEF=$(ls -t $XPD/result/*/output/fb_${arm}_ariane_dp.def 2>/dev/null | head -1)
  if [ -z "$DEF" ]; then echo "MISSING DEF for $arm"; continue; fi
  OUTD=$B/ardr_$arm; mkdir -p $OUTD
  export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=fbdr_$arm; cd $B
  echo "=== START $arm DEF=$DEF $(date +%H:%M:%S) ==="
  $OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_ardr_$arm.log 2>&1
  grt=$(grep DROUTE_GR_TNS $B/backend_ardr_$arm.log|awk '{print $2}')
  drt=$(grep DROUTE_DR_TNS $B/backend_ardr_$arm.log|awk '{print $2}')
  drw=$(grep DROUTE_DR_WNS $B/backend_ardr_$arm.log|awk '{print $2}')
  echo "$arm $grt $drt $drw" >> $RES
  echo "DONE $arm gr=$grt dr=$drt $(date +%H:%M:%S)"
done
echo "ARIANE_DR_FIDELITY_DONE"; cat $RES
