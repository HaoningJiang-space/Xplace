import torch

# Level-A differentiable route-aware timing term (IMPLICIT_DIFF_TIMING.md §9 — the cheap,
# single-direction validation BEFORE the full IFT / soft-router fusion).
#
# Hypothesis under test: feeding a *differentiable routed-length* estimate into the timing
# force beats the frozen route-blind HPWL force. We approximate routed length by a
# congestion-detour multiplier on the estimated (HPWL) length:
#
#     L_detour = Σ_n  w_n · HPWL_n(x) · (1 + α · ρ_n(x))
#
#   w_n  = data.net_criticality   — the route-aware UNION criticality (the SOURCE; sparse,
#          nonzero only on critical nets, so the whole term costs O(#critical nets)).
#   ρ_n  = differentiable pin-density congestion, bilinearly sampled at net n's centroid.
#
# This is one-directional (no routing variable p), so it cannot be "bidirectional" — it only
# tests whether ∂(detour-length)/∂x carries useful route-aware signal. If it helps, escalate to
# Level-B (soft-rasterized router + p) and the IFT cross term (IMPLICIT_DIFF_TIMING.md §5-8).


def _bilinear_splat(gx, gy, vals, G):
    """Differentiable splat of `vals` at continuous grid coords (gx, gy) onto a (G, G) field.
    Gradient flows to (gx, gy) through the bilinear weights and to `vals` directly."""
    ix0 = gx.floor().clamp(0, G - 2)
    iy0 = gy.floor().clamp(0, G - 2)
    fx = gx - ix0
    fy = gy - iy0
    ix0l = ix0.long()
    iy0l = iy0.long()
    flat = gx.new_zeros(G * G)
    for dx in (0, 1):
        for dy in (0, 1):
            wx = (1.0 - fx) if dx == 0 else fx
            wy = (1.0 - fy) if dy == 0 else fy
            idx = (iy0l + dy) * G + (ix0l + dx)
            flat = flat.scatter_add(0, idx, vals * wx * wy)
    return flat.view(G, G)


def _bilinear_sample(field, gx, gy):
    """Differentiable bilinear sample of a (G, G) `field` at continuous coords (gx, gy)."""
    G = field.shape[0]
    ix0 = gx.floor().clamp(0, G - 2)
    iy0 = gy.floor().clamp(0, G - 2)
    fx = gx - ix0
    fy = gy - iy0
    ix0l = ix0.long()
    iy0l = iy0.long()
    f = field.reshape(-1)
    out = torch.zeros_like(gx)
    for dx in (0, 1):
        for dy in (0, 1):
            wx = (1.0 - fx) if dx == 0 else fx
            wy = (1.0 - fy) if dy == 0 else fy
            idx = (iy0l + dy) * G + (ix0l + dx)
            out = out + f[idx] * wx * wy
    return out


