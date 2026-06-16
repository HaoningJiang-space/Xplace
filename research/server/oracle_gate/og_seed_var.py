#!/usr/bin/env python3
# og_seed_var.py : route-seed variance of per-arc routed-RC / residual.
# Compares post_seed*_arc.csv against pre_arc.csv (same placement).
# For each arc: residual_s = wire_cap_post_seed - wire_cap_pre.
# Reports cross-seed std of wire_cap and of residual vs the across-arc spread,
# to judge: placement-driven (stable across seeds) vs seed noise.
import sys, os, glob
import numpy as np, pandas as pd
OUT=sys.argv[1] if len(sys.argv)>1 else "."
def p(x): return os.path.join(OUT,x)

pre=pd.read_csv(p("pre_arc.csv"))[["net","driver","sink","wire_cap_fF"]].rename(columns={"wire_cap_fF":"wc_pre"})
seed_files=sorted(glob.glob(p("post_seed*_arc.csv")))
print(f"[seeds] files={[os.path.basename(f) for f in seed_files]}")
if len(seed_files)<2:
    print("need >=2 seed files"); sys.exit(0)
key=["net","driver","sink"]
df=pre.copy()
seedcols=[]
for f in seed_files:
    tag=os.path.basename(f).replace("_arc.csv","")
    s=pd.read_csv(f)[key+["wire_cap_fF","elmore_max_ps"]].rename(
        columns={"wire_cap_fF":f"wc_{tag}","elmore_max_ps":f"elm_{tag}"})
    df=df.merge(s,on=key,how="inner"); seedcols.append(tag)
print(f"[seeds] common arcs across all seeds = {len(df)}")

wc_cols=[f"wc_{t}" for t in seedcols]
elm_cols=[f"elm_{t}" for t in seedcols]
W=df[wc_cols].values.astype(float)
df["wc_mean"]=W.mean(1); df["wc_seedstd"]=W.std(1,ddof=1)
df["resid_mean"]=df["wc_mean"]-df["wc_pre"]
# per-arc residual across seeds
R=W - df["wc_pre"].values[:,None]
df["resid_seedstd"]=R.std(1,ddof=1)

# Variance decomposition: across-arc spread of mean residual (signal) vs mean per-arc seed std (noise)
between_arc=np.nanstd(df["resid_mean"].values)         # placement-driven spread of residual
within_seed=np.nanmean(df["resid_seedstd"].values)     # avg seed noise per arc
icc = between_arc**2/(between_arc**2+within_seed**2+1e-30)
print("\n===== ROUTE-SEED VARIANCE of residual (routed_wc - steiner_wc) =====")
print(f"between-arc std of mean residual (placement signal) = {between_arc:.4f} fF")
print(f"within-arc std across seeds (seed noise, avg)        = {within_seed:.4f} fF")
print(f"signal-to-noise (between/within)                     = {between_arc/(within_seed+1e-30):.3f}")
print(f"approx ICC = signal_var/(signal_var+noise_var)       = {icc:.4f}")
# relative seed variability of wire cap itself
relcv=(df["wc_seedstd"]/(df["wc_mean"].abs()+1e-30))
print(f"median per-arc wire_cap CV across seeds              = {relcv.median():.4%}")
print(f"mean   per-arc wire_cap CV across seeds              = {relcv.mean():.4%}")

# correlation of residual rankings between seed pairs (is residual stable?)
from scipy.stats import spearmanr
print("\npairwise Spearman of per-arc residual across seeds:")
rr=[]
for i in range(len(seedcols)):
    for j in range(i+1,len(seedcols)):
        a=W[:,i]-df["wc_pre"].values; b=W[:,j]-df["wc_pre"].values
        msk=np.isfinite(a)&np.isfinite(b)
        rho,_=spearmanr(a[msk],b[msk]); rr.append(rho)
        print(f"  {seedcols[i]} vs {seedcols[j]}: rho={rho:.4f}")
if rr: print(f"  mean pairwise rho = {np.mean(rr):.4f}  -> high => residual is placement-driven, not seed noise")
df.to_csv(p("seed_variance.csv"),index=False)
print(f"\n[wrote] {p('seed_variance.csv')}")
