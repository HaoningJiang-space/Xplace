# og_flow.tcl : synthesis-free + fixed-macro PnR for ariane133 (TILOS ASAP7 1x).
# Produces placed odb (pre-route) and routed odb + SPEF.
set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
set DB   $WORK/db
set LOG  $WORK/logs
source $WORK/scripts/og_setup.tcl
set DES /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set NLDIR $DES/scripts/OpenROAD/ariane133

set NCORES 16
if {[info exists ::env(OG_NUMCORES)]} { set NCORES $::env(OG_NUMCORES) }
set_thread_count $NCORES

puts "=== read_verilog + link ==="
# ariane.v is Genus-synthesized: instantiates sram_asap7_16x256_1rw directly (133x).
# macros.v is the pre-synth RTL wrapper (SyncSpRam) and is NOT referenced -> skip it.
read_verilog $NLDIR/ariane.v
link_design ariane

puts "=== read_def -floorplan (die + 133 macro placement + pins) ==="
read_def -floorplan $DES/def/ariane_fp_placed_macros.def

puts "=== read_sdc ==="
read_sdc $DES/constraints/ariane.sdc

# report db basics
set block [ord::get_db_block]
puts "INSTCOUNT [llength [$block getInsts]]"
set nmac 0
foreach inst [$block getInsts] { if {[[$inst getMaster] isBlock]} { incr nmac } }
puts "MACROCOUNT $nmac"
puts "NETCOUNT [llength [$block getNets]]"

# fix macros (they are placed from DEF) so placement keeps them put
foreach inst [$block getInsts] {
  if {[[$inst getMaster] isBlock]} { $inst setPlacementStatus FIRM }
}
puts "=== macros set FIRM ==="

write_db $DB/0_loaded.odb
puts "WROTE 0_loaded.odb"
