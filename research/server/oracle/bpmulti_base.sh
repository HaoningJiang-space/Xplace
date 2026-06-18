#!/bin/bash
# 3rd-design base: extract bp_multi floorplan -> Xplace plain place -> route -> est/routed netslack -> divergence.
# No set -u. GPU 1 (GPU0=PPoPP). Decides if bp_multi is the needed HIGH-divergence design.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
conda activate /data/ziheng/wzh/conda_envs/orfs
$OR -no_init -exit $B/extract_bpmulti_def.tcl > $B/extract_bpmulti.log 2>&1
echo "DEF extracted: $(grep -c BPMULTI_DEF_DONE $B/extract_bpmulti.log)"
conda activate /data/ziheng/wzh/conda_envs/xplace
export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
python main.py --custom_json $B/bpmulti.json --load_from_raw True --detail_placement True --write_placement True --output_prefix bpmulti_base --gpu 1 > $B/place_bpmulti_base.log 2>&1
DEF=$(ls -t $XPD/result/*/output/bpmulti_base_bp_multi_top_dp.def 2>/dev/null | head -1)
hpwl=$(grep "After DP, HPWL" $B/place_bpmulti_base.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
echo "PLACED base DEF=$DEF hpwl=$hpwl"
if [ -z "$DEF" ]; then echo "PLACE FAILED"; tail -15 $B/place_bpmulti_base.log; echo BPMULTI_BASE_DONE; exit 1; fi
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/bpmulti_base_out; mkdir -p $OUTD
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=bpmulti_base; cd $B
$OR -no_init -exit xplace_backend_bpmulti.tcl > $B/backend_bpmulti_base.log 2>&1
echo "ROUTED dplace_tns=$(grep DPLACE_TNS $B/backend_bpmulti_base.log|awk '{print $2}') droute_tns=$(grep DROUTE_TNS $B/backend_bpmulti_base.log|awk '{print $2}')"
PY=/data/ziheng/wzh/conda_envs/orfs/bin/python
echo "=== bp_multi DIVERGENCE (est vs routed) ==="
$PY $B/divergence.py $OUTD/bpmulti_base_place_netslack.csv $OUTD/bpmulti_base_netslack.csv 5000
echo "BPMULTI_BASE_DONE"
