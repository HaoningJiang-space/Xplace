set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
set DES /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set_thread_count 16
read_db $WORK/db/0_loaded.odb
read_sdc $DES/constraints/ariane.sdc
set block [ord::get_db_block]
# mark clk_i as CLOCK so GPL down-weights it (huge 19940-fanout net diverges GPL)
set cn [$block findNet clk_i]
if {$cn ne "NULL" && $cn ne ""} { $cn setSigType CLOCK; puts "MARKED clk_i CLOCK" }
# also mark the big floating/tie SIGNAL nets that GPL shouldn't chase
foreach nn {issue_stage_i/rs3_valid_iro_sb} {
  set n [$block findNet $nn]; if {$n ne "NULL" && $n ne ""} { puts "found $nn fo=[llength [$n getITerms]]" }
}
global_placement -density 0.75 -pad_left 1 -pad_right 1 -init_density_penalty 0.00008
puts "GP3_DONE"
write_db $WORK/db/gp3.odb
