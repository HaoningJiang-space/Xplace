# og_pnr2.tcl : full PnR with macro halos (keepout) so std cells don't block SRAM pins.
set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
set DB   $WORK/db
set DES  /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set RCX  /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/asap7/rcx_patterns.rules
source $WORK/scripts/og_setup.tcl
set NCORES 16
if {[info exists ::env(OG_NUMCORES)]} { set NCORES $::env(OG_NUMCORES) }
set_thread_count $NCORES
read_db $DB/0_loaded.odb
read_sdc $DES/constraints/ariane.sdc
source $WORK/scripts/og_setrc_asap7.tcl

# --- macro keepout halo: 2um around each macro so std cells don't crowd M4 pins ---
set block [ord::get_db_block]
set dbu [$block getDbUnitsPerMicron]
set halo [expr {int(2.0*$dbu)}]
set nh 0
foreach inst [$block getInsts] {
  if {![[$inst getMaster] isBlock]} continue
  set bb [$inst getBBox]
  set x0 [expr {[$bb xMin]-$halo}]; set y0 [expr {[$bb yMin]-$halo}]
  set x1 [expr {[$bb xMax]+$halo}]; set y1 [expr {[$bb yMax]+$halo}]
  # placement blockage ring (just create one covering halo box; macro itself is fixed)
  set blk [odb::dbBlockage_create $block $x0 $y0 $x1 $y1]
  incr nh
}
puts "HALO created $nh macro placement blockages (2um)"

puts "=== GLOBAL PLACEMENT ==="
gpl::set_nesv_place_iter_cmd 2300
global_placement -density 0.72 -overflow 0.18 -initial_place_max_fanout 200 -pad_left 0 -pad_right 0
puts "GP_DONE"
estimate_parasitics -placement

puts "=== DETAILED PLACEMENT ==="
set_placement_padding -global -left 0 -right 0
detailed_placement
if {[catch {check_placement -verbose} e]} { puts "CHECK_PLACE_WARN $e" }
puts "DP_DONE"
write_db $DB/1_placed.odb
puts "WROTE 1_placed.odb"

puts "=== CTS ==="
set cts_ok 1
if {[catch { clock_tree_synthesis -buf_list {BUFx4_ASAP7_75t_R BUFx8_ASAP7_75t_R BUFx10_ASAP7_75t_R} -root_buf BUFx4_ASAP7_75t_R -sink_clustering_enable } err]} {
  puts "CTS_FAILED: $err"; set cts_ok 0
}
if {$cts_ok} { set_propagated_clock [all_clocks]; detailed_placement; puts "CTS_DONE" }
estimate_parasitics -placement
write_db $DB/2_cts.odb
puts "WROTE 2_cts.odb"

# fix tie nets BEFORE routing
set fixed 0
foreach net [$block getNets] {
  set st [$net getSigType]
  if {($st eq "POWER" || $st eq "GROUND") && ![$net isSpecial]} { $net setSigType SIGNAL; incr fixed }
}
puts "TIEFIX $fixed"

puts "=== GLOBAL ROUTE ==="
set_routing_layers -signal M2-M7 -clock M2-M7
global_route -allow_congestion -congestion_iterations 50
puts "GR_DONE"
write_db $DB/3_groute.odb
puts "WROTE 3_groute.odb"

puts "=== DETAILED ROUTE ==="
detailed_route -output_drc $WORK/logs/route_drc.rpt -bottom_routing_layer M2 -top_routing_layer M7 -verbose 1 -droute_end_iter 5
puts "DR_DONE"
write_db $DB/4_routed.odb
puts "WROTE 4_routed.odb"

puts "=== OPENRCX SPEF ==="
if {[file exists $RCX]} { define_process_corner -ext_model_index 0 X; extract_parasitics -ext_model_file $RCX } else { extract_parasitics }
write_spef $DB/ariane_routed.spef
puts "WROTE_SPEF ariane_routed.spef"
read_spef $DB/ariane_routed.spef
set wns [sta::worst_slack -max]; set tns [sta::total_negative_slack -max]
puts "ROUTED_WNS $wns ROUTED_TNS $tns"
