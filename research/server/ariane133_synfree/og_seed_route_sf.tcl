# og_seed_route_sf.tcl : re-route SAME placement (3_groute.odb, has global routes)
# with given detailed-route seed, write SPEF, dump per-arc routed RC.
# Env: OG_PREROUTE_DB OG_SEED OG_OUT OG_TAG OG_NUMCORES
set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
set DES  /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set RCX  /data/ziheng/wzh/orfs/OpenROAD-flow-scripts/flow/platforms/asap7/rcx_patterns.rules
set OUT $::env(OG_OUT); set TAG $::env(OG_TAG)
file mkdir $OUT
source $WORK/scripts/og_setup.tcl
read_db $::env(OG_PREROUTE_DB)
read_sdc $DES/constraints/ariane.sdc
catch { set_propagated_clock [all_clocks] }
if {[info exists ::env(OG_NUMCORES)]} { set_thread_count $::env(OG_NUMCORES) }

set args [list -output_drc $OUT/${TAG}_drc.rpt -or_seed $::env(OG_SEED) -verbose 1 \
  -droute_end_iter 5 -bottom_routing_layer M2 -top_routing_layer M7]
puts "SEED_ROUTE seed=$::env(OG_SEED) args=$args"
detailed_route {*}$args

if {[file exists $RCX]} {
  define_process_corner -ext_model_index 0 X
  extract_parasitics -ext_model_file $RCX
} else { extract_parasitics }
write_spef $OUT/${TAG}.spef
read_spef  $OUT/${TAG}.spef

set corner [sta::cmd_corner]
set rfR [sta::parse_rise_fall_arg rise]; set rfF [sta::parse_rise_fall_arg fall]
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
  set fo [llength $loads]; set drvr [lindex $drvrs 0]
  set pic2 ""; set pirpi ""; set pic1 ""
  catch { set pi [sta::find_pi_elmore $drvr $rfR max]; set pic2 [expr {[lindex $pi 0]*1e15}]; set pirpi [lindex $pi 1]; set pic1 [expr {[lindex $pi 2]*1e15}] }
  foreach load $loads {
    set er ""; set ef ""; set em ""
    catch { set er [expr {[sta::find_elmore $drvr $load $rfR max]*1e12}] }
    catch { set ef [expr {[sta::find_elmore $drvr $load $rfF max]*1e12}] }
    if {$er ne "" && $ef ne ""} { set em [expr {max($er,$ef)}] }
    set slk ""; catch { set slk [get_property $load slack_max] }
    puts $farc "$nm,[get_full_name $drvr],[get_full_name $load],$wc,$nc,$fo,$er,$ef,$em,$pic2,$pirpi,$pic1,$slk"
  }
}
close $farc
set wns [sta::worst_slack -max]; set tns [sta::total_negative_slack -max]
puts "SEED_DONE tag=$TAG seed=$::env(OG_SEED) WNS=$wns TNS=$tns"
