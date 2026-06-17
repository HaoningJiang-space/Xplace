#!/bin/bash
# Routable-density test: re-place ariane UNION arm at target_density 0.7 (vs 1.0 default which gives
# ~580k DR violations, non-converging). Place -> GR -> DR; report first-pass violation count (DRT-0199)
# to decide if 0.7 routes (ORFS golden ariane = 83k initial, converges). No set -u. GPU 1 for place.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
TD=${1:-0.7}
pref="ardens_union_td${TD}"
conda activate /data/ziheng/wzh/conda_envs/xplace
export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True --write_placement True \
  --oracle_timing_file $B/ar_fair_union.csv --oracle_timing_scale 1.0 --oracle_topk 13000 \
  --target_density $TD --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
DEF=$(ls -t $XPD/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
echo "PLACED td=$TD DEF=$DEF hpwl=$hpwl"
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/ardens_$TD; mkdir -p $OUTD
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
$OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_$pref.log 2>&1 &
ORPID=$!
echo "DR launched pid=$ORPID td=$TD"
for i in $(seq 1 40); do   # up to ~20 min watching first-pass
  sleep 30
  if ! kill -0 $ORPID 2>/dev/null; then echo "DR EXITED (full done) at check $i"; break; fi
  v=$(grep -E "Number of violations" $B/backend_$pref.log 2>/dev/null | tail -1)
  c=$(grep -E "Completing [0-9]+%" $B/backend_$pref.log 2>/dev/null | tail -1)
  if [ -n "$v" ]; then echo "check $i: FIRST-PASS DONE -> $v ; killing to decide"; kill -9 $ORPID 2>/dev/null; break; fi
  echo "check $i: $c"
done
echo "DENSITY_TEST_DONE td=$TD"
grep -E "DROUTE_GR_TNS" $B/backend_$pref.log 2>/dev/null
