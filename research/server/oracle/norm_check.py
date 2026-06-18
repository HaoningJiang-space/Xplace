# codex #5/#8 check: does the union top-K SET depend on the normalization scheme?
# Compares own-norm (current blend_crit.py) vs rank-percentile vs common-ns(raw) unions.
import csv
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
est=load('/tmp/normck/ar_est_metal5_netslack.csv')
routed=load('/tmp/normck/ar_base_netslack.csv')
nets=sorted(set(est)|set(routed))
def crit_pos(d): # criticality = max(0,-slack)
    return {n:max(0.0,-d.get(n,0.0)) for n in nets}
ce, cr = crit_pos(est), crit_pos(routed)
def ownnorm(c):
    m=max(c.values()) or 1.0
    return {n:v/m for n,v in c.items()}
def rankpct(c):
    order=sorted(nets, key=lambda n:c[n])
    N=len(order); return {n:i/(N-1) for i,n in enumerate(order)}
# three unions
import math
def topk_set(score, K):
    return set(sorted(nets, key=lambda n:score[n], reverse=True)[:K])
en,rn=ownnorm(ce),ownnorm(cr)
union_own ={n:max(en[n],rn[n]) for n in nets}
ep,rp=rankpct(ce),rankpct(cr)
union_rank={n:max(ep[n],rp[n]) for n in nets}
union_raw ={n:max(ce[n],cr[n]) for n in nets}   # common-ns (no per-file norm)
def jac(a,b): return len(a&b)/len(a|b) if (a|b) else 1.0
for K in (13000, int(0.10*len(nets))):
    so=topk_set(union_own,K); sr=topk_set(union_rank,K); sx=topk_set(union_raw,K)
    # also est-only and routed-only top-K for reference
    se=topk_set(en,K); srt=topk_set(rn,K)
    print(f"--- K={K} ({K*100//len(nets)}% of {len(nets)} nets) ---")
    print(f"  union_own vs union_rankpct  Jaccard = {jac(so,sr):.3f}")
    print(f"  union_own vs union_raw(ns)  Jaccard = {jac(so,sx):.3f}")
    print(f"  union_rankpct vs union_raw  Jaccard = {jac(sr,sx):.3f}")
    print(f"  [ref] est_topK vs routed_topK Jaccard = {jac(se,srt):.3f}  (the divergence-law metric)")
    print(f"  [ref] union_own vs est_topK   Jaccard = {jac(so,se):.3f}; union_own vs routed_topK = {jac(so,srt):.3f}")
