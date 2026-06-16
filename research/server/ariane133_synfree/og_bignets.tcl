set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
read_db $WORK/db/0_loaded.odb
set block [ord::get_db_block]
set lst {}
foreach net [$block getNets] {
  set fo [llength [$net getITerms]]
  if {$fo>1000} { lappend lst [list $fo [$net getName] [$net getSigType]] }
}
set lst [lsort -integer -decreasing -index 0 $lst]
foreach e $lst { puts "BIGNET fanout=[lindex $e 0] sig=[lindex $e 2] name=[lindex $e 1]" }
