set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
set DES /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set_thread_count 16
read_db $WORK/db/0_loaded.odb
read_sdc $DES/constraints/ariane.sdc
# higher density penalty => damped Nesterov steps, avoids newStepLength divergence
global_placement -density 0.70 -pad_left 1 -pad_right 1 -init_density_penalty 0.005
puts "GP5_DONE"
write_db $WORK/db/gp5.odb
