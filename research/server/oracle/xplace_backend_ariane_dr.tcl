# ariane detailed-route + OpenRCX (coupling) re-eval of an Xplace placement DEF (FIDELITY test, R24 flaw3)
set NG /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/nangate45
set DES /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/designs/nangate45/ariane133
set OUT $::env(XP_OUT); file mkdir $OUT
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
clock_tree_synthesis -buf_list BUF_X4 -root_buf BUF_X4 -sink_clustering_enable
set_propagated_clock [all_clocks]
detailed_placement
catch { check_placement }
set_routing_layers -signal metal2-metal10 -clock metal2-metal10
# CRITICAL routability fix (ORFS global_route.tcl): reserve 50% layer capacity for vias/local routing
# + congestion-driven GR. WITHOUT this my GR over-packs nets -> DR violation explosion (580k vs ORFS
# 83k, non-converging). This is the dominant missing piece, more than target_density.
set_global_routing_layer_adjustment metal2-metal10 0.5
global_route -congestion_iterations 30 -verbose
estimate_parasitics -global_routing
puts "DROUTE_GR_TNS [sta::total_negative_slack -max]"
# --- detailed route + OpenRCX coupling-aware extraction ---
# CRITICAL: restrict to metal2-metal10 (ORFS NanGate45 MIN/MAX_ROUTING_LAYER). Omitting these lets
# DR include metal1 -> huge metal1 guide-region pin-query -> DETERMINISTIC HANG at "Init gr pin query"
# on the large ariane design (ORFS does init in 37s WITH the restriction; my omission hung 3h+).
if {[catch { detailed_route -bottom_routing_layer metal2 -top_routing_layer metal10 -verbose 1 } drmsg]} { puts "DRT_FAIL $drmsg" }
define_process_corner -ext_model_index 0 X
extract_parasitics -ext_model_file $NG/rcx_patterns.rules
# CRITICAL (ORFS final_report.tcl): extract_parasitics writes into the DB but STA keeps the stale
# GR-estimated parasitics until the SPEF is written AND read back. WITHOUT write_spef+read_spef the
# DROUTE_DR_TNS == DROUTE_GR_TNS exactly (the bug that made the coupling extraction look inert).
write_spef $OUT/$::env(XP_TAG).spef
read_spef $OUT/$::env(XP_TAG).spef
puts "DROUTE_DR_WNS [sta::worst_slack -max]"
puts "DROUTE_DR_TNS [sta::total_negative_slack -max]"
# persist the routed DB so future timing checks need not re-route
write_db $OUT/$::env(XP_TAG)_routed.odb
puts "BACKEND_DR_DONE"
