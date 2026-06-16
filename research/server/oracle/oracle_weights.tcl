# Oracle net weights from the ROUTED STA of an Xplace placement.
# weight(net) = 1 + ALPHA * clamp(-worst_sink_slack / clk_period, 0, 1)
# i.e. routed-critical nets get up-weighted (a PERFECT predictor of routed criticality).
# Env: OW_DEF (routed def) OW_SPEF (routed spef) OW_OUT (csv) OW_PERIOD
set NG /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/nangate45
set DES /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/designs/nangate45/aes
set ALPHA 3.0
set PERIOD $::env(OW_PERIOD)
read_lef $NG/lef/NangateOpenCellLibrary.tech.lef
read_lef $NG/lef/NangateOpenCellLibrary.macro.mod.lef
read_liberty $NG/lib/NangateOpenCellLibrary_typical.lib
read_def $::env(OW_DEF)
source $DES/constraint.sdc
read_spef $::env(OW_SPEF)
set_propagated_clock [all_clocks]

set corner [sta::cmd_corner]
set f [open $::env(OW_OUT) w]
puts $f "net,worst_slack_ns,weight"
set ncrit 0
foreach net [get_nets *] {
  set nm [get_full_name $net]
  set wslk 1e30
  foreach pin [get_pins -quiet -of_objects $net] {
    if {[sta::Pin_is_load $pin]} {
      set s [get_property $pin slack_max]
      if {$s ne "" && $s < $wslk} { set wslk $s }
    }
  }
  if {$wslk > 1e29} { continue }
  set viol [expr {-$wslk / $PERIOD}]
  if {$viol < 0} { set viol 0 }
  if {$viol > 1} { set viol 1 }
  set w [expr {1.0 + $ALPHA * $viol}]
  if {$w > 1.001} { incr ncrit }
  puts $f "$nm,$wslk,$w"
}
close $f
puts "ORACLE_WEIGHTS_DONE ncrit=$ncrit out=$::env(OW_OUT)"
