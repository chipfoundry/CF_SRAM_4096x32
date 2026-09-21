# Signoff evidence

Reports in this directory were produced against the v1.0.3 delivered GDS:

- SHA-256: `e3b8245151791d824f638a68ca68adcad369ecfecfe9fa97a3d8c7a0eb172499`
- Top cell: `CF_SRAM_4096x32`
- SKY130 KLayout runset: mpw-precheck release `2024.2.11_01.09`
- DRC result: 0 violations

`drc/logs/klayout_drc_check.log` is the complete run log,
`drc/logs/klayout_drc_check.total` contains the violation count, and
`drc/outputs/reports/klayout_drc_check.xml` is the KLayout report database.

Regression checks that do not require a PDK are run by `make verify`.
