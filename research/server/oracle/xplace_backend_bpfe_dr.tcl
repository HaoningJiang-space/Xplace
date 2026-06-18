# bp_fe_top: detailed-route + OpenRCX coupling-aware re-eval of an Xplace placement DEF.
# FIDELITY probe (codex flaw-3 / GR-no-coupling caveat): report GR-estimate TNS and
# DR+OpenRCX(coupling) TNS in the SAME run on the SAME placement+CTS, so the GR->DR delta
# is isolated. bp_fe is the tractable vehicle (ariane DR hangs at TritonRoute init at density 1.0).
set NG /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/nangate45
set DES /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/designs/nangate45/bp_fe_top
set OUT $::env(XP_OUT); file mkdir $OUT
set_thread_count 16
read_lef $NG/lef/NangateOpenCellLibrary.tech.lef
read_lef $NG/lef/NangateOpenCellLibrary.macro.mod.lef
read_lef $NG/lef/fakeram45_512x64.lef
read_lef $NG/lef/fakeram45_64x7.lef
read_lef $NG/lef/fakeram45_64x96.lef
read_liberty $NG/lib/NangateOpenCellLibrary_typical.lib
read_liberty $NG/lib/fakeram45_512x64.lib
read_liberty $NG/lib/fakeram45_64x7.lib
read_liberty $NG/lib/fakeram45_64x96.lib
read_def $::env(XP_DEF)
source $DES/constraint.sdc
source $NG/setRC.tcl
set_propagated_clock [all_clocks]
clock_tree_synthesis -buf_list BUF_X4 -root_buf BUF_X4 -sink_clustering_enable
set_propagated_clock [all_clocks]
detailed_placement
catch { check_placement }
set_routing_layers -signal metal2-metal10 -clock metal2-metal10
# CRITICAL routability fix (validated on ariane R32/R33, ORFS global_route.tcl): reserve 50% layer
# capacity for vias/local routing + congestion-driven GR. WITHOUT this GR over-packs -> DR violation
# explosion (non-converging). Dominant missing piece, more than target_density.
set_global_routing_layer_adjustment metal2-metal10 0.5
global_route -congestion_iterations 30 -verbose
estimate_parasitics -global_routing
puts "BPFE_GR_WNS [sta::worst_slack -max]"
puts "BPFE_GR_TNS [sta::total_negative_slack -max]"
# --- detailed route + OpenRCX coupling-aware extraction ---
# restrict to metal2-metal10 (ORFS NanGate45 MIN/MAX_ROUTING_LAYER) — metal1 reserved for pins;
# including it inflates DR violations (and on large designs hangs pin-query init).
if {[catch { detailed_route -bottom_routing_layer metal2 -top_routing_layer metal10 -verbose 1 } drmsg]} { puts "DRT_FAIL $drmsg" }
define_process_corner -ext_model_index 0 X
extract_parasitics -ext_model_file $NG/rcx_patterns.rules
# CRITICAL (ariane R33, ORFS final_report.tcl): extract_parasitics writes into the DB but STA keeps the
# stale GR-estimated parasitics until the SPEF is written AND read back. WITHOUT write_spef+read_spef
# the BPFE_DR_TNS == BPFE_GR_TNS exactly (the inert-extraction bug that masks coupling -> 失真).
write_spef $OUT/$::env(XP_TAG).spef
read_spef $OUT/$::env(XP_TAG).spef
puts "BPFE_DR_WNS [sta::worst_slack -max]"
puts "BPFE_DR_TNS [sta::total_negative_slack -max]"
write_db $OUT/$::env(XP_TAG)_routed.odb
puts "BACKEND_BPFE_DR_DONE"
