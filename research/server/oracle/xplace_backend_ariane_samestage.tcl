# P3 SAME-STAGE divergence (MECHANISM_AUTOPSY #4): dump est slack AFTER CTS+DP (pre-route) and routed
# slack AFTER global_route, on the SAME post-CTS/post-DP netlist. Isolates ROUTING-parasitic reordering
# from the CTS/netlist/stage differences the current backend conflates (est was dumped pre-CTS).
set NG /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/nangate45
set DES /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/designs/nangate45/ariane133
set OUT $::env(XP_OUT)
file mkdir $OUT
set_thread_count 16
read_lef $NG/lef/NangateOpenCellLibrary.tech.lef
read_lef $NG/lef/NangateOpenCellLibrary.macro.mod.lef
read_lef $NG/lef/fakeram45_256x16.lef
read_liberty $NG/lib/NangateOpenCellLibrary_typical.lib
read_liberty $NG/lib/fakeram45_256x16.lib
read_def $::env(XP_DEF)
source $DES/ariane.sdc
source $NG/setRC.tcl
set_propagated_clock [all_clocks]
proc dump_netslack {fn} {
  set f [open $fn w]; puts $f "net,worst_slack_ns"
  foreach net [get_nets *] { set nm [get_full_name $net]; set wslk 1e30
    foreach pin [get_pins -quiet -of_objects $net] {
      if {[sta::Pin_is_load $pin]} { set s [get_property $pin slack_max]
        if {$s ne "" && $s < $wslk} { set wslk $s } } }
    if {$wslk < 1e29} { puts $f "$nm,$wslk" } }
  close $f
}
# --- bring the netlist to post-CTS/post-DP FIRST (so est and routed share the same stage) ---
clock_tree_synthesis -buf_list BUF_X4 -root_buf BUF_X4 -sink_clustering_enable
set_propagated_clock [all_clocks]
detailed_placement
catch { check_placement }
# --- SAME-STAGE est: Steiner estimate on the post-CTS/post-DP netlist, BEFORE routing ---
estimate_parasitics -placement
puts "SAMESTAGE_EST_WNS [sta::worst_slack -max]"
puts "SAMESTAGE_EST_TNS [sta::total_negative_slack -max]"
dump_netslack $OUT/$::env(XP_TAG)_samestage_est_netslack.csv
# --- routed: same netlist, now with global route ---
# (R32 convergence fix: layer adjustment + congestion iters so GR clears overflow on the routability-grade
#  cell-inflated placement; plain global_route over-packs and stalls "GRT-0103 hard benchmark" otherwise)
set_routing_layers -signal metal2-metal10 -clock metal2-metal10
set_global_routing_layer_adjustment metal2-metal10 0.5
global_route -congestion_iterations 30 -verbose
estimate_parasitics -global_routing
puts "SAMESTAGE_ROUTED_WNS [sta::worst_slack -max]"
puts "SAMESTAGE_ROUTED_TNS [sta::total_negative_slack -max]"
dump_netslack $OUT/$::env(XP_TAG)_samestage_routed_netslack.csv
puts "SAMESTAGE_BACKEND_DONE"
