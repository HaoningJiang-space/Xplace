set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
read_db $WORK/db/0_loaded.odb
set block [ord::get_db_block]
set die [$block getDieArea]
puts "DIE [$die xMin] [$die yMin] [$die xMax] [$die yMax]"
puts "ROWS [llength [$block getRows]]"
puts "BTERMS [llength [$block getBTerms]]"
# sample macro placement
set n 0
foreach inst [$block getInsts] {
  if {[[$inst getMaster] isBlock]} {
    set loc [$inst getLocation]
    puts "MACRO [$inst getName] [lindex $loc 0] [lindex $loc 1] status=[$inst getPlacementStatus]"
    incr n
    if {$n>=3} break
  }
}
# count placed std cells (should be unplaced before GP)
set placed 0; set unplaced 0
foreach inst [$block getInsts] {
  if {![[$inst getMaster] isBlock]} {
    if {[$inst isPlaced]} { incr placed } else { incr unplaced }
  }
}
puts "STDCELLS placed=$placed unplaced=$unplaced"
