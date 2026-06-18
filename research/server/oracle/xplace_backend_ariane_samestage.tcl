# MECHANISM AUTOPSY step 1 (user-directed): isolate the CTS/stage contribution to the est-vs-routed
# criticality divergence. On ONE fixed ariane placement, dump per-net worst-slack criticality at THREE
# points — (a) est PRE-CTS (estimate_parasitics -placement, the current "est" stage), (b) est POST-CTS+DP
# (same -placement estimate but after clock tree + detailed placement = the routed CSV's netlist stage),
# (c) routed (after global_route). Then Jaccard(pre,routed) vs Jaccard(post,routed) tells us how much of
# the "divergence" is CTS/stage vs genuine routing reordering. GR-fidelity (matches the divergence metric).
# Default setRC (metal3) = the est the divergence table uses. CPU-only, no DR. No set -u. No () in echo.
set NG /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/nangate45
set DES /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/designs/nangate45/ariane133
set OUT $::env(XP_OUT); file mkdir $OUT
set TAG $::env(XP_TAG)
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
# (a) est PRE-CTS — the current "est" stage (placement-stage estimate, no clock tree yet)
estimate_parasitics -placement
puts "PRECTS_WNS [sta::worst_slack -max]"
puts "PRECTS_TNS [sta::total_negative_slack -max]"
dump_netslack $OUT/${TAG}_est_prects.csv
# build the clock tree + re-legalize (this is the netlist stage the routed CSV is dumped at)
clock_tree_synthesis -buf_list BUF_X4 -root_buf BUF_X4 -sink_clustering_enable
set_propagated_clock [all_clocks]
detailed_placement
catch { check_placement }
# (b) est POST-CTS+DP — same -placement estimator, but on the post-CTS netlist/geometry (no routing yet)
estimate_parasitics -placement
puts "POSTCTS_WNS [sta::worst_slack -max]"
puts "POSTCTS_TNS [sta::total_negative_slack -max]"
dump_netslack $OUT/${TAG}_est_postcts.csv
# (c) routed — global route + GR-estimated parasitics (the "routed" criticality stage, GR fidelity)
set_routing_layers -signal metal2-metal10 -clock metal2-metal10
set_global_routing_layer_adjustment metal2-metal10 0.5
global_route -congestion_iterations 30 -verbose
estimate_parasitics -global_routing
puts "ROUTED_WNS [sta::worst_slack -max]"
puts "ROUTED_TNS [sta::total_negative_slack -max]"
dump_netslack $OUT/${TAG}_routed.csv
puts "BACKEND_SAMESTAGE_DONE"
