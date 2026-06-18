# bp_multi_top back-end on an Xplace placement DEF (macros fixed). GR-based.
set NG /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/nangate45
set DES /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/designs/nangate45/bp_multi_top
set OUT $::env(XP_OUT)
file mkdir $OUT
set_thread_count 16
read_lef $NG/lef/NangateOpenCellLibrary.tech.lef
read_lef $NG/lef/NangateOpenCellLibrary.macro.mod.lef
read_lef $NG/lef/fakeram45_512x64.lef
read_lef $NG/lef/fakeram45_256x96.lef
read_lef $NG/lef/fakeram45_32x64.lef
read_lef $NG/lef/fakeram45_64x7.lef
read_lef $NG/lef/fakeram45_64x15.lef
read_lef $NG/lef/fakeram45_64x96.lef
read_liberty $NG/lib/NangateOpenCellLibrary_typical.lib
read_liberty $NG/lib/fakeram45_512x64.lib
read_liberty $NG/lib/fakeram45_256x96.lib
read_liberty $NG/lib/fakeram45_32x64.lib
read_liberty $NG/lib/fakeram45_64x7.lib
read_liberty $NG/lib/fakeram45_64x15.lib
read_liberty $NG/lib/fakeram45_64x96.lib
read_def $::env(XP_DEF)
source $DES/constraint.sdc
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
estimate_parasitics -placement
puts "DPLACE_WNS [sta::worst_slack -max]"
puts "DPLACE_TNS [sta::total_negative_slack -max]"
dump_netslack $OUT/$::env(XP_TAG)_place_netslack.csv
clock_tree_synthesis -buf_list BUF_X4 -root_buf BUF_X4 -sink_clustering_enable
set_propagated_clock [all_clocks]
detailed_placement
catch { check_placement }
set_routing_layers -signal metal2-metal10 -clock metal2-metal10
global_route
estimate_parasitics -global_routing
puts "DROUTE_WNS [sta::worst_slack -max]"
puts "DROUTE_TNS [sta::total_negative_slack -max]"
dump_netslack $OUT/$::env(XP_TAG)_netslack.csv
puts "BACKEND_DONE"
