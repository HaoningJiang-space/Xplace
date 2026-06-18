# MECHANISM AUTOPSY P3-extended (the one place routing could still add criticality info): on the SAME
# post-CTS/post-DP ariane placement, dump post-CTS est criticality, then FULL detailed_route + OpenRCX
# COUPLING extraction + SPEF, dump the coupling-routed criticality. Jaccard(post-CTS-est, coupling-routed)
# tells us if signoff-fidelity COUPLING routing reorders the critical set more than GR did (R40: GR-routed
# vs post-CTS-est = 0.982, i.e. GR adds ~nothing). If coupling also ~0.98 -> route-feedback is fully dead on
# ariane; if much lower -> a narrow coupling-criticality angle survives. CPU-only. No set -u.
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
# post-CTS/post-DP netlist
clock_tree_synthesis -buf_list BUF_X4 -root_buf BUF_X4 -sink_clustering_enable
set_propagated_clock [all_clocks]
detailed_placement
catch { check_placement }
# same-stage est (post-CTS, pre-route)
estimate_parasitics -placement
puts "CC_EST_WNS [sta::worst_slack -max]"
dump_netslack $OUT/${TAG}_est.csv
# full route + OpenRCX coupling + SPEF
set_routing_layers -signal metal2-metal10 -clock metal2-metal10
set_global_routing_layer_adjustment metal2-metal10 0.5
global_route -congestion_iterations 30 -verbose
if {[catch { detailed_route -bottom_routing_layer metal2 -top_routing_layer metal10 -verbose 1 } drmsg]} { puts "DRT_FAIL $drmsg" }
define_process_corner -ext_model_index 0 X
extract_parasitics -ext_model_file $NG/rcx_patterns.rules
write_spef $OUT/${TAG}.spef
read_spef $OUT/${TAG}.spef
puts "CC_COUPLING_WNS [sta::worst_slack -max]"
puts "CC_COUPLING_TNS [sta::total_negative_slack -max]"
dump_netslack $OUT/${TAG}_coupling.csv
puts "BACKEND_COUPLING_CRIT_DONE"
