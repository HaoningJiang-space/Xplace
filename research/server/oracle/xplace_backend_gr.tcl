# Back-end on an Xplace placement DEF, GR-based (fast, deterministic).
# Xplace places -> CTS -> global route -> GR parasitics -> STA.
# Same CTS netlist + same GR estimator across arms (D1/D7), so the
# baseline-vs-oracle comparison is valid. Also dumps per-net worst slack
# for oracle-weight computation.
# Env: XP_DEF (placement DEF), XP_OUT (dir), XP_TAG, XP_PERIOD
set NG /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/nangate45
set DES /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/designs/nangate45/aes
set OUT $::env(XP_OUT)
file mkdir $OUT
set_thread_count 16

read_lef $NG/lef/NangateOpenCellLibrary.tech.lef
read_lef $NG/lef/NangateOpenCellLibrary.macro.mod.lef
read_liberty $NG/lib/NangateOpenCellLibrary_typical.lib
read_def $::env(XP_DEF)
source $DES/constraint.sdc
source $NG/setRC.tcl
set_propagated_clock [all_clocks]

# ---- D_place: pre-route (Steiner RC estimate) ----
estimate_parasitics -placement
puts "DPLACE_WNS [sta::worst_slack -max]"
puts "DPLACE_TNS [sta::total_negative_slack -max]"

# ---- CTS + legalize ----
clock_tree_synthesis -buf_list BUF_X4 -root_buf BUF_X4 -sink_clustering_enable
set_propagated_clock [all_clocks]
detailed_placement
check_placement

# ---- Global route + GR-based parasitics = D_route ----
set_routing_layers -signal metal2-metal10 -clock metal2-metal10
global_route
estimate_parasitics -global_routing
puts "DROUTE_WNS [sta::worst_slack -max]"
puts "DROUTE_TNS [sta::total_negative_slack -max]"
# total routed wire cap = routing-induced RC proxy (iso-congestion control)
set corner [sta::cmd_corner]
set twc 0.0
foreach net [get_nets *] { catch { set twc [expr {$twc + [sta::Net_wire_capacitance $net $corner max]}] } }
puts "TOTAL_WIRE_CAP_fF [expr {$twc*1e15}]"

# ---- routed WL (GR) as the iso-WL control ----
set grwl "NA"
catch { set grwl [grt::compute_grt_wirelength] }
puts "GR_WIRELENGTH $grwl"
catch { report_design_area }

# ---- per-net worst slack dump (for oracle weights) ----
set corner [sta::cmd_corner]
set f [open $OUT/${::env(XP_TAG)}_netslack.csv w]
puts $f "net,worst_slack_ns"
foreach net [get_nets *] {
  set nm [get_full_name $net]; set wslk 1e30
  foreach pin [get_pins -quiet -of_objects $net] {
    if {[sta::Pin_is_load $pin]} {
      set s [get_property $pin slack_max]
      if {$s ne "" && $s < $wslk} { set wslk $s }
    }
  }
  if {$wslk < 1e29} { puts $f "$nm,$wslk" }
}
close $f
write_def $OUT/${::env(XP_TAG)}_cts.def
puts "BACKEND_DONE"
