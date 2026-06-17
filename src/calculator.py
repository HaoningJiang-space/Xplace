import torch
from .param_scheduler import ParamScheduler
from .core import merged_wl_loss_grad, merged_wl_loss_grad_timing

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
            # TERM-2 prototype (PROTOTYPE.md): timing-weighted congestion force. Scale the
            # per-node route (congestion) force by (1+alpha*node_criticality), so timing-critical
            # cells get pushed out of congestion harder (route-aware DENSITY lever). node_crit =
            # max over the node's pins of per-net criticality; cached (oracle criticality is static).
            if getattr(ps, "timing_route_weight", 0.0) > 0 and getattr(data, "net_criticality", None) is not None:
                if getattr(data, "node_criticality", None) is None:
                    pin_net_crit = data.net_criticality[data.pin_id2net_id.long()]
                    nc = torch.zeros(data.num_nodes, device=mov_node_pos.device, dtype=torch.float32)
                    nc.scatter_reduce_(0, data.pin_id2node_id.long(), pin_net_crit, reduce="amax", include_self=True)
                    data.node_criticality = nc
                tw = 1.0 + ps.timing_route_weight * data.node_criticality[mov_lhs:mov_rhs].unsqueeze(1)
                mov_route_grad[mov_lhs:mov_rhs] = mov_route_grad[mov_lhs:mov_rhs] * tw
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
            mov_node_pos.grad[mov_lhs:mov_rhs] += conn_node_grad_by_timing[mov_lhs:mov_rhs]
            wl_loss += wl_loss_timing
            
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

