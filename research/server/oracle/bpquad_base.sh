#!/bin/bash
# 3rd-design base: extract bp_quad floorplan -> Xplace plain place -> route -> est/routed netslack -> divergence.
# No set -u. GPU 1 (GPU0=PPoPP). Decides if bp_quad is the needed HIGH-divergence design.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPD=/data/ziheng/wzh/xplace_dac/Xplace
conda activate /data/ziheng/wzh/conda_envs/orfs
$OR -no_init -exit $B/extract_bpquad_def.tcl > $B/extract_bpquad.log 2>&1
echo "DEF extracted: $(grep -c BPQUAD_DEF_DONE $B/extract_bpquad.log)"
conda activate /data/ziheng/wzh/conda_envs/xplace
export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
python main.py --custom_json $B/bpquad.json --load_from_raw True --detail_placement True --write_placement True --output_prefix bpquad_base --gpu 1 > $B/place_bpquad_base.log 2>&1
DEF=$(ls -t $XPD/result/*/output/bpquad_base_bsg_chip_dp.def 2>/dev/null | head -1)
hpwl=$(grep "After DP, HPWL" $B/place_bpquad_base.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
echo "PLACED base DEF=$DEF hpwl=$hpwl"
if [ -z "$DEF" ]; then echo "PLACE FAILED"; tail -15 $B/place_bpquad_base.log; echo BPQUAD_BASE_DONE; exit 1; fi
conda activate /data/ziheng/wzh/conda_envs/orfs
OUTD=$B/bpquad_base_out; mkdir -p $OUTD
export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=bpquad_base; cd $B
$OR -no_init -exit xplace_backend_bpquad.tcl > $B/backend_bpquad_base.log 2>&1
echo "ROUTED dplace_tns=$(grep DPLACE_TNS $B/backend_bpquad_base.log|awk '{print $2}') droute_tns=$(grep DROUTE_TNS $B/backend_bpquad_base.log|awk '{print $2}')"
PY=/data/ziheng/wzh/conda_envs/orfs/bin/python
echo "=== bp_quad DIVERGENCE (est vs routed) ==="
$PY $B/divergence.py $OUTD/bpquad_base_place_netslack.csv $OUTD/bpquad_base_netslack.csv 5000
echo "BPQUAD_BASE_DONE"
