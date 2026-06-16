# og_rudy.tcl  -- per-net geometry for a simple RUDY / congestion proxy
# Env: OG_LEFS OG_LIBS OG_DB OG_OUT OG_TAG
# RUDY (Rectangular Uniform wire DensitY) proxy computed in python from:
#   net bbox (umin..umax), HPWL, pin count.  rudy = HPWL*min_wire_pitch / bbox_area
set OUT $::env(OG_OUT); set TAG $::env(OG_TAG)
file mkdir $OUT
foreach lib $::env(OG_LIBS) { read_liberty $lib }
foreach lef $::env(OG_LEFS) { read_lef $lef }
read_db $::env(OG_DB)

set block [ord::get_db_block]
set dbu [$block getDbUnitsPerMicron]
set f [open $OUT/${TAG}_rudy.csv w]
puts $f "net,npins,hpwl_um,bbox_w_um,bbox_h_um,bbox_area_um2,rudy"
foreach net [$block getNets] {
  set nm [$net getName]
  set xs {}; set ys {}
  foreach it [$net getITerms] {
    set bb [[$it getInst] getBBox]
    lappend xs [expr {([$bb xMin]+[$bb xMax])/2.0}]
    lappend ys [expr {([$bb yMin]+[$bb yMax])/2.0}]
  }
  foreach bt [$net getBTerms] {
    foreach bp [$bt getBPins] {
      set bb [$bp getBBox]
      lappend xs [expr {([$bb xMin]+[$bb xMax])/2.0}]
      lappend ys [expr {([$bb yMin]+[$bb yMax])/2.0}]
    }
  }
  set n [llength $xs]
  if {$n < 1} { continue }
  set xmin [lindex $xs 0]; set xmax $xmin; set ymin [lindex $ys 0]; set ymax $ymin
  foreach x $xs { if {$x<$xmin} {set xmin $x}; if {$x>$xmax} {set xmax $x} }
  foreach y $ys { if {$y<$ymin} {set ymin $y}; if {$y>$ymax} {set ymax $y} }
  set w [expr {($xmax-$xmin)/double($dbu)}]
  set h [expr {($ymax-$ymin)/double($dbu)}]
  set hpwl [expr {$w+$h}]
  set area [expr {$w*$h}]
  # min metal pitch ~0.14um for nangate45 M1; use a fixed nominal track width
  set track 0.14
  set rudy 0.0
  if {$area > 1e-9} { set rudy [expr {$hpwl*$track/$area}] }
  puts $f "$nm,$n,$hpwl,$w,$h,$area,$rudy"
}
close $f
puts "RUDY_DONE $OUT/${TAG}_rudy.csv"
