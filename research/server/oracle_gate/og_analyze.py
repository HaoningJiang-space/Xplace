#!/usr/bin/env python3
# og_analyze.py : Gate A residual-beyond-RUDY analysis + oracle timing delta.
# Inputs (in OG_OUT): pre_arc.csv post_arc.csv pre_rudy.csv (post_rudy optional),
#   pre_wirelen.rpt post_wirelen.rpt, pre_wns_tns.txt post_wns_tns.txt
# Usage: og_analyze.py <OUT_DIR>
import sys, os, re, math
import numpy as np, pandas as pd
from scipy import stats

OUT = sys.argv[1] if len(sys.argv)>1 else "."
def p(x): return os.path.join(OUT,x)

def load_wirelen(fn):
    if not os.path.exists(fn): return pd.DataFrame(columns=["net","routed_len_um","hpwl_um"])
    return pd.read_csv(fn)

pre = pd.read_csv(p("pre_arc.csv"))
post= pd.read_csv(p("post_arc.csv"))
key=["net","driver","sink"]
m=pre.merge(post,on=key,suffixes=("_pre","_post"))
print(f"[merge] pre_arcs={len(pre)} post_arcs={len(post)} matched={len(m)}")

# residual RC = routed - steiner (use net wire cap and elmore)
m["resid_wirecap"]=m["wire_cap_fF_post"]-m["wire_cap_fF_pre"]
m["resid_netcap"] =m["net_cap_fF_post"]-m["net_cap_fF_pre"]
m["delta_elmore"] =m["elmore_max_ps_post"]-m["elmore_max_ps_pre"]
m["delta_slack"]  =m["sink_slack_max_ns_post"]-m["sink_slack_max_ns_pre"]

# wirelength routed vs estimated -> detour
wl_pre =load_wirelen(p("pre_wirelen.csv")).rename(columns={"hpwl_um":"est_len","routed_len_um":"rl_pre"})
wl_post=load_wirelen(p("post_wirelen.csv")).rename(columns={"routed_len_um":"routed_len","hpwl_um":"hpwl_post"})
m=m.merge(wl_pre[["net","est_len"]],on="net",how="left")
m=m.merge(wl_post[["net","routed_len"]],on="net",how="left")
# detour = routed detailed-route length - Steiner/HPWL estimate (placement)
m["detour"]=m["routed_len"]-m["est_len"]

# RUDY (per net) joined to arcs
rud=pd.read_csv(p("pre_rudy.csv"))[["net","rudy","npins","hpwl_um"]]
m=m.merge(rud,on="net",how="left")
m["fanout"]=m["fanout_pre"]
m["log_est_len"]=np.log(m["est_len"].clip(lower=1e-3))

mm=m.dropna(subset=["delta_elmore","resid_wirecap","rudy","detour","est_len"]).copy()
print(f"[clean] arcs_for_analysis={len(mm)}")

def safe_spearman(a,b):
    a=np.asarray(a,float); b=np.asarray(b,float)
    msk=np.isfinite(a)&np.isfinite(b)
    if msk.sum()<5 or np.std(a[msk])==0 or np.std(b[msk])==0: return (float('nan'),float('nan'),int(msk.sum()))
    r,pp=stats.spearmanr(a[msk],b[msk]); return (r,pp,int(msk.sum()))

print("\n===== GATE A: residual vs delay =====")
for an,a in [("resid_wirecap",mm["resid_wirecap"]),("resid_netcap",mm["resid_netcap"]),("detour",mm["detour"])]:
    r,pp,n=safe_spearman(a,mm["delta_elmore"])
    print(f"Spearman({an}, delta_elmore): rho={r:.4f} p={pp:.3g} n={n}")
    r2,pp2,_=safe_spearman(a,mm["delta_slack"])
    print(f"Spearman({an}, delta_slack ): rho={r2:.4f} p={pp2:.3g}")

