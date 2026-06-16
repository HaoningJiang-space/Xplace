#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh
conda activate /data/ziheng/wzh/conda_envs/orfs
export TMPDIR=/data/ziheng/wzh/tmp
cd /data/ziheng/wzh/oracle_gate/ariane133_synfree
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
echo ===PRE_START$(date +%T)===
OG_DB=db/1_placed.odb OG_MODE=pre OG_OUT=out OG_TAG=pre $OR -no_init -exit scripts/og_extract_sf.tcl > logs/extract_pre.log 2>&1
echo PRE_RC=$? $(date +%T)
echo ===GR_START$(date +%T)===
OG_DB=db/3_groute.odb OG_MODE=gr OG_OUT=out OG_TAG=gr $OR -no_init -exit scripts/og_extract_sf.tcl > logs/extract_gr.log 2>&1
echo GR_RC=$? $(date +%T)
echo ===ALLDONE===
