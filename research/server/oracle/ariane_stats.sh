#!/bin/bash
# STATISTICAL test (user: "感觉是调参数，有没有概率") — fixed frac 0.3, fanout_norm, matched force.
# 3 arms x K seeds: est / union / shuffled-null. Reports per-arm droute_TNS distribution. Decisive
# comparison = union vs SHUFFLED (same frac/force/cardinality/fanout, random nets): union<<shuffled =>
# criticality is real; union~shuffled => geometry/force, frac-choice irrelevant. No set -u. GPU 1.
FRAC=0.3; SEEDS="0 1 2 3 4"
source ~/miniconda3/etc/profile.d/conda.sh
B=/data/ziheng/wzh/bridge; OR=/data/ziheng/wzh/conda_envs/orfs/bin/openroad; XPD=/data/ziheng/wzh/xplace_dac/Xplace
PY=/data/ziheng/wzh/conda_envs/orfs/bin/python
EST=$B/ar_est_metal5_netslack.csv; UNION=$B/ar_union_metal5.csv
RES=$B/ariane_stats_results.txt; echo "arm seed hpwl droute_tns" > $RES
run () {
  arm=$1; csv=$2; seed=$3; pref="st_${arm}_s${seed}"
  conda activate /data/ziheng/wzh/conda_envs/xplace
  export PATH=/usr/local/cuda-11.7/bin:$PATH; export PYTHONPATH=$XPD:$PYTHONPATH; cd $XPD
  python main.py --custom_json $B/ariane.json --load_from_raw True --detail_placement True --write_placement True \
    --oracle_timing_file $csv --oracle_timing_scale 1.0 --oracle_topfrac $FRAC --timing_force_frac $FRAC \
    --oracle_pin_weight_mode fanout_norm --seed $seed --output_prefix $pref --gpu 1 > $B/place_$pref.log 2>&1
  DEF=$(ls -t $XPD/result/*/output/${pref}_ariane_dp.def 2>/dev/null | head -1)
  hpwl=$(grep "After DP, HPWL" $B/place_$pref.log | tail -1 | grep -oE "[0-9.]+E[+][0-9]+")
  conda activate /data/ziheng/wzh/conda_envs/orfs
  OUTD=$B/${pref}_out; mkdir -p $OUTD; export XP_DEF=$DEF XP_OUT=$OUTD XP_TAG=$pref; cd $B
  $OR -no_init -exit xplace_backend_ariane.tcl > $B/backend_$pref.log 2>&1
  dr=$(grep DROUTE_TNS $B/backend_$pref.log|awk '{print $2}')
  echo "$arm $seed $hpwl $dr" >> $RES; echo "DONE $arm s$seed dr=$dr"
}
for s in $SEEDS; do
  $PY $B/shuffle_crit.py $UNION $B/ar_shuffled_s$s.csv $s
  run est      $EST                  $s
  run union    $UNION                $s
  run shuffled $B/ar_shuffled_s$s.csv $s
done
echo "STATS_DONE"; cat $RES
$PY - <<'PYSTATS'
import statistics as st
d={}
for line in open("/data/ziheng/wzh/bridge/ariane_stats_results.txt"):
    p=line.split()
    if len(p)<4 or p[0]=="arm": continue
    try: d.setdefault(p[0],[]).append(float(p[3]))
    except: pass
for a in ("est","union","shuffled"):
    v=d.get(a,[]); 
    if v: print("%-9s n=%d mean=%.1f std=%.1f  vals=%s"%(a,len(v),st.mean(v),(st.pstdev(v) if len(v)>1 else 0),["%.0f"%x for x in v]))
if "union" in d and "est" in d:
    pe=[u-e for u,e in zip(d["union"],d["est"])]; print("paired union-est:   mean=%.1f (neg=better) vals=%s"%(st.mean(pe),["%.0f"%x for x in pe]))
if "union" in d and "shuffled" in d:
    ps=[u-s for u,s in zip(d["union"],d["shuffled"])]; print("paired union-shuf:  mean=%.1f (neg=union better=criticality real) vals=%s"%(st.mean(ps),["%.0f"%x for x in ps]))
PYSTATS
