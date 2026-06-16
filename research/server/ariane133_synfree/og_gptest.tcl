set WORK /data/ziheng/wzh/oracle_gate/ariane133_synfree
source $WORK/scripts/og_setup.tcl
set DES /data/ziheng/wzh/MacroPlacement/Flows/ASAP7/ariane133
set_thread_count 16
read_db $WORK/db/0_loaded.odb
read_sdc $DES/constraints/ariane.sdc
source $WORK/scripts/og_setrc_asap7.tcl
global_placement -routability_driven -density 0.72 -pad_left 1 -pad_right 1 \
  -init_density_penalty 0.0008 -routability_check_overflow 0.15
puts "GP_DONE_TEST"
