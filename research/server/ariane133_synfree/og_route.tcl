# og_route.tcl : resume from 3_groute.odb, fix tie-net sigtypes, detailed route + SPEF.
set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
set DB   $WORK/db
set DES  /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set RCX  /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/asap7/rcx_patterns.rules
source $WORK/scripts/og_setup.tcl
set NCORES 16
if {[info exists ::env(OG_NUMCORES)]} { set NCORES $::env(OG_NUMCORES) }
set_thread_count $NCORES
read_db $DB/3_groute.odb
read_sdc $DES/constraints/ariane.sdc
catch { set_propagated_clock [all_clocks] }

# fix synthesis tie nets (one_/zero_) wrongly typed POWER/GROUND -> SIGNAL (router-routable)
set block [ord::get_db_block]
set fixed 0
foreach net [$block getNets] {
  set st [$net getSigType]
  if {($st eq "POWER" || $st eq "GROUND") && ![$net isSpecial]} {
    $net setSigType SIGNAL; incr fixed
  }
}
puts "TIEFIX set $fixed nets POWER/GROUND -> SIGNAL"

puts "=== DETAILED ROUTE ==="
detailed_route -output_drc $WORK/logs/route_drc.rpt -bottom_routing_layer M2 \
  -top_routing_layer M7 -verbose 1 -droute_end_iter 5
puts "DR_DONE"
write_db $DB/4_routed.odb
puts "WROTE 4_routed.odb"

puts "=== OPENRCX SPEF ==="
if {[file exists $RCX]} {
  define_process_corner -ext_model_index 0 X
  extract_parasitics -ext_model_file $RCX
} else { extract_parasitics }
write_spef $DB/ariane_routed.spef
puts "WROTE_SPEF ariane_routed.spef"

read_spef $DB/ariane_routed.spef
set wns [sta::worst_slack -max]; set tns [sta::total_negative_slack -max]
puts "ROUTED_WNS $wns ROUTED_TNS $tns"

# DRC count
set ndrc 0
if {[file exists $WORK/logs/route_drc.rpt]} {
  set fp [open $WORK/logs/route_drc.rpt r]; set txt [read $fp]; close $fp
  set ndrc [regexp -all -line {violation type} $txt]
}
puts "DRC_VIOLATIONS $ndrc"
