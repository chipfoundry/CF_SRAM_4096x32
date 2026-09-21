# CF_SRAM_4096x32

This is a 4096x32 SRAM macro that is built using four 1024x32 SRAM macros. It provides a Wishbone compliant slave interface for easy integration into SoC designs.

## Structure

The 4096x32 SRAM macro consists of:

1. **CF_SRAM_4096x32.v** - The main SRAM macro that instantiates four 1024x32 SRAMs with address decoding and data multiplexing
2. **CF_SRAM_4096x32_wb_wrapper.v** - Wishbone compliant wrapper that provides the bus interface
3. **controllers/ram_controller_wb.v** - Wishbone controller that translates bus transactions to SRAM signals

## Features

- **Capacity**: 4096 words × 32 bits = 16KB
- **Address Width**: 12 bits (4096 = 2^12)
- **Data Width**: 32 bits
- **Interface**: Wishbone compliant slave
- **Byte Enable**: Supports byte-level writes using wbs_sel_i[3:0]
- **Scan Chain**: Child-macro scan circuitry is not exposed by this wrapper

## Address Mapping

The 4096x32 SRAM uses the following address mapping:
- Address bits [11:10]: Select which 1024x32 SRAM macro (00, 01, 10, 11)
- Address bits [9:0]: Word address within each 1024x32 SRAM

## Dependencies

This macro depends on the CF_SRAM_1024x32 macro, which must be available in your design.

## Integration limitations

The hardened Wishbone wrapper ties `WLOFF` low for normal operation and does
not expose it as a top-level pin. Consequently, the wrapper does not support
deep-sleep retention by powering down the periphery, and an integrator cannot
assert wordline-off protection during power-up. Keep the SRAM supplies valid
and do not rely on retention across periphery power-down. Designs that require
these modes must expose and sequence `WLOFF` using the CF_SRAM_1024x32
integration requirements.

The wrapper also ties off the scan/test inputs and does not expose a usable
memory scan chain. The delivered Liberty file characterizes one nominal
process corner and is intended for ordinary STA, not power-aware analysis: it
does not model `VPWR`/`VGND` as `pg_pin` groups. Use the LEF power/ground ports
for physical integration. Multi-corner or power-aware signoff requires
additional characterized views.

## Reproducibility and verification

The hardening configuration is maintained in
[caravel_user_sram_16kb](https://github.com/chipfoundry/caravel_user_sram_16kb/tree/main/openlane/CF_SRAM_4096x32_wb_wrapper).
The v1.0.3 regeneration uses an exact `CF_SRAM_1024x32` blackbox interface.
The previous mismatched stub module caused synthesis to omit `WLOFF`.

Run `make verify` to check that every child-LEF pin is connected on all four
SRAM instances and that no connected met1 shape in the GDS touches two signal
pins on one child instance. The GDS check requires KLayout.