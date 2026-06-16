# og_pnr.tcl : full PnR from loaded odb. macros FIRM. -> placed odb + routed odb + SPEF.
set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
set DB   $WORK/db
source $WORK/scripts/og_setup.tcl
set DES /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set RCX /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/asap7/rcx_patterns.rules

set NCORES 16
if {[info exists ::env(OG_NUMCORES)]} { set NCORES $::env(OG_NUMCORES) }
set_thread_count $NCORES

read_db $DB/0_loaded.odb
read_sdc $DES/constraints/ariane.sdc

set MINL M2
set MAXL M7

# ---- the set_wire_rc fix (so STA during flow has nonzero RC) ----
source $WORK/scripts/og_setrc_asap7.tcl

# ---- IO pin placement (pins from DEF are already placed; ensure legal) ----
# pins already in floorplan DEF; skip place_pins to keep DEF-consistent pin locs.

# ---- global placement (macros FIRM => stay put) ----
# NOTE: this 226x226um die is ~69% filled (133 macros + std). The huge clk_i net
# (19940 fanout) destabilizes initial QP -> Nesterov diverges (GPL-0305) at the
# achievable overflow floor (~0.14). Fix: cap initial-place fanout + set an
# achievable -overflow target + hard nesv-iter cap. Converges cleanly ~iter 490.
puts "=== GLOBAL PLACEMENT ==="
gpl::set_nesv_place_iter_cmd 2300
global_placement -density 0.72 -overflow 0.18 -initial_place_max_fanout 200 \
  -pad_left 0 -pad_right 0
puts "GP_DONE"

# ---- estimate parasitics + report after GP ----
estimate_parasitics -placement

# ---- detailed placement (legalize std cells) ----
puts "=== DETAILED PLACEMENT ==="
set_placement_padding -global -left 0 -right 0
detailed_placement
if {[catch {check_placement -verbose} cperr]} { puts "CHECK_PLACE_WARN $cperr" }
puts "DP_DONE"

write_db $DB/1_placed.odb
puts "WROTE 1_placed.odb"

# ---- CTS ----
puts "=== CLOCK TREE SYNTHESIS ==="
set cts_ok 1
if {[catch {
  clock_tree_synthesis -buf_list {BUFx4_ASAP7_75t_R BUFx8_ASAP7_75t_R BUFx10_ASAP7_75t_R} \
    -root_buf BUFx4_ASAP7_75t_R -sink_clustering_enable
} err]} {
  puts "CTS_FAILED: $err  -- proceeding with SDC ideal clocks"
  set cts_ok 0
}
if {$cts_ok} {
  set_propagated_clock [all_clocks]
  detailed_placement
  puts "CTS_DONE"
}
estimate_parasitics -placement
write_db $DB/2_cts.odb
puts "WROTE 2_cts.odb"

# ---- global route ----
puts "=== GLOBAL ROUTE ==="
set_routing_layers -signal $MINL-$MAXL -clock $MINL-$MAXL
global_route -allow_congestion -congestion_iterations 50
puts "GR_DONE"
write_db $DB/3_groute.odb
puts "WROTE 3_groute.odb"

# ---- detailed route ----
puts "=== DETAILED ROUTE ==="
detailed_route -output_drc $WORK/logs/route_drc.rpt -bottom_routing_layer $MINL \
  -top_routing_layer $MAXL -verbose 1 -droute_end_iter 5
puts "DR_DONE"
write_db $DB/4_routed.odb
puts "WROTE 4_routed.odb"

# ---- OpenRCX parasitic extraction -> SPEF ----
puts "=== OPENRCX SPEF ==="
if {[file exists $RCX]} {
  define_process_corner -ext_model_index 0 X
  extract_parasitics -ext_model_file $RCX
} else {
  extract_parasitics
}
write_spef $WORK/db/ariane_routed.spef
puts "WROTE_SPEF ariane_routed.spef"

# ---- final timing ----
read_spef $WORK/db/ariane_routed.spef
set wns [sta::worst_slack -max]
set tns [sta::total_negative_slack -max]
puts "ROUTED_WNS $wns ROUTED_TNS $tns"
