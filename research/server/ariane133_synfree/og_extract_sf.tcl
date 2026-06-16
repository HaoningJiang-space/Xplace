# og_extract_sf.tcl : synthesis-free per-net + per-arc extraction.
# Env: OG_DB OG_MODE(pre|post) OG_SPEF OG_OUT OG_TAG
set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
set DES  /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set OUT  $::env(OG_OUT)
set TAG  $::env(OG_TAG)
set MODE $::env(OG_MODE)
file mkdir $OUT
source $WORK/scripts/og_setup.tcl
read_db $::env(OG_DB)
read_sdc $DES/constraints/ariane.sdc

set corner [sta::cmd_corner]
set rfR [sta::parse_rise_fall_arg rise]
set rfF [sta::parse_rise_fall_arg fall]

if {$MODE eq "pre"} {
  # ===== THE set_wire_rc FIX : nonzero Steiner-baseline RC =====
  source $WORK/scripts/og_setrc_asap7.tcl
  estimate_parasitics -placement
} elseif {$MODE eq "post"} {
  read_spef $::env(OG_SPEF)
} elseif {$MODE eq "gr"} {
  # ===== GR-based routing-aware RC (no detailed route needed) =====
  source $WORK/scripts/og_setrc_asap7.tcl
  estimate_parasitics -global_routing
} else { error "OG_MODE must be pre|post|gr" }

set fnet [open $OUT/${TAG}_net.csv w]
puts $fnet "net,wire_cap_fF,net_cap_fF,pin_cap_fF,fanout"
set nz 0; set ntot 0; set sumwc 0.0
foreach net [get_nets *] {
  set nm [get_full_name $net]
  set wc 0.0; set nc 0.0; set pc 0.0
  catch { set wc [sta::Net_wire_capacitance $net $corner max] }
  catch { set nc [sta::Net_capacitance      $net $corner max] }
  catch { set pc [sta::Net_pin_capacitance  $net $corner max] }
  set wcf [expr {$wc*1e15}]; set ncf [expr {$nc*1e15}]; set pcf [expr {$pc*1e15}]
  set fo 0
  foreach p [get_pins -quiet -of_objects $net] { if {[sta::Pin_is_load $p]} { incr fo } }
  incr ntot
  if {$wcf > 0} { incr nz }
  set sumwc [expr {$sumwc + $wcf}]
  puts $fnet "$nm,$wcf,$ncf,$pcf,$fo"
}
close $fnet
puts "VERIFY_WIRECAP mode=$MODE nonzero_nets=$nz total_nets=$ntot sum_wirecap_fF=$sumwc"

set block [ord::get_db_block]
set dbu [$block getDbUnitsPerMicron]
set fwl [open $OUT/${TAG}_wirelen.csv w]
puts $fwl "net,routed_len_um,hpwl_um"
foreach net [$block getNets] {
  set nm [$net getName]
  set rl 0.0
  set w [$net getWire]
  if {$w ne "" && $w ne "NULL"} { catch { set rl [expr {[$w getLength]/double($dbu)}] } }
  set xs {}; set ys {}
  foreach it [$net getITerms] { set bb [[$it getInst] getBBox]
    lappend xs [expr {([$bb xMin]+[$bb xMax])/2.0}]; lappend ys [expr {([$bb yMin]+[$bb yMax])/2.0}] }
  foreach bt [$net getBTerms] { foreach bp [$bt getBPins] { set bb [$bp getBBox]
    lappend xs [expr {([$bb xMin]+[$bb xMax])/2.0}]; lappend ys [expr {([$bb yMin]+[$bb yMax])/2.0}] } }
  set hpwl 0.0
  if {[llength $xs]>=2} {
    set xmin [lindex $xs 0]; set xmax $xmin; set ymin [lindex $ys 0]; set ymax $ymin
    foreach x $xs { if {$x<$xmin} {set xmin $x}; if {$x>$xmax} {set xmax $x} }
    foreach y $ys { if {$y<$ymin} {set ymin $y}; if {$y>$ymax} {set ymax $y} }
    set hpwl [expr {(($xmax-$xmin)+($ymax-$ymin))/double($dbu)}]
  }
  puts $fwl "$nm,$rl,$hpwl"
}
close $fwl

set farc [open $OUT/${TAG}_arc.csv w]
puts $farc "net,driver,sink,wire_cap_fF,net_cap_fF,fanout,elmore_r_ps,elmore_f_ps,elmore_max_ps,pi_c2_fF,pi_rpi_ohm,pi_c1_fF,sink_slack_max_ns"
foreach net [get_nets *] {
  set nm [get_full_name $net]
  set drvrs {}; set loads {}
  foreach pin [get_pins -quiet -of_objects $net] {
    if {[sta::Pin_is_driver $pin]} { lappend drvrs $pin }
    if {[sta::Pin_is_load   $pin]} { lappend loads $pin }
  }
  if {[llength $drvrs]==0 || [llength $loads]==0} { continue }
  set wc 0.0; set nc 0.0
  catch { set wc [expr {[sta::Net_wire_capacitance $net $corner max]*1e15}] }
  catch { set nc [expr {[sta::Net_capacitance      $net $corner max]*1e15}] }
  set fo [llength $loads]
  set drvr [lindex $drvrs 0]
  set pic2 ""; set pirpi ""; set pic1 ""
  catch {
    set pi [sta::find_pi_elmore $drvr $rfR max]
    set pic2 [expr {[lindex $pi 0]*1e15}]; set pirpi [lindex $pi 1]; set pic1 [expr {[lindex $pi 2]*1e15}]
  }
  foreach load $loads {
    set er ""; set ef ""; set em ""
    catch { set er [expr {[sta::find_elmore $drvr $load $rfR max]*1e12}] }
    catch { set ef [expr {[sta::find_elmore $drvr $load $rfF max]*1e12}] }
    if {$er ne "" && $ef ne ""} { set em [expr {max($er,$ef)}] }
    set slk ""
    catch { set slk [get_property $load slack_max] }
    puts $farc "$nm,[get_full_name $drvr],[get_full_name $load],$wc,$nc,$fo,$er,$ef,$em,$pic2,$pirpi,$pic1,$slk"
  }
}
close $farc
puts "ARC_DUMP_DONE $OUT/${TAG}_arc.csv"

set wns [sta::worst_slack -max]
set tns [sta::total_negative_slack -max]
set fts [open $OUT/${TAG}_wns_tns.txt w]
puts $fts "WNS_ns $wns"
puts $fts "TNS_ns $tns"
close $fts
puts "WNS_TNS mode=$MODE tag=$TAG WNS=$wns TNS=$tns"
