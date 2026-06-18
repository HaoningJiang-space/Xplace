import csv, sys
def load(fn):
    d={}
    with open(fn) as f:
        r=csv.reader(f)
        next(r,None)
        for row in r:
            if len(row)<2: continue
            try: d[row[0]]=float(row[1])
            except: pass
    return d
def crit(d):
    # normalized negative slack in [0,1]
    mn=min([v for v in d.values()]+[0.0])
    neg={k:max(0.0,-v) for k,v in d.items()}
    mx=max(neg.values()) if neg else 1.0
    if mx<=0: mx=1.0
    return {k:v/mx for k,v in neg.items()}
def topk_set(c,k):
    return set([x[0] for x in sorted(c.items(),key=lambda y:-y[1])[:k]])
def jaccard(a,b):
    return len(a&b)/max(1,len(a|b))
def spearman(ca,cb):
    keys=[k for k in ca if k in cb]
    import statistics
    a=[ca[k] for k in keys]; b=[cb[k] for k in keys]
    def rank(x):
        order=sorted(range(len(x)),key=lambda i:x[i]); r=[0]*len(x)
        for i,o in enumerate(order): r[o]=i
        return r
    ra,rb=rank(a),rank(b); n=len(a)
    if n<2: return float('nan')
    ma=sum(ra)/n; mb=sum(rb)/n
    cov=sum((ra[i]-ma)*(rb[i]-mb) for i in range(n))
    va=sum((ra[i]-ma)**2 for i in range(n))**0.5
    vb=sum((rb[i]-mb)**2 for i in range(n))**0.5
    return cov/(va*vb) if va*vb>0 else float('nan')
est=crit(load(sys.argv[1])); routed=crit(load(sys.argv[2])); K=int(sys.argv[3])
print(f"  nets est={len(est)} routed={len(routed)} common={len(set(est)&set(routed))}")
print(f"  Spearman(est,routed crit) = {spearman(est,routed):.4f}")
for k in [K]:
    je=topk_set(est,k); jr=topk_set(routed,k)
    print(f"  top-{k} Jaccard(est,routed) = {jaccard(je,jr):.4f}  (routed-only nets not in est top-k: {len(jr-je)})")
