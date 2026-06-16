#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh
conda activate /data/ziheng/wzh/conda_envs/orfs
export TMPDIR=/data/ziheng/wzh/tmp
cd /data/ziheng/wzh/oracle_gate/ariane133_synfree
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
echo ===STEINER_START$(date +%T)===
OG_DB=db/3_groute.odb OG_MODE=pre OG_OUT=out OG_TAG=steiner $OR -no_init -exit scripts/og_extract_sf.tcl > logs/extract_steiner.log 2>&1
echo STEINER_RC=$? $(date +%T)
echo ===RUDY_START$(date +%T)===
OG_DB=db/3_groute.odb OG_OUT=out OG_TAG=grt $OR -no_init -exit scripts/og_rudy_sf.tcl > logs/rudy_grt.log 2>&1
echo RUDY_RC=$? $(date +%T)
echo ===ALLDONE===
