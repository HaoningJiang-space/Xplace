# Standalone OpenROAD back-end on an Xplace placement DEF.
# Xplace places -> this does CTS + route + SPEF + STA (D_place vs D_route).
# Env: XP_DEF (Xplace placement DEF), XP_OUT (output dir), XP_TAG
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

# ---- D_place: pre-route (placement / Steiner RC estimate) ----
estimate_parasitics -placement
puts "DPLACE_WNS [sta::worst_slack -max]"
puts "DPLACE_TNS [sta::total_negative_slack -max]"

# ---- CTS ----
clock_tree_synthesis -buf_list BUF_X4 -root_buf BUF_X4 -sink_clustering_enable
set_propagated_clock [all_clocks]
estimate_parasitics -placement
# legalize CTS buffers
detailed_placement
check_placement -verbose

# ---- Route ----
set_routing_layers -signal metal2-metal10 -clock metal2-metal10
global_route
detailed_route -bottom_routing_layer metal2 -top_routing_layer metal10 -verbose 0

# ---- Extract SPEF + D_route ----
define_process_corner -ext_model_index 0 X
extract_parasitics -ext_model_file $NG/rcx_patterns.rules
write_spef $OUT/$::env(XP_TAG).spef
read_spef $OUT/$::env(XP_TAG).spef
set_propagated_clock [all_clocks]
puts "DROUTE_WNS [sta::worst_slack -max]"
puts "DROUTE_TNS [sta::total_negative_slack -max]"
set drc [detailed_route_num_drvs]
puts "DRC_VIOLATIONS $drc"
write_def $OUT/$::env(XP_TAG)_routed.def
puts "BACKEND_DONE"
