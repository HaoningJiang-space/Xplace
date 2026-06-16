set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
set DES /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set_thread_count 16
read_db $WORK/db/0_loaded.odb
read_sdc $DES/constraints/ariane.sdc
set block [ord::get_db_block]
# Disconnect huge-degree nets from GPL view: detach iterms of nets with fanout>1500,
# remember them, GP, then reconnect. This stops GPL chasing meaningless tie/clk wirelength.
set saved {}
foreach net [$block getNets] {
  set its [$net getITerms]
  if {[llength $its] > 1500} {
    set nm [$net getName]
    puts "DETACH net=$nm fo=[llength $its] sig=[$net getSigType]"
    foreach it $its { lappend saved [list [$it getInst] [$it getMTerm] $nm]; $it disconnect }
  }
}
puts "DETACHED [llength $saved] iterms"
global_placement -density 0.72 -pad_left 1 -pad_right 1
puts "GP4_DONE"
# reconnect
foreach e $saved {
  set inst [lindex $e 0]; set mt [lindex $e 1]; set nm [lindex $e 2]
  set net [$block findNet $nm]
  set it [$inst findITerm [$mt getName]]
  if {$it ne "NULL" && $net ne "NULL"} { $it connect $net }
}
puts "RECONNECTED"
write_db $WORK/db/gp4.odb
