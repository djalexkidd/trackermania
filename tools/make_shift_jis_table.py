# Builds assets/shift_jis.tres, the Shift-JIS (CP932) to Unicode table used by scripts/bms/ShiftJIS.gd
# Usage: python make_shift_jis_table.py
# Each double byte character (lead 0x81~0x9F or 0xE0~0xFC, trail 0x40~0xFC) is a UTF-16 code, little endian, 0 if undefined.
import os

LEADS = list(range(0x81, 0xA0)) + list(range(0xE0, 0xFD))
TRAILS = range(0x40, 0xFD)

table = bytearray()
for lead in LEADS:
    for trail in TRAILS:
        try:
            code = ord(bytes([lead, trail]).decode("cp932"))
        except UnicodeDecodeError:
            code = 0
        table += code.to_bytes(2, "little")

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "shift_jis.tres")
with open(path, "w", encoding="utf-8") as f:
    f.write('[gd_resource type="Resource" format=3]\n\n[resource]\n')
    f.write("metadata/table = PackedByteArray(" + ", ".join(str(b) for b in table) + ")\n")
