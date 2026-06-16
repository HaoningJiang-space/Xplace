set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
set DES /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set_thread_count 16
read_db $WORK/db/0_loaded.odb
read_sdc $DES/constraints/ariane.sdc
# hard cap Nesterov iters (diverges ~2680) and target an achievable overflow
gpl::set_nesv_place_iter_cmd 2300
global_placement -density 0.72 -overflow 0.18 -initial_place_max_fanout 200 -pad_left 0 -pad_right 0
puts "GP8_DONE"
set block [ord::get_db_block]
set die [$block getDieArea]
set out 0
foreach inst [$block getInsts] {
  if {[[$inst getMaster] isBlock]} continue
  set loc [$inst getLocation]; set x [lindex $loc 0]; set y [lindex $loc 1]
  if {$x<[$die xMin]||$x>=[$die xMax]||$y<[$die yMin]||$y>=[$die yMax]} { incr out }
}
puts "OUTOFDIE $out"
write_db $WORK/db/gp8.odb
