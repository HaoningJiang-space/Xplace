set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
set DES /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set_thread_count 16
read_db $WORK/db/gp7.odb
read_sdc $DES/constraints/ariane.sdc
set_placement_padding -global -left 0 -right 0
if {[catch {detailed_placement} err]} { puts "DP_ERR $err" }
if {[catch {check_placement -verbose} err]} { puts "CHECK_ERR $err" }
puts "DPTEST_DONE"
write_db $WORK/db/dptest.odb
