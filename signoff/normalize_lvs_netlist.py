#!/usr/bin/env python3
"""Normalize Magic's extracted top-level supply names for LVS."""

import argparse
import re
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    text = args.source.read_text()
    for pin in ("VPWR", "VGND"):
        # Rename the top-level signal token, but preserve named cell ports such
        # as ".VPWR(...)" and escaped identifiers that contain the same text.
        text = re.sub(
            rf"(?<![.$\\A-Za-z0-9_]){pin}(?![$A-Za-z0-9_])",
            f"{pin}_uq1",
            text,
        )
    args.output.write_text(text)


if __name__ == "__main__":
    main()
