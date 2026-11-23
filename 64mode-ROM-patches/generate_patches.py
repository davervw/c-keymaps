#!/usr/bin/env python3
"""Generate 64-mode ROM patch and BASIC DATA files from 64moderom.prg."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


BASIC_ORIGIN = 0xA000
KERNAL_ORIGIN = 0xE000

COPY_RANGE = (0x033C, 0x035C)
BASIC_RANGES = ((0xBF4E, 0xBF70),)
KERNAL_RANGES = ((0xE4B7, 0xE4D2), (0xEA87, 0xEADF))


def read_prg(path: Path) -> tuple[int, bytes]:
    image = path.read_bytes()
    if len(image) < 2:
        raise ValueError(f"{path} is too short to contain a PRG load address")
    load_address = image[0] | (image[1] << 8)
    payload = image[2:]
    if not payload:
        raise ValueError(f"{path} contains no program bytes")
    return load_address, payload


def get_range(load_address: int, payload: bytes, address: int, end_address: int) -> bytes:
    start = address - load_address
    end = end_address - load_address + 1
    if start < 0 or end > len(payload):
        raise ValueError(
            f"address range ${address:04X}-${end_address:04X} "
            f"is outside PRG range ${load_address:04X}-${load_address + len(payload) - 1:04X}"
        )
    return payload[start:end]


def chunks(data: bytes, address: int, size: int = 16):
    for offset in range(0, len(data), size):
        yield address + offset, data[offset:offset + size]


def rom_patch(load_address: int, payload: bytes, origin: int, ranges) -> str:
    lines = []
    for range_address, end_address in ranges:
        data = get_range(load_address, payload, range_address, end_address)
        for address, chunk in chunks(data, range_address):
            relative_address = address - origin
            hex_bytes = " ".join(f"{byte:02x}" for byte in chunk)
            lines.append(f"{relative_address:04x}: {hex_bytes}")
    return "\n".join(lines) + "\n"


def basic_data_patch(load_address: int, payload: bytes) -> str:
    lines = [
        "0 rem rom revisions copyright (c) 2026",
        "1 rem by david r. van wagner",
        "2 rem davevw.com github.com/davervw/c-keymaps",
        "3 :",
    ]

    copy_address, copy_end = COPY_RANGE
    copy_data = get_range(load_address, payload, copy_address, copy_end)
    line_number = 4
    for address, chunk in chunks(copy_data, copy_address):
        hex_bytes = " ".join(f"{byte:02x}" for byte in chunk)
        lines.append(f'{line_number} data "{address:04x}: {hex_bytes}"')
        line_number += 1

    lines.extend(["7 data \"*\"", "8 :"])

    basic_address, basic_end = BASIC_RANGES[0]
    basic_data = get_range(load_address, payload, basic_address, basic_end)
    for line_number, (address, chunk) in zip(
        (10, 15, 16),
        chunks(basic_data, basic_address),
    ):
        hex_bytes = " ".join(f"{byte:02x}" for byte in chunk)
        lines.append(f'{line_number} data "{address:04x}: {hex_bytes}"')

    lines.append("20 :")
    kernal_first_address, kernal_first_end = KERNAL_RANGES[0]
    kernal_first = get_range(
        load_address, payload, kernal_first_address, kernal_first_end
    )
    for line_number, (address, chunk) in zip(
        (25, 30),
        chunks(kernal_first, kernal_first_address),
    ):
        hex_bytes = " ".join(f"{byte:02x}" for byte in chunk)
        lines.append(f'{line_number} data "{address:04x}: {hex_bytes}"')

    lines.append("35 :")
    kernal_address, kernal_end = KERNAL_RANGES[1]
    kernal_data = get_range(load_address, payload, kernal_address, kernal_end)
    for line_number, (address, chunk) in zip(
        (40, 45, 50, 55, 60, 65),
        chunks(kernal_data, kernal_address),
    ):
        hex_bytes = " ".join(f"{byte:02x}" for byte in chunk)
        lines.append(f'{line_number} data "{address:04x}: {hex_bytes}"')

    lines.extend(["70 data \"\"", "71 :"])
    return "\n".join(lines).lower() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("prg", nargs="?", type=Path, default=Path("64moderom.prg"))
    parser.add_argument("--directory", type=Path)
    args = parser.parse_args()

    directory = args.directory or Path(__file__).resolve().parent
    prg_path = args.prg if args.prg.is_absolute() else directory / args.prg

    try:
        load_address, payload = read_prg(prg_path)

        basic_patch = rom_patch(load_address, payload, BASIC_ORIGIN, BASIC_RANGES)
        kernal_patch = rom_patch(load_address, payload, KERNAL_ORIGIN, KERNAL_RANGES)
        data_patch = basic_data_patch(load_address, payload)

        (directory / "64mode-BASIC-ROM-patch.txt").write_text(
            basic_patch, encoding="ascii", newline="\n"
        )
        (directory / "64mode-KERNAL-ROM-patch.txt").write_text(
            kernal_patch, encoding="ascii", newline="\n"
        )
        (directory / "64mode-part1.basic.txt").write_text(
            data_patch, encoding="ascii", newline="\n"
        )
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
