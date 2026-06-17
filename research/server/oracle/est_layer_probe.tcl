# Fair-est probe: re-estimate placement criticality with a LESS pessimistic signal layer.
# Tests if the ariane est-vs-routed divergence (R27) shrinks under a fairer layer assumption.
set NG /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/nangate45
set DES /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/designs/nangate45/ariane133
set LAYER $::env(EST_LAYER)
read_lef $NG/lef/NangateOpenCellLibrary.tech.lef
read_lef $NG/lef/NangateOpenCellLibrary.macro.mod.lef
read_lef $NG/lef/fakeram45_256x16.lef
read_liberty $NG/lib/NangateOpenCellLibrary_typical.lib
read_liberty $NG/lib/fakeram45_256x16.lib
read_def /data/ziheng/wzh/bridge/ar_base_ariane_dp.def
source $DES/ariane.sdc
# fair-layer RC (per-layer values from setRC.tcl), signal on $LAYER instead of metal3
source $NG/setRC.tcl
set_wire_rc -signal -layer $LAYER
set_propagated_clock [all_clocks]
estimate_parasitics -placement
puts "EST_${LAYER}_WNS [sta::worst_slack -max]"
puts "EST_${LAYER}_TNS [sta::total_negative_slack -max]"
set f [open /data/ziheng/wzh/bridge/ar_est_${LAYER}_netslack.csv w]; puts $f "net,worst_slack_ns"
foreach net [get_nets *] { set nm [get_full_name $net]; set wslk 1e30
  foreach pin [get_pins -quiet -of_objects $net] {
    if {[sta::Pin_is_load $pin]} { set s [get_property $pin slack_max]
      if {$s ne "" && $s < $wslk} { set wslk $s } } }
  if {$wslk < 1e29} { puts $f "$nm,$wslk" } }
close $f
puts "EST_LAYER_DONE"
