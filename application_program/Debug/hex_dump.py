"""
hex_dump.py — Convert raw bytes to a readable hex + ASCII display.

Usage:
    python3 hex_dump.py <file.bin>

Or import and call hex_dump() directly in your own script.
"""

import sys


def hex_dump(data: bytes, bytes_per_row: int = 16) -> None:
    """
    Print raw bytes as a hex dump with ASCII representation.

    Output format:
    OFFSET    00 11 22 33 44 55 66 77  88 99 AA BB CC DD EE FF    |ASCII....ASCII..|

    Args:
        data          : raw bytes to display
        bytes_per_row : how many bytes per row (default 16)
    """
    for row_start in range(0, len(data), bytes_per_row):
        row = data[row_start : row_start + bytes_per_row]

        # 1. Offset column
        offset_str = f"{row_start:08X}"

        # 2. Hex columns — split into two groups of 8 for readability
        left  = row[:8]
        right = row[8:]
        hex_left  = " ".join(f"{b:02X}" for b in left)
        hex_right = " ".join(f"{b:02X}" for b in right)

        # Pad shorter last row so ASCII column always lines up
        hex_left  = hex_left.ljust(8 * 3 - 1)
        hex_right = hex_right.ljust(8 * 3 - 1)

        # 3. ASCII column — printable chars shown as-is, everything else as '.'
        #    Printable ASCII range: 0x20 (space) to 0x7E (~)
        ascii_str = "".join(chr(b) if 32 <= b < 127 else "." for b in row)

        print(f"{offset_str}  {hex_left}  {hex_right}  |{ascii_str}|")


def find_strings(data: bytes, min_length: int = 5) -> None:
    """
    Scan raw bytes and print any embedded ASCII strings longer than min_length.
    Useful for spotting format strings, error messages, version info, etc.
    """
    current = []
    for i, b in enumerate(data):
        if 32 <= b < 127:
            current.append((i, chr(b)))
        else:
            if len(current) >= min_length:
                addr   = current[0][0]
                string = "".join(c for _, c in current)
                print(f"  0x{addr:04X}: \"{string}\"")
            current = []


# ── CLI ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 hex_dump.py <file.bin> [num_bytes]")
        print("       num_bytes: how many bytes to dump (default: all)")
        sys.exit(0)

    path = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else None

    with open(path, "rb") as f:
        data = f.read(limit) if limit else f.read()

    print(f"File : {path}")
    print(f"Size : {len(data)} bytes\n")

    hex_dump(data)

    print("\n=== Embedded ASCII strings (length >= 5) ===")
    find_strings(data)
