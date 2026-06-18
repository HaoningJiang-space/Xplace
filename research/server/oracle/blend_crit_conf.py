#!/usr/bin/env python3
# Confidence-weighted union (DIVERGENCE_LAW.md S4): c = est + (1-a)*max(0, routed-est),
# a = clamp(Spearman(est,routed crit), 0, 1) computed from the two pass-1 CSVs (oracle-free).
#  - a->1 (est & routed agree, e.g. bp_fe 0.97): c -> est  (ignore noisy routed; avoid raw-union harm)
#  - a->0 (disagree, e.g. ariane 0.19):          c -> max(est,routed) = raw union (full route-awareness)
# Writes worst_slack_ns = -c (the loader recovers c via max(0,-slack)/max_neg, matching blend_crit.py).
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
    return {n: max(0.0,-s)/mn for n,s in d.items()}
def spearman(ca, cb):
    keys=[k for k in ca if k in cb]
    a=[ca[k] for k in keys]; b=[cb[k] for k in keys]; n=len(a)
    if n<2: return 0.0
    def rank(x):
        order=sorted(range(len(x)), key=lambda i:x[i]); r=[0]*len(x)
        for i,o in enumerate(order): r[o]=i
        return r
    ra,rb=rank(a),rank(b); ma=sum(ra)/n; mb=sum(rb)/n
    cov=sum((ra[i]-ma)*(rb[i]-mb) for i in range(n))
    va=sum((ra[i]-ma)**2 for i in range(n))**0.5
    vb=sum((rb[i]-mb)**2 for i in range(n))**0.5
    return cov/(va*vb) if va*vb>0 else 0.0
est=load_crit(est_f); routed=load_crit(routed_f)
a=spearman(est,routed)
a=max(0.0, min(1.0, a))
nets=set(est)|set(routed)
with open(out_f,"w") as f:
    f.write("net,worst_slack_ns\n")
    for n in nets:
        e=est.get(n,0.0); r=routed.get(n,0.0)
        c=e + (1.0-a)*max(0.0, r-e)
        f.write("%s,%.6f\n"%(n, -c))
print("CONF-BLEND agreement(spearman)=%.4f weight_on_routed_excess=%.4f nets=%d -> %s"%(a,1.0-a,len(nets),out_f))