# does residual/detour survive controlling for RUDY? partial spearman via rank-residualization
def partial_spearman(x,y,z):
    df=pd.DataFrame({"x":x,"y":y,"z":z}).replace([np.inf,-np.inf],np.nan).dropna()
    if len(df)<8: return (float('nan'),float('nan'),len(df))
    rx=stats.rankdata(df.x); ry=stats.rankdata(df.y); rz=stats.rankdata(df.z)
    def resid(a,b):
        b=np.c_[np.ones(len(b)),b]; beta,*_=np.linalg.lstsq(b,a,rcond=None); return a-b@beta
    ex=resid(rx,rz); ey=resid(ry,rz)
    if np.std(ex)==0 or np.std(ey)==0: return (float('nan'),float('nan'),len(df))
    r,pp=stats.pearsonr(ex,ey); return (r,pp,len(df))

print("\n===== GATE A: beyond-RUDY (partial Spearman controlling for RUDY) =====")
for an,a in [("detour",mm["detour"]),("resid_wirecap",mm["resid_wirecap"]),("resid_netcap",mm["resid_netcap"])]:
    r,pp,n=partial_spearman(a,mm["delta_elmore"],mm["rudy"])
    print(f"partial Spearman({an}, delta_elmore | rudy): r={r:.4f} p={pp:.3g} n={n}")

# multiple regression delta_elmore ~ detour + log_est_len + fanout + rudy
print("\n===== GATE A: OLS delta_elmore ~ detour + log_est_len + fanout + rudy =====")
reg=mm.dropna(subset=["delta_elmore","detour","log_est_len","fanout","rudy"]).copy()
if len(reg)>=10:
    X=reg[["detour","log_est_len","fanout","rudy"]].values
    X=(X-X.mean(0))/ (X.std(0)+1e-12)   # standardize for comparable betas
    X=np.c_[np.ones(len(X)),X]
    y=reg["delta_elmore"].values
    beta,res,rank,sv=np.linalg.lstsq(X,y,rcond=None)
    yhat=X@beta; ss_res=np.sum((y-yhat)**2); ss_tot=np.sum((y-y.mean())**2)
    r2=1-ss_res/ss_tot if ss_tot>0 else float('nan')
    # std errors
    n,k=X.shape; sigma2=ss_res/max(n-k,1)
    cov=sigma2*np.linalg.pinv(X.T@X); se=np.sqrt(np.diag(cov))
    names=["const","detour","log_est_len","fanout","rudy"]
    print(f"n={n} R2={r2:.4f}")
    for nm,b,s in zip(names,beta,se):
        t=b/s if s>0 else float('nan'); print(f"  {nm:14s} beta(std)={b:+.4f} se={s:.4f} t={t:+.2f}")
else:
    print("not enough rows for OLS")

# critical-arc focus: arcs with worst (most negative) post slack
print("\n===== GATE A on CRITICAL arcs (worst 20% post-slack) =====")
thr=mm["sink_slack_max_ns_post"].quantile(0.20)
crit=mm[mm["sink_slack_max_ns_post"]<=thr]
print(f"critical arcs n={len(crit)} (slack<= {thr:.4f} ns)")
for an,a in [("detour",crit["detour"]),("resid_wirecap",crit["resid_wirecap"])]:
    r,pp,n=safe_spearman(a,crit["delta_elmore"])
    rp,ppp,_=partial_spearman(a,crit["delta_elmore"],crit["rudy"])
    print(f"  {an}: Spearman vs dElmore rho={r:.4f}(p={pp:.3g}); partial|rudy r={rp:.4f}(p={ppp:.3g}) n={n}")

# ===== Oracle timing delta =====
def rd_wns(fn):
    w=t=None
    if os.path.exists(fn):
        for l in open(fn):
            if l.startswith("WNS"): w=float(l.split()[1])
            if l.startswith("TNS"): t=float(l.split()[1])
    return w,t
pw,pt=rd_wns(p("pre_wns_tns.txt")); qw,qt=rd_wns(p("post_wns_tns.txt"))
print("\n===== ORACLE TIMING DELTA (Steiner baseline vs routed-RC) =====")
print(f"Steiner-baseline (PRE)  WNS={pw} ns  TNS={pt} ns")
print(f"Routed-RC (POST/SPEF)   WNS={qw} ns  TNS={qt} ns")
if pw is not None and qw is not None:
    print(f"delta WNS = {qw-pw:+.5f} ns ; delta TNS = {qt-pt:+.5f} ns  (achievable-gain ceiling)")

m.to_csv(p("gateA_merged.csv"),index=False)
print(f"\n[wrote] {p('gateA_merged.csv')}")
