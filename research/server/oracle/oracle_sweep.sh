#!/bin/bash
# Oracle-timing scale sweep on aes: place (Xplace) + back-end (GR) per scale.
# scale 0 = plain baseline. Records D_place TNS, D_route TNS, total wire cap, HPWL.
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge
OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad
XPDIR=/data/ziheng/wzh/xplace_dac/Xplace
RES=$B/sweep_results.txt
echo "scale  hpwl  dplace_tns  droute_tns  wirecap_fF" > $RES

for sc in 0 0.1 0.3 1.0; do
  pref="sw_${sc}"
  # --- place ---
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH
  export PYTHONPATH=$XPDIR:$PYTHONPATH
  cd $XPDIR
  if [ "$sc" == "0" ]; then
    python main.py --custom_json $B/aes.json --load_from_raw True --detail_placement True \
      --write_placement True --output_prefix $pref --gpu 0 > $B/sweep_place_$pref.log 2>&1
  else
    python main.py --custom_json $B/aes.json --load_from_raw True --detail_placement True \
      --write_placement True --oracle_timing_file $B/backend_aes/aes_base_netslack.csv \
      --oracle_timing_scale $sc --output_prefix $pref --gpu 0 > $B/sweep_place_$pref.log 2>&1
  fi
  DEF=$(ls -t $XPDIR/result/*/output/${pref}_aes_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/sweep_place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  # --- back-end ---
  conda activate /data/ziheng/wzh/conda_envs/orfs
  export XP_DEF=$DEF XP_OUT=$B/sweep_$pref XP_TAG=$pref XP_PERIOD=0.82
  cd $B
  $OR -no_init -exit xplace_backend_gr.tcl > $B/sweep_backend_$pref.log 2>&1
  dp=$(grep DPLACE_TNS $B/sweep_backend_$pref.log | awk '{print $2}')
  dr=$(grep DROUTE_TNS $B/sweep_backend_$pref.log | awk '{print $2}')
  wc=$(grep TOTAL_WIRE_CAP_fF $B/sweep_backend_$pref.log | awk '{print $2}')
  echo "$sc  $hpwl  $dp  $dr  $wc" >> $RES
  echo "DONE scale=$sc"
done
echo "SWEEP_DONE"
cat $RES
