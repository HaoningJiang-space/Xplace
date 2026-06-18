import sys
est_f, routed_f, out_f = sys.argv[1], sys.argv[2], sys.argv[3]
def load_crit(fn):
    d={}; mn=0.0
    with open(fn) as f:
        for i,line in enumerate(f):
            if i==0: continue
            p=line.strip().split(",")
            if len(p)<2: continue
            try: s=float(p[1])
            except: continue
            d[p[0]]=s
            if -s>mn: mn=-s
    if mn<=0: mn=1.0
    return {n: max(0.0,-s)/mn for n,s in d.items()}   # normalized criticality in [0,1]
est=load_crit(est_f); routed=load_crit(routed_f)
nets=set(est)|set(routed)
with open(out_f,"w") as f:
    f.write("net,worst_slack_ns\n")
    for n in nets:
        c=max(est.get(n,0.0), routed.get(n,0.0))   # critical if EITHER source ranks it high
        f.write("%s,%.6f\n"%(n, -c))               # builder: crit = max(0,-slack)/max -> recovers c
print("BLENDED(normalized-max) %d nets -> %s"%(len(nets),out_f))
