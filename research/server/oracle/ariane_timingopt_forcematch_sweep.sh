#!/bin/bash
# Option-1 (SOTA_COMPARISON_DESIGN.md): force-match Xplace production --timing_opt DOWN to the union
# arm's HPWL (2.819e7) so it is iso-congestion / routable, for a clean placer-vs-placer #12 number.
# R34: --timing_opt default (0.05) over-packs -> HPWL 2.463e7 (DENSER than union 2.819e7) -> won't route.
# Lower --timing_init_weight => weaker pull => HPWL rises toward union. PLACE-ONLY sweep (GPU 1, cheap,
# does NOT contend with CPU DR routes). Records HPWL per weight; pick the one ~2.82e7 for the signoff DR.
# No set -u. GPU 1 only (GPU0=PPoPP).
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
XPD=/data/ziheng/wzh/xplace_dac/Xplace
RES=$B/ariane_timingopt_forcematch_hpwl.txt
echo "init_weight hpwl def" > $RES
conda activate /data/ziheng/wzh/conda_envs/xplace
export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
for w in 0.05 0.03 0.02 0.01 0.005; do
  pref="fmto_w${w}"
  python main.py --custom_json $B/ariane_timed.json --load_from_raw True --timing_opt True \
    --use_cell_inflate True --detail_placement True --write_placement True \
    --timing_init_weight $w --wire_resistance_per_micron 0.0036 \
    --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPD/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  echo "$w $hpwl $DEF" >> $RES
  echo "DONE w=$w hpwl=$hpwl $(date +%H:%M:%S)"
done
echo "FORCEMATCH_SWEEP_DONE"; cat $RES
