set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
set DES /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set_thread_count 16
read_db $WORK/db/0_loaded.odb
read_sdc $DES/constraints/ariane.sdc
# initial QP place only (no Nesterov) -> never diverges; rough but valid spread
global_placement -skip_nesterov_place -density 0.72
puts "GP7_DONE"
# how spread / out of die?
set block [ord::get_db_block]
set die [$block getDieArea]
set out 0
foreach inst [$block getInsts] {
  if {[[$inst getMaster] isBlock]} continue
  set loc [$inst getLocation]; set x [lindex $loc 0]; set y [lindex $loc 1]
  if {$x<[$die xMin]||$x>=[$die xMax]||$y<[$die yMin]||$y>=[$die yMax]} { incr out }
}
puts "OUTOFDIE $out"
write_db $WORK/db/gp7.odb
