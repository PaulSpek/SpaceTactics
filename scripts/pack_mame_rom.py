"""Assemble a user-supplied MAME stactics.zip for the MiSTer OSD loader."""

import argparse
import pathlib
import sys
import zipfile
import zlib


# Sizes and CRC32 values from MAME src/mame/sega/stactics.cpp.
PARTS = (
    ("epr-218x", 0x800, 0xB1186AD2),
    ("epr-219x", 0x800, 0x3B86036D),
    ("epr-220x", 0x800, 0xC58702DA),
    ("epr-221x", 0x800, 0xE327639E),
    ("epr-222y", 0x800, 0x24DD2BCC),
    ("epr-223x", 0x800, 0x7FEF0940),
    ("pr54",     0x800, 0x9640BD6E),
)


def pack(source: pathlib.Path, output: pathlib.Path) -> None:
    with zipfile.ZipFile(source) as archive:
        members = {pathlib.PurePosixPath(n).name.lower(): n for n in archive.namelist()}
        data = bytearray()
        for name, size, expected_crc in PARTS:
            if name not in members:
                raise ValueError(f"Missing {name} in {source}")
            content = archive.read(members[name])
            actual_crc = zlib.crc32(content)
            if len(content) != size or actual_crc != expected_crc:
                raise ValueError(
                    f"{name}: expected {size} bytes, CRC {expected_crc:08x}; "
                    f"got {len(content)} bytes, CRC {actual_crc:08x}"
                )
            data.extend(content)
    output.write_bytes(data)
    print(f"Wrote {len(data)} bytes to {output}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=pathlib.Path, help="User-supplied MAME stactics.zip")
    parser.add_argument("output", type=pathlib.Path, help="Output SpaceTactics.rom")
    args = parser.parse_args()
    try:
        pack(args.source, args.output)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"ROM assembly failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
