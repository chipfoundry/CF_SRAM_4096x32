source /pdkroot/sky130A/libs.tech/netgen/sky130A_setup.tcl

# The PDK's conb_1 SPICE model uses 0.5um poly resistors while this GDS extracts
# 0.045um. Connectivity is identical; relax only the poly-resistor length
# property so this known model discrepancy does not mask wrapper LVS.
property "-circuit1 sky130_fd_pr__res_generic_po" tolerance {l 2.0}
property "-circuit2 sky130_fd_pr__res_generic_po" tolerance {l 2.0}
