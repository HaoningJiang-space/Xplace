#!/bin/bash
# Routability-INTEGRATED test (R31 next-phase): place ariane UNION arm with --use_cell_inflate True
# (Xplace routability mode: periodic GGR -> cell inflation) + union criticality, so the placement is
# routability-grade. Then DR through the fixed (layer+GR-adjusted) back-end; watch first-pass DRC
# violations. GATE: if violations drop to ~ORFS-level (~83k, converging) the fidelity path works ->
# run all 3 arms. No set -u. Place on GPU 1 (GPU0=PPoPP). DR is CPU.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
pref="arinfl_union"
conda activate /data/ziheng/wzh/conda_envs/xplace
export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True --write_placement True \
  --use_cell_inflate True \
  --oracle_timing_file $B/ar_fair_union.csv --oracle_timing_scale 1.0 --oracle_topk 13000 \
  --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
PLRC=$?
DEF=$(ls -t $XPD/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
echo "PLACED rc=$PLRC DEF=$DEF hpwl=$hpwl"
if [ -z "$DEF" ]; then echo "PLACE FAILED — tail:"; tail -15 $B/place_$pref.log; echo "INFLATE_TEST_DONE"; exit 1; fi
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/arinfl_out; mkdir -p $OUTD
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
$OR -no_init -exit xplace_backend_ariane_dr.tcl > $B/backend_$pref.log 2>&1 &
ORPID=$!
echo "DR launched pid=$ORPID"
for i in $(seq 1 60); do  # up to ~30 min
  sleep 30
  if ! kill -0 $ORPID 2>/dev/null; then echo "DR EXITED (FULL DONE) at check $i $(date +%H:%M:%S)"; break; fi
  v=$(grep -E "Number of violations" $B/backend_$pref.log 2>/dev/null | tail -1)
  c=$(grep -E "Completing [0-9]+%" $B/backend_$pref.log 2>/dev/null | tail -1)
  if [ -n "$v" ]; then echo "check $i: FIRST-PASS -> $v"; kill -9 $ORPID 2>/dev/null; break; fi
  echo "check $i: $c"
done
echo "INFLATE_TEST_DONE"; grep -E "DROUTE_GR_TNS" $B/backend_$pref.log 2>/dev/null
