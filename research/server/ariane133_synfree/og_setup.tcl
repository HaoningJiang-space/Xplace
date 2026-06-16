# og_setup.tcl : load TILOS ASAP7 (1x) enablement + ariane133 netlist + placed-macro DEF.
# Self-consistent: TILOS 2020 enablement (1x) + TILOS netlist + TILOS DEF.
set MP   /data/ziheng/wzh/MacroPlacement
set ENL  $MP/Enablements/ASAP7
set DES  $MP/Flows/ASAP7/ariane133
set LEFDIR $ENL/lef
set LIBDIR $ENL/lib

# --- liberty (FF corner, RVT) + sram ---
set LIBS [list \
  $LIBDIR/asap7sc7p5t_AO_RVT_FF_nldm_201020.lib \
  $LIBDIR/asap7sc7p5t_INVBUF_RVT_FF_nldm_201020.lib \
  $LIBDIR/asap7sc7p5t_OA_RVT_FF_nldm_201020.lib \
  $LIBDIR/asap7sc7p5t_SEQ_RVT_FF_nldm_201020.lib \
  $LIBDIR/asap7sc7p5t_SIMPLE_RVT_FF_nldm_201020.lib \
  $LIBDIR/sram_asap7_16x256_1rw.lib ]
foreach l $LIBS { read_liberty $l }

# --- LEF: tech 1x then sc 1x then sram (1x scale, matches DEF site 0.054) ---
read_lef $LEFDIR/asap7_tech_1x_201209.lef
read_lef $LEFDIR/asap7sc7p5t_27_R_1x_201211.lef
read_lef $LEFDIR/sram_asap7_16x256_1rw.lef
