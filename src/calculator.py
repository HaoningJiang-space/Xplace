import torch
from .param_scheduler import ParamScheduler
from .core import merged_wl_loss_grad, merged_wl_loss_grad_timing, detour_timing_grad

def apply_precond(mov_node_pos: torch.Tensor, ps: ParamScheduler, args):
    if not args.use_precond:
        return
    mov_node_pos.grad /= ps.precond_weight
    return mov_node_pos.grad


def calc_obj_and_grad(
    mov_node_pos,
    constraint_fn=None,
    route_fn=None,
    mov_node_size=None,
    expand_ratio=None,
    init_density_map=None,
    density_map_layer=None,
    conn_fix_node_pos=None,
    ps=None,
    data=None,
    args=None,
    merged_forward_backward=True,
):
    mov_lhs, mov_rhs = data.movable_index
    mov_node_pos = constraint_fn(mov_node_pos)
    conn_node_pos = mov_node_pos[mov_lhs:mov_rhs, ...]
    conn_node_pos = torch.cat([conn_node_pos, conn_fix_node_pos], dim=0)

    assert merged_forward_backward
    if merged_forward_backward:
        if mov_node_pos.grad is not None:
            mov_node_pos.grad.zero_()
        else:
            mov_node_pos.grad = torch.zeros_like(mov_node_pos).detach()

        if ps.use_route_force and ps.start_route_opt:
            mov_route_grad, mov_congest_grad, mov_pseudo_grad = route_fn(
                mov_node_pos, mov_node_size, expand_ratio, constraint_fn
            )
            # TERM-2 v1 (ANALYSIS_TERM2.md): the per-BIN concentration is done in get_route_force
            # (route_gradmat is multiplied by the critical-corridor map). Here we additionally push
            # only the NON-critical AGGRESSORS: scale the per-node force by (1-node_crit) so critical
            # cells are NOT moved (keep the critical net compact) while non-critical cells are cleared
            # out of the critical corridor. This is ESSENCE.md's "clear corridor, don't pull". Scale
            # OUT-OF-PLACE (route_fn may return the cached mov_route_grad tensor).
            if getattr(ps, "timing_route_weight", 0.0) > 0 and getattr(data, "node_criticality", None) is not None:
                tw_scale = torch.ones((mov_route_grad.shape[0], 1), device=mov_route_grad.device, dtype=mov_route_grad.dtype)
                tw_scale[mov_lhs:mov_rhs, 0] = (1.0 - data.node_criticality[mov_lhs:mov_rhs]).clamp(min=0.0)
                mov_route_grad = mov_route_grad * tw_scale
            mov_node_pos.grad += mov_route_grad * ps.route_weight
            mov_node_pos.grad += mov_congest_grad * ps.congest_weight
            mov_node_pos.grad += mov_pseudo_grad * ps.pseudo_weight

        wl_loss, conn_node_grad_by_wl = merged_wl_loss_grad(
            conn_node_pos, data.pin_id2node_id, data.pin_rel_cpos,
            data.node2pin_list, data.node2pin_list_end,
            data.hyperedge_list, data.hyperedge_list_end, data.net_mask, 
            data.hpwl_scale, ps.wa_coeff, args.deterministic
        )
        mov_node_pos.grad[mov_lhs:mov_rhs] += conn_node_grad_by_wl[mov_lhs:mov_rhs]

        if ps.enable_timing:
            wl_loss_timing, conn_node_grad_by_timing = merged_wl_loss_grad_timing(
                conn_node_pos, data.gputimer.timing_pin_weight,
                data.pin_id2node_id, data.pin_rel_cpos,
                data.node2pin_list, data.node2pin_list_end, data.hyperedge_list, data.hyperedge_list_end,
                data.net_mask, data.net_weight, data.hpwl_scale, ps.wa_coeff, args.deterministic
            )
            # R25 fix: AUTO-CALIBRATE the timing force to a design-invariant fraction of the WL
            # gradient norm. A fixed --oracle_timing_scale over-pulls on some designs (swerv: HPWL
            # +38%, TNS worse than no-timing). Rescaling to ||timing||=frac*||wl|| each iter keeps the
            # per-pin criticality RANKING but makes the global scale design-invariant (frozen rule).
            tfrac = getattr(args, "timing_force_frac", 0.0)
            if tfrac > 0:
                wl_n = conn_node_grad_by_wl[mov_lhs:mov_rhs].norm()
                tm_n = conn_node_grad_by_timing[mov_lhs:mov_rhs].norm()
                if tm_n > 0:
                    conn_node_grad_by_timing = conn_node_grad_by_timing * (tfrac * wl_n / tm_n)
            mov_node_pos.grad[mov_lhs:mov_rhs] += conn_node_grad_by_timing[mov_lhs:mov_rhs]
            wl_loss += wl_loss_timing

            # Level-A differentiable route-aware timing term (IMPLICIT_DIFF_TIMING.md §9):
            # additive ∂[Σ w_n·HPWL_n·(1+α·ρ_n)]/∂x — tests whether a differentiable
            # routed-length (detour) signal beats the frozen route-blind HPWL force. Gated;
            # inert unless --detour_timing_weight > 0. Costs O(#critical nets) (w_n sparse).
            if getattr(args, "detour_timing_weight", 0.0) > 0:
                mov_count = mov_rhs - mov_lhs
                g_detour = detour_timing_grad(
                    conn_node_pos[:mov_count], conn_node_pos[mov_count:], data,
                    alpha=getattr(args, "detour_alpha", 2.0),
                )
                mov_node_pos.grad[mov_lhs:mov_rhs] += args.detour_timing_weight * g_detour

        if ps.enable_sample_force:
            if ps.iter > 3 and ps.iter % 20 == 0:
                # ps.iter > 3 for warmup
                density_loss, _, node_grad_by_density = density_map_layer.merged_density_loss_grad(
                    mov_node_pos, mov_node_size, init_density_map, calc_overflow=False
                )
                ps.force_ratio = (
                    ps.density_weight * node_grad_by_density[mov_lhs:mov_rhs].norm(p=1) / 
                    conn_node_grad_by_wl[mov_lhs:mov_rhs].norm(p=1)
                ).clamp_(max=10)
                mov_node_pos.grad += node_grad_by_density * ps.density_weight
            else:
                density_loss = 0.0
            if (ps.iter > 3 and ps.recorder.force_ratio[-1] > 1e-2) or ps.iter > 100:
                # no longer enable sampling back
                ps.enable_sample_force = False
        else:
            density_loss, _, node_grad_by_density = density_map_layer.merged_density_loss_grad(
                mov_node_pos, mov_node_size, init_density_map, calc_overflow=False
            )
            mov_node_pos.grad += node_grad_by_density * ps.density_weight

        if ps.zero_macro_grad:
            mov_node_pos.grad[mov_lhs:mov_rhs].masked_fill_(data.is_mov_macro[mov_lhs:mov_rhs].unsqueeze(1), 0)

        grad = apply_precond(mov_node_pos, ps, args)
        loss = wl_loss + ps.density_weight * density_loss

    return loss, grad

