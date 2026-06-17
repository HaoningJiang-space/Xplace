"""Standalone correctness test for the Level-A differentiable detour-timing term.

Runs on CPU, no CUDA / no full pipeline needed (only torch). Verifies that the analytic
autograd gradient returned by `detour_timing_grad` matches a central finite-difference of the
underlying loss L = Σ w_n·HPWL_n·(1+α·ρ_n). Run from repo root:

    python tool/test_detour_timing.py

Exit 0 = all finite-difference checks pass.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import torch
from types import SimpleNamespace
from src.core.detour_timing import detour_timing_grad, _bilinear_splat, _bilinear_sample

torch.manual_seed(0)
DT = torch.float64          # double precision for a tight FD comparison
GRID = 32
ALPHA = 2.0


def make_case(M=8, F=3, P=20, K=5, seed=0):
    torch.manual_seed(seed)
    N = M + F
    mov = torch.randn(M, 2, dtype=DT)
    fix = torch.randn(F, 2, dtype=DT)
    # ensure every net has >=2 pins so HPWL/centroid are well defined
    base_net = torch.arange(P) % K
    data = SimpleNamespace(
        pin_id2node_id=torch.randint(0, N, (P,)),
        pin_rel_cpos=torch.randn(P, 2, dtype=DT) * 0.1,
        pin_id2net_id=base_net[torch.randperm(P)],
        net_criticality=torch.rand(K, dtype=DT),         # union-source path
        net_mask=torch.ones(K, dtype=torch.bool),
    )
    return mov, fix, data


def loss_only(mov, fix, data):
    """Recompute L with grad enabled — the reference the FD differentiates."""
    p = mov.clone().requires_grad_(True)
    conn = torch.cat([p, fix], 0)
    pin = conn[data.pin_id2node_id] + data.pin_rel_cpos
    pin_net = data.pin_id2net_id
    w = data.net_criticality
    sel = (w > 0) & data.net_mask
    cn = sel.nonzero(as_tuple=True)[0]
    K = cn.numel()
    remap = torch.full((w.shape[0],), -1, dtype=torch.long); remap[cn] = torch.arange(K)
    cid_all = remap[pin_net]; keep = cid_all >= 0
    pk = pin[keep]; cid = cid_all[keep]
    xmax = pk.new_full((K,), -1e30).scatter_reduce(0, cid, pk[:, 0], reduce="amax", include_self=True)
    xmin = pk.new_full((K,), 1e30).scatter_reduce(0, cid, pk[:, 0], reduce="amin", include_self=True)
    ymax = pk.new_full((K,), -1e30).scatter_reduce(0, cid, pk[:, 1], reduce="amax", include_self=True)
    ymin = pk.new_full((K,), 1e30).scatter_reduce(0, cid, pk[:, 1], reduce="amin", include_self=True)
    hp = (xmax - xmin) + (ymax - ymin)
    cnt = torch.zeros(K, dtype=DT).scatter_add(0, cid, torch.ones_like(cid, dtype=DT)).clamp(min=1)
    cx = torch.zeros(K, dtype=DT).scatter_add(0, cid, pk[:, 0]) / cnt
    cy = torch.zeros(K, dtype=DT).scatter_add(0, cid, pk[:, 1]) / cnt
    lo = pin.detach().amin(0); hi = pin.detach().amax(0); span = (hi - lo).clamp(min=1e-6)
    def tg(px, py):
        return (((px - lo[0]) / span[0]).clamp(0, 1) * (GRID - 1),
                ((py - lo[1]) / span[1]).clamp(0, 1) * (GRID - 1))
    gx, gy = tg(pin[:, 0], pin[:, 1])
    dem = _bilinear_splat(gx, gy, torch.ones_like(gx), GRID); rho = dem / (dem.mean() + 1e-6)
    cgx, cgy = tg(cx, cy); rn = _bilinear_sample(rho, cgx, cgy)
    return (w[cn] * hp * (1.0 + ALPHA * rn)).sum(), p


def main():
    ok = True
    for seed in range(4):
        mov, fix, data = make_case(seed=seed)
        g = detour_timing_grad(mov, fix, data, alpha=ALPHA, grid=GRID)
        assert g.shape == mov.shape and torch.isfinite(g).all(), "bad grad shape/nan"
        eps = 1e-6
        max_err = 0.0
        for i in range(mov.shape[0]):
            for j in range(2):
                mp = mov.clone(); mm = mov.clone(); mp[i, j] += eps; mm[i, j] -= eps
                lp, _ = loss_only(mp, fix, data); lm, _ = loss_only(mm, fix, data)
                num = ((lp - lm) / (2 * eps)).item()
                err = abs(num - g[i, j].item())
                max_err = max(max_err, err)
        status = "PASS" if max_err < 1e-4 else "FAIL"
        ok &= max_err < 1e-4
        print(f"seed={seed}  |grad|={g.norm():.4f}  max|fd-autograd|={max_err:.2e}  {status}")
    print("ALL PASS" if ok else "SOME FAILED")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
