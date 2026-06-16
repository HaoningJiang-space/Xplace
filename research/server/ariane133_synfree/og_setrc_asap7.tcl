# setRC for TILOS ASAP7 1x : tech-level per-layer R/C reused from ORFS asap7 platform
# (metal stack identical; values are technology-level, lib-generation-independent).
# Liberty units: cap fF, res kOhm.
set_layer_rc -layer M1 -capacitance 1.1368e-01 -resistance 1.3889e-01
set_layer_rc -layer M2 -capacitance 1.3426e-01 -resistance 2.4222e-02
set_layer_rc -layer M3 -capacitance 1.2918e-01 -resistance 2.4222e-02
set_layer_rc -layer M4 -capacitance 1.1396e-01 -resistance 1.6778e-02
set_layer_rc -layer M5 -capacitance 1.3323e-01 -resistance 1.4677e-02
set_layer_rc -layer M6 -capacitance 1.1575e-01 -resistance 1.0371e-02
set_layer_rc -layer M7 -capacitance 1.3293e-01 -resistance 9.6720e-03
set_layer_rc -layer M8 -capacitance 1.1822e-01 -resistance 7.4310e-03
set_layer_rc -layer M9 -capacitance 1.3497e-01 -resistance 6.8740e-03
set_layer_rc -via V1 -resistance 1.72E-02
set_layer_rc -via V2 -resistance 1.72E-02
set_layer_rc -via V3 -resistance 1.72E-02
set_layer_rc -via V4 -resistance 1.18E-02
set_layer_rc -via V5 -resistance 1.18E-02
set_layer_rc -via V6 -resistance 8.20E-03
set_layer_rc -via V7 -resistance 8.20E-03
set_layer_rc -via V8 -resistance 6.30E-03
# signal + clock default routing layers (ASAP7 routes M2..M7)
set_wire_rc -signal -layer M3
set_wire_rc -clock  -layer M5