def detour_timing_grad(conn_node_pos_mov, conn_fix_node_pos, data, alpha=2.0, grid=128, eps=1e-6, frame=None, arc=False):
    """Gradient of L_detour w.r.t. the MOVABLE node positions.

    Args:
        conn_node_pos_mov: (M, 2) movable connected-node positions (the leading slice of
            calculator's `conn_node_pos`). Detached internally; we build a local autograd graph.
        conn_fix_node_pos: (F, 2) fixed connected-node positions (appended after movable).
        data: PlaceData. Uses pin_id2node_id, pin_rel_cpos, pin_id2net_id, net_criticality.
        alpha: detour strength (routed ≈ est·(1 + α·ρ)).
    Returns:
        (M, 2) gradient to be added (scaled by a weight) onto mov_node_pos.grad[mov_lhs:mov_rhs].
        Zeros if no critical net is present.
    """
    device = conn_node_pos_mov.device
    pos_mov = conn_node_pos_mov.detach().requires_grad_(True)
    conn = torch.cat([pos_mov, conn_fix_node_pos.detach()], dim=0)

    pin_pos = conn[data.pin_id2node_id] + data.pin_rel_cpos          # (P, 2) differentiable
    pin_net = data.pin_id2net_id.to(device)                         # (P,)

    net_mask = getattr(data, "net_mask", None)
    num_nets = (net_mask.shape[0] if net_mask is not None
                else int(pin_net.max().item()) + 1)

    # ---- differentiable congestion field from ALL pins (unit weight), relative to mean demand ----
    # lo/hi are DETACHED: the grid frame is fixed per call (positions normalized into it), so the
    # gradient is the response of demand/centroid *within* a fixed frame, not of the frame itself —
    # the intended, stable behavior for a per-iteration congestion proxy. span is floored to avoid
    # div-by-0; a degenerate (near-zero-span) axis saturates clamp(0,1) so grads vanish there.
    if frame is None:
        lo = pin_pos.detach().amin(0)
        hi = pin_pos.detach().amax(0)
    else:                                # caller-fixed frame (e.g. die/core bounds) — codex LOW#3
        lo, hi = frame
        lo = lo.to(device=device, dtype=pos_mov.dtype)
        hi = hi.to(device=device, dtype=pos_mov.dtype)
    span = (hi - lo).clamp(min=eps)

    def to_grid(px, py):
        gx = ((px - lo[0]) / span[0]).clamp(0, 1) * (grid - 1)
        gy = ((py - lo[1]) / span[1]).clamp(0, 1) * (grid - 1)
        return gx, gy

    gx, gy = to_grid(pin_pos[:, 0], pin_pos[:, 1])
    demand = _bilinear_splat(gx, gy, torch.ones_like(gx), grid)
    rho = demand / (demand.mean() + eps)

    if not arc:
        # ====================== NET-LEVEL (scaffold; FD-verified) ======================
        # w_n: prefer UNION net_criticality, else estimated timing_pin_weight aggregated to nets.
        w = getattr(data, "net_criticality", None)
        if w is not None:
            w = w.to(device=device, dtype=pos_mov.dtype)
        else:
            tpw = getattr(getattr(data, "gputimer", None), "timing_pin_weight", None)
            if tpw is None:
                return torch.zeros_like(conn_node_pos_mov)
            wn = torch.zeros(num_nets, device=device, dtype=pos_mov.dtype).scatter_reduce(
                0, pin_net, tpw.to(device=device, dtype=pos_mov.dtype), reduce="amax", include_self=True)
            rng = (wn.max() - wn.min()).clamp(min=eps)
            wn = (wn - wn.min()) / rng
            w = torch.where(wn > 0.1, wn, torch.zeros_like(wn))
        sel = w > 0
        if net_mask is not None:
            sel = sel & net_mask.to(device).bool()
        crit_nets = sel.nonzero(as_tuple=True)[0]
        if crit_nets.numel() == 0:
            return torch.zeros_like(conn_node_pos_mov)
        K = crit_nets.numel()
        remap = torch.full((num_nets,), -1, dtype=torch.long, device=device)
        remap[crit_nets] = torch.arange(K, device=device)
        pk_cid_all = remap[pin_net]
        keep = pk_cid_all >= 0
        pk_pos = pin_pos[keep]
        pk_cid = pk_cid_all[keep]

        def seg_minmax(vals):
            amax = vals.new_full((K,), -1e30).scatter_reduce(0, pk_cid, vals, reduce="amax", include_self=True)
            amin = vals.new_full((K,), 1e30).scatter_reduce(0, pk_cid, vals, reduce="amin", include_self=True)
            return amax, amin

        xmax, xmin = seg_minmax(pk_pos[:, 0])
        ymax, ymin = seg_minmax(pk_pos[:, 1])
        hpwl_n = (xmax - xmin) + (ymax - ymin)
        cnt = torch.zeros(K, device=device, dtype=pos_mov.dtype).scatter_add(
            0, pk_cid, torch.ones_like(pk_cid, dtype=pos_mov.dtype)).clamp(min=1.0)
        cx = torch.zeros(K, device=device, dtype=pos_mov.dtype).scatter_add(0, pk_cid, pk_pos[:, 0]) / cnt
        cy = torch.zeros(K, device=device, dtype=pos_mov.dtype).scatter_add(0, pk_cid, pk_pos[:, 1]) / cnt
        cgx, cgy = to_grid(cx, cy)
        rho_n = _bilinear_sample(rho, cgx, cgy)
        L = (w[crit_nets] * hpwl_n * (1.0 + alpha * rho_n)).sum()
    else:
        # ====================== ARC-LEVEL (per-sink; CRITICALITY_GRANULARITY.md) ======================
        # Act on each CRITICAL PIN individually (not the net bbox): pull it toward its net centroid,
        # weighted by its OWN criticality κ_v and its OWN corridor congestion ρ_v. This removes
        # net-level's wrong-pin pull + per-sink-detour loss (codex: net aggregation is a false-negative
        # machine) WITHOUT needing driver identification (centroid reference; no C++/db plumbing).
        #   L_arc = Σ_v κ_v · ‖pos(v) − c_net(v)‖₁ · (1 + α·ρ_v)
        # κ_v: prefer per-pin timing_pin_weight (true per-sink criticality); else net_criticality
        # broadcast to its pins (geometry/congestion still per-pin even if κ is net-broadcast).
        tpw = getattr(getattr(data, "gputimer", None), "timing_pin_weight", None)
        if tpw is not None:
            kp = tpw.to(device=device, dtype=pos_mov.dtype)
        else:
            wn = getattr(data, "net_criticality", None)
            if wn is None:
                return torch.zeros_like(conn_node_pos_mov)
            kp = wn.to(device=device, dtype=pos_mov.dtype)[pin_net]
        rng = (kp.max() - kp.min()).clamp(min=eps)
        kp = (kp - kp.min()) / rng                                   # normalize to [0,1]
        selp = kp > 0.1                                              # critical-pin band (sparse)
        if net_mask is not None:
            selp = selp & net_mask.to(device).bool()[pin_net]
        if selp.sum() == 0:
            return torch.zeros_like(conn_node_pos_mov)
        # net centroid over ALL pins of each net (differentiable)
        cntN = torch.zeros(num_nets, device=device, dtype=pos_mov.dtype).scatter_add(
            0, pin_net, torch.ones_like(pin_net, dtype=pos_mov.dtype)).clamp(min=1.0)
        cNx = torch.zeros(num_nets, device=device, dtype=pos_mov.dtype).scatter_add(0, pin_net, pin_pos[:, 0]) / cntN
        cNy = torch.zeros(num_nets, device=device, dtype=pos_mov.dtype).scatter_add(0, pin_net, pin_pos[:, 1]) / cntN
        vp = pin_pos[selp]                                           # (Pv, 2) critical pins
        vn = pin_net[selp]
        vk = kp[selp]
        len_v = (vp[:, 0] - cNx[vn]).abs() + (vp[:, 1] - cNy[vn]).abs()
        gxv, gyv = to_grid(vp[:, 0], vp[:, 1])
        rho_v = _bilinear_sample(rho, gxv, gyv)
        L = (vk * len_v * (1.0 + alpha * rho_v)).sum()
    (g,) = torch.autograd.grad(L, pos_mov)
    return g
