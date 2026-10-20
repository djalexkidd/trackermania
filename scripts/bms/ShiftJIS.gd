extends RefCounted
class_name ShiftJIS

# Text of the BMS files: Shift-JIS (CP932) like on Japanese Windows, or UTF-8 for the recent ones.
# The table comes from tools/make_shift_jis_table.py.

const TABLE_PATH : String = "res://assets/shift_jis.tres"
const TRAILS : int = 0xFD - 0x40

static var table : PackedByteArray = []

# Decode bytes read as Latin-1 (one character per byte, see get_string_from_ascii)
static func decode(raw : String) -> String:
	var bytes : PackedByteArray = []
	bytes.resize(raw.length())
	var ascii : bool = true
	for k in raw.length():
		bytes[k] = raw.unicode_at(k) & 0xFF
		ascii = ascii and bytes[k] < 0x80
	if ascii:
		return raw
	if isUtf8(bytes):
		return bytes.get_string_from_utf8()
	return decodeBytes(bytes)

static func decodeBytes(bytes : PackedByteArray) -> String:
	if table.is_empty():
		table = load(TABLE_PATH).get_meta("table")
	var result : String = ""
	var k : int = 0
	while k < bytes.size():
		var b : int = bytes[k]
		var index : int = -1
		if (b >= 0x81 and b <= 0x9F) or (b >= 0xE0 and b <= 0xFC):
			if k + 1 < bytes.size() and bytes[k + 1] >= 0x40 and bytes[k + 1] <= 0xFC:
				var lead : int = b - 0x81 if b <= 0x9F else b - 0xE0 + 0x1F
				index = (lead * TRAILS + bytes[k + 1] - 0x40) * 2
			k += 1
		if index >= 0:
			var code : int = table[index] | table[index + 1] << 8
			result += char(code) if code != 0 else "?"
		elif b >= 0xA1 and b <= 0xDF:
			# Half width katakana
			result += char(0xFF61 + b - 0xA1)
		elif b < 0x80:
			result += char(b)
		else:
			result += "?"
		k += 1
	return result

static func isUtf8(bytes : PackedByteArray) -> bool:
	var k : int = 0
	while k < bytes.size():
		var b : int = bytes[k]
		var extra : int = 0
		if b < 0x80:
			extra = 0
		elif b >= 0xC2 and b <= 0xDF:
			extra = 1
		elif b >= 0xE0 and b <= 0xEF:
			extra = 2
		elif b >= 0xF0 and b <= 0xF4:
			extra = 3
		else:
			return false
		for n in extra:
			k += 1
			if k >= bytes.size() or bytes[k] & 0xC0 != 0x80:
				return false
		k += 1
	return true
