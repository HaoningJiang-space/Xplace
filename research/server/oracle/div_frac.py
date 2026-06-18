import csv,sys
def load(fn):
    d={}
    with open(fn) as f:
        r=csv.reader(f); next(r,None)
        for row in r:
            if len(row)<2: continue
            try: d[row[0]]=float(row[1])
            except: pass
    return d
def crit(d):
    neg={k:max(0.0,-v) for k,v in d.items()}
    mx=max(neg.values()) if neg else 1.0
    return {k:v/(mx or 1) for k,v in neg.items()}
def jac_frac(ca,cb,frac):
    n=int(len(ca)*frac)
    a=set([x[0] for x in sorted(ca.items(),key=lambda y:-y[1])[:n]])
    b=set([x[0] for x in sorted(cb.items(),key=lambda y:-y[1])[:n]])
    return len(a&b)/max(1,len(a|b)), n
est=crit(load(sys.argv[1])); routed=crit(load(sys.argv[2]))
for frac in [0.05,0.10]:
    j,n=jac_frac(est,routed,frac)
    print(f"  top-{int(frac*100)}% (K={n}): Jaccard={j:.3f}")
