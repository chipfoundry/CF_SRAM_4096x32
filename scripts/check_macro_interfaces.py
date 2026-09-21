#!/usr/bin/env python3
"""Check that every child-macro LEF pin is connected in every GL instance."""

import argparse
import re
from pathlib import Path


def lef_pins(path: Path, macro: str) -> set[str]:
    text = path.read_text()
    match = re.search(
        rf"(?ms)^\s*MACRO\s+{re.escape(macro)}\s*$"
        rf"(.*?)^\s*END\s+{re.escape(macro)}\s*$",
        text,
    )
    if not match:
        raise ValueError(f"{macro} is not defined in {path}")
    return set(re.findall(r"(?m)^\s*PIN\s+(\S+)\s*$", match.group(1)))


def instances(path: Path, macro: str) -> list[tuple[str, set[str]]]:
    text = re.sub(r"/\*.*?\*/|//[^\n]*", "", path.read_text(), flags=re.S)
    pattern = re.compile(
        rf"(?ms)(?<![\w$]){re.escape(macro)}\s+"
        rf"(\\\S+|[A-Za-z_$][\w$]*)\s*\((.*?)\)\s*;"
    )
    found = []
    for match in pattern.finditer(text):
        ports = set(re.findall(r"\.([A-Za-z_$][\w$]*)\s*\(", match.group(2)))
        found.append((match.group(1), ports))
    return found


def port_name(pin: str) -> str:
    """Map a bit-level LEF pin such as DI[7] to its Verilog bus port DI."""
    return re.sub(r"\[\d+\]$", "", pin)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lef", required=True, type=Path)
    parser.add_argument("--netlist", required=True, type=Path)
    parser.add_argument("--macro", default="CF_SRAM_1024x32")
    parser.add_argument("--expected-instances", default=4, type=int)
    args = parser.parse_args()

    lef_pin_names = lef_pins(args.lef, args.macro)
    expected = {port_name(pin).lower(): port_name(pin) for pin in lef_pin_names}
    found = instances(args.netlist, args.macro)
    errors = []

    if len(found) != args.expected_instances:
        errors.append(
            f"found {len(found)} {args.macro} instances; "
            f"expected {args.expected_instances}"
        )

    for name, ports in found:
        actual = {port.lower() for port in ports}
        missing = [expected[key] for key in sorted(expected.keys() - actual)]
        if missing:
            errors.append(f"{name} is missing: {', '.join(missing)}")

    if errors:
        print("Macro-interface check FAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        f"Macro-interface check passed: {len(found)} instances, "
        f"{len(lef_pin_names)} LEF pins represented by "
        f"{len(expected)} connected ports per instance."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
