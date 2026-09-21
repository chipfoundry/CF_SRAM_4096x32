# Hierarchical LVS

Netgen reports `Final result: Circuits match uniquely.` for the delivered GDS
against the delivered gate-level netlist.

The comparison uses:

- Magic 8.3.471 and Netgen 1.5.272
- the SKY130A PDK at commit `74c0e6b`
- `CF_SRAM_1024x32` as a black box, because its transistor-level source is
  proprietary and is not shipped with this repository
- the PDK standard-cell SPICE models

Two narrowly scoped normalizations are recorded in this directory:

1. Magic names the extracted top-level power ports `VPWR_uq1` and `VGND_uq1`.
   `normalize_lvs_netlist.py` applies those names to a temporary copy of the
   source netlist; it does not modify the delivered gate-level netlist.
2. The PDK `conb_1` SPICE model uses 0.5um poly-resistor lengths while this GDS
   extracts 0.045um. `sky130A_setup.tcl` relaxes only that resistor-length
   property. Device counts, net counts, hierarchy, and connectivity still have
   to match.

`lvs.log` is the Netgen transcript and `lvs.report` is the detailed comparison.
The child black-box pin lists and all wrapper-level nets are included in the
comparison.

Magic also emits obstruction-overlap feedback while building the child-macro
abstract because top-level routes intentionally enter the macro obstruction at
declared pins. The independent SKY130 KLayout DRC and the met1 pin-short
regression cover those geometries.
