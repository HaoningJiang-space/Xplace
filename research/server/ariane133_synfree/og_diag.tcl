set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
read_db $WORK/db/0_loaded.odb
set block [ord::get_db_block]
set die [$block getDieArea]
puts "DIE [$die xMin] [$die yMin] [$die xMax] [$die yMax]"
# core box from rows
set rxmin 1e12; set rymin 1e12; set rxmax -1e12; set rymax -1e12
foreach row [$block getRows] {
  set bb [$row getBBox]
  if {[$bb xMin]<$rxmin} {set rxmin [$bb xMin]}
  if {[$bb yMin]<$rymin} {set rymin [$bb yMin]}
  if {[$bb xMax]>$rxmax} {set rxmax [$bb xMax]}
  if {[$bb yMax]>$rymax} {set rymax [$bb yMax]}
}
puts "COREROWS $rxmin $rymin $rxmax $rymax"
# any net with huge fanout?
set maxfo 0; set bignets 0
foreach net [$block getNets] {
  set fo [llength [$net getITerms]]
  if {$fo>$maxfo} {set maxfo $fo}
  if {$fo>1000} {incr bignets}
}
puts "MAXFANOUT $maxfo BIGNETS_gt1000 $bignets"
# instances with no iterms connected (floating)?
set floaters 0
foreach inst [$block getInsts] {
  if {[[$inst getMaster] isBlock]} continue
  set conn 0
  foreach it [$inst getITerms] { if {[$it getNet] ne "NULL" && [$it getNet] ne ""} { incr conn } }
  if {$conn==0} { incr floaters }
}
puts "FLOATING_STDCELLS $floaters"
