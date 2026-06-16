set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
set DES /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set_thread_count 16
read_db $WORK/db/0_loaded.odb
read_sdc $DES/constraints/ariane.sdc
# mark clk as clock so GPL/CTS treat it right; do NOT source setRC before GP
global_placement -density 0.75 -pad_left 1 -pad_right 1
puts "GP2_DONE"
set block [ord::get_db_block]
# check if cells stayed in core
set out 0
set die [$block getDieArea]
foreach inst [$block getInsts] {
  if {[[$inst getMaster] isBlock]} continue
  set loc [$inst getLocation]
  set x [lindex $loc 0]; set y [lindex $loc 1]
  if {$x<[$die xMin]||$x>[$die xMax]||$y<[$die yMin]||$y>[$die yMax]} { incr out }
}
puts "OUTOFDIE $out"
write_db $WORK/db/gp2.odb
