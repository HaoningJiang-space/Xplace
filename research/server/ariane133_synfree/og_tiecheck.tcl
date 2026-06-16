set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
read_db $WORK/db/3_groute.odb
set block [ord::get_db_block]
set npg 0
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} {
    incr npg
    if {$npg<=12} { puts "PGNET name=[$net getName] sig=$st iterms=[llength [$net getITerms]] special=[$net isSpecial]" }
  }
}
puts "TOTAL_PG_SIGTYPE_NETS $npg"
