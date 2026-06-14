"""
STM32 CRC Calculator
Implements the algorithm from Figure 2 (MS31648V1) exactly:

  Crc = Initial_Crc ^ Input_Data
  for bindex in range(sizeof(Input_Data) * 8):
      if MSB of Crc == 1:
          Crc = (Crc << 1) ^ POLY
      else:
          Crc = Crc << 1

Matches the STM32 hardware CRC peripheral (32-bit, MSB-first, poly=0x04C11DB7).
"""

import struct
import sys

# STM32 CRC peripheral defaults
POLY         = 0x04C11DB7
INITIAL_CRC  = 0xFFFFFFFF
MASK         = 0xFFFFFFFF  # keep results 32-bit wide


def crc32_word(crc: int, word: int) -> int:
    """
    Process a single 32-bit word through the flowchart algorithm.

    Step 1  : Crc = Crc ^ Input_Data
    Step 2  : Loop sizeof(uint32_t)*8 = 32 times:
                  if MSB == 1 → Crc = (Crc << 1) ^ POLY
                  else        → Crc = Crc << 1
    """
    crc = (crc ^ word) & MASK

    bindex = 0

    while True:
        if crc & 0x80000000:
            crc = ((crc << 1) ^ POLY) & MASK
        else:
            crc = (crc << 1) & MASK

        bindex += 1

        if bindex >= 32:   # sizeof(uint32_t)->4 * 8 = 32
            break          # NO → Return Crc

    return crc


def crc32_buffer(data: bytes, initial: int = INITIAL_CRC) -> int:
    """
    Calculate CRC over an entire byte buffer.

    The STM32 hardware CRC unit consumes data as 32-bit words.
    If the buffer length is not a multiple of 4, the last partial
    word is zero-padded on the right (matching hardware behaviour).
    """
    crc = initial

    # Pad to a multiple of 4 bytes
    remainder = len(data) % 4
    if remainder:
        data = data + b'\x00' * (4 - remainder)

    # Process each 32-bit word  (big-endian interpretation = MSB-first)
    num_words = len(data) // 4
    for i in range(num_words):
        # STM32 hardware feeds words little-endian (LSB first)
        word, = struct.unpack_from('<I', data, i * 4)
        crc = crc32_word(crc, word)

    return crc


def crc32_file(path: str) -> tuple[int, int]:
    """Read a binary file and return (crc, file_size_bytes)."""
    with open(path, 'rb') as f:
        data = f.read()
    return crc32_buffer(data), len(data)


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Usage: python stm32_crc.py <firmware.bin>")
        print()
        print("Example (single word):")
        demo_word = 0xAB46FF23
        result = crc32_word(INITIAL_CRC, demo_word)
        print(f"  Input : 0x{demo_word:08X}")
        print(f"  CRC   : 0x{result:08X}")
        return

    path = sys.argv[1]
    try:
        crc, size = crc32_file(path)
        print(f"File    : {path}")
        print(f"Size    : {size} bytes ({size // 4} words{', +' + str(size % 4) + ' byte(s) padded' if size % 4 else ''})")
        print(f"CRC-32  : 0x{crc:08X}")
    except FileNotFoundError:
        print(f"Error: file not found: {path}")
        sys.exit(1)


if __name__ == "__main__":
    main()
