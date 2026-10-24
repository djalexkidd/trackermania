extends ModModule
class_name XmModule

# FastTracker II module (.XM) reader.
# Gives the same notes as ModModule: the song is replayed tick by tick like FastTracker II
# (instruments with several samples, volume envelope and fadeout, auto-vibrato, volume column, linear or Amiga periods).

const MAX_CHANNELS : int = 32
const NOTE_OFF : int = 97
# Linear periods have 64 units per semitone, C-4 (note 48) plays the sample at C4_RATE
const LINEAR_C4 : float = 4608.0
const LINEAR_BASE : float = 7680.0
# Amiga periods (4 times the ProTracker ones), C-4 is this period
const AMIGA_C4 : float = 1712.0
const XM_PERIOD_MIN : float = 1.0
const XM_PERIOD_MAX : float = 31999.0
# Fadeout volume of a note before its key off
const FADE_MAX : int = 32768
# Volume change of the multi retrigger (Rxy) for each x, [add, multiply]
const RETRIG_VOLUME : Array = [[0, 1.0], [-1, 1.0], [-2, 1.0], [-4, 1.0], [-8, 1.0], [-16, 1.0], [0, 2.0 / 3.0], [0, 0.5],
	[0, 1.0], [1, 1.0], [2, 1.0], [4, 1.0], [8, 1.0], [16, 1.0], [0, 1.5], [0, 2.0]]

var linear : bool = true
var initialSpeed : int = 6
var initialBpm : int = 125
var globalVolume : int = 64
# {keymap (index in samples of each note, -1 if none), envelope (Vector2i points: tick, volume 0~64),
# env_on, sustain, loop_start, loop_end (point indices, -1 if off), fadeout, vibrato_type, vibrato_sweep, vibrato_depth, vibrato_rate}
var instruments : Array = []

func _init() -> void:
	formatName = "FastTracker module"

func parse(data : PackedByteArray) -> bool:
	if data.size() < 80 or data.slice(0, 17).get_string_from_ascii() != "Extended Module: ":
		return false
	title = data.slice(17, 37).get_string_from_ascii().strip_edges()
	var header_size : int = data.decode_u32(60)
	var song_length : int = mini(data.decode_u16(64), 256)
	channels = data.decode_u16(68)
	var pattern_count : int = data.decode_u16(70)
	var instrument_count : int = data.decode_u16(72)
	linear = data.decode_u16(74) & 1 == 1
	initialSpeed = data.decode_u16(76)
	initialBpm = data.decode_u16(78)
	if channels == 0 or channels > MAX_CHANNELS or 80 + song_length > data.size():
		return false
	order = data.slice(80, 80 + song_length)
	var pos : int = 60 + header_size
	for p in pattern_count:
		if pos + 9 > data.size():
			return false
		var rows : int = data.decode_u16(pos + 5)
		var packed_size : int = data.decode_u16(pos + 7)
		pos += data.decode_u32(pos)
		var cells : PackedByteArray = PackedByteArray()
		cells.resize((rows if rows > 0 else ROWS) * channels * 5)
		unpack(data, pos, mini(pos + packed_size, data.size()), cells)
		patterns.append(cells)
		pos += packed_size
	# A missing pattern is an empty one
	for k in order.size():
		if order[k] >= patterns.size():
			if patterns.size() == pattern_count:
				var empty : PackedByteArray = PackedByteArray()
				empty.resize(ROWS * channels * 5)
				patterns.append(empty)
			order[k] = pattern_count
	for i in instrument_count:
		if pos + 29 > data.size():
			break
		pos = parseInstrument(data, pos)
	return not order.is_empty()

# Packed pattern data to 5 bytes per cell: note, instrument, volume column, effect, parameter
static func unpack(data : PackedByteArray, start : int, end : int, cells : PackedByteArray) -> void:
	var o : int = start
	var cell : int = 0
	while o < end and cell < cells.size():
		var b : int = data[o]
		o += 1
		var fields : int = b & 0x1F
		if not b & 0x80:
			cells[cell] = b
			fields = 0x1E
		for k in 5:
			if fields & (1 << k) and o < end:
				cells[cell + k] = data[o]
				o += 1
		cell += 5

# An instrument, its sample headers and sample data, returns the position after it
func parseInstrument(data : PackedByteArray, pos : int) -> int:
	var header_size : int = data.decode_u32(pos)
	var sample_count : int = data.decode_u16(pos + 27)
	var keymap : PackedInt32Array = PackedInt32Array()
	keymap.resize(96)
	keymap.fill(-1)
	var instrument : Dictionary = {"keymap": keymap, "envelope": [], "env_on": false, "sustain": -1, "loop_start": -1, "loop_end": -1,
		"fadeout": 0, "vibrato_type": 0, "vibrato_sweep": 0, "vibrato_depth": 0, "vibrato_rate": 0}
	instruments.append(instrument)
	if sample_count == 0 or pos + 241 > data.size():
		return pos + header_size
	var sample_header_size : int = data.decode_u32(pos + 29)
	if sample_header_size == 0:
		sample_header_size = 40
	var first : int = samples.size()
	for k in 96:
		if data[pos + 33 + k] < sample_count:
			keymap[k] = first + data[pos + 33 + k]
	var point_count : int = mini(data[pos + 225], 12)
	for k in point_count:
		instrument.envelope.append(Vector2i(data.decode_u16(pos + 129 + k * 4), mini(data.decode_u16(pos + 131 + k * 4), 64)))
	var env_type : int = data[pos + 233]
	instrument.env_on = env_type & 1 == 1 and point_count > 0
	if env_type & 2 and data[pos + 227] < point_count:
		instrument.sustain = data[pos + 227]
	if env_type & 4 and data[pos + 228] <= data[pos + 229] and data[pos + 229] < point_count:
		instrument.loop_start = data[pos + 228]
		instrument.loop_end = data[pos + 229]
	instrument.vibrato_type = data[pos + 235]
	instrument.vibrato_sweep = data[pos + 236]
	instrument.vibrato_depth = data[pos + 237]
	instrument.vibrato_rate = data[pos + 238]
	instrument.fadeout = data.decode_u16(pos + 239)
	pos += header_size
	var headers : Array = []
	for k in sample_count:
		if pos + 18 > data.size():
			break
		headers.append({"length": data.decode_u32(pos), "loop_start": data.decode_u32(pos + 4), "loop_length": data.decode_u32(pos + 8),
			"volume": mini(data[pos + 12], 64), "finetune": data.decode_s8(pos + 13), "type": data[pos + 14],
			"panning": data[pos + 15], "relnote": data.decode_s8(pos + 16),
			"name": data.slice(pos + 18, mini(pos + 40, data.size())).get_string_from_ascii().strip_edges()})
		pos += sample_header_size
	for h in headers:
		var bytes : int = 2 if h.type & 0x10 else 1
		var raw : PackedByteArray = data.slice(pos, mini(pos + h.length, data.size()))
		pos += h.length
		raw.resize(raw.size() - raw.size() % bytes)
		var frames : int = raw.size() / bytes
		var loop_start : int = mini(h.loop_start / bytes, frames)
		var loop_length : int = mini(h.loop_length / bytes, frames - loop_start)
		samples.append({
			"name": h.name, "data": deltaDecode(raw, bytes == 2) if decodeSamples else PackedByteArray(), "frames": frames,
			"bits": bytes * 8, "loop_type": (h.type & 3 if h.type & 3 < 3 else 0) if loop_length > 0 else 0,
			"loop_start": loop_start, "loop_length": loop_length,
			"volume": h.volume, "finetune": h.finetune, "relnote": h.relnote, "panning": h.panning,
		})
	return pos

# XM samples store the difference with the previous value
static func deltaDecode(raw : PackedByteArray, sixteen_bits : bool) -> PackedByteArray:
	var old : int = 0
	if sixteen_bits:
		for k in range(0, raw.size(), 2):
			old = (old + (raw[k] | (raw[k + 1] << 8))) & 0xFFFF
			raw[k] = old & 0xFF
			raw[k + 1] = old >> 8
	else:
		for k in raw.size():
			old = (old + raw[k]) & 0xFF
			raw[k] = old
	return raw

func periodOf(realnote : int, finetune : int) -> float:
	if linear:
		return LINEAR_BASE - realnote * 64 - finetune / 2.0
	return AMIGA_C4 * pow(2.0, -(realnote - 48 + finetune / 128.0) / 12.0)

func pitchScale(_sample : int, period : float) -> float:
	return pow(2.0, (LINEAR_C4 - period) / 768.0) if linear else AMIGA_C4 / period

func newXmChannel() -> Dictionary:
	return {"instrument": -1, "sample": -1, "period": 0.0, "volume": 0, "pan": 128, "period_out": 0.0, "volume_out": 0,
		"effect": 0, "param": 0, "volcol": 0, "current": null, "key_on": false, "env_pos": 0, "fade": FADE_MAX,
		"autovib_pos": 0, "autovib_amp": 0, "delayed": [], "retrigger": false,
		"porta_target": 0.0, "porta_speed": 0, "porta_up": 0, "porta_down": 0, "fine_up": 0, "fine_down": 0,
		"xfine_up": 0, "xfine_down": 0, "vol_slide": 0, "fine_vol_up": 0, "fine_vol_down": 0, "global_slide": 0,
		"pan_slide": 0, "retrig_volume": 0, "retrig_interval": 0, "retrig_count": 0, "offset": 0, "tremor": 0, "tremor_pos": 0,
		"vibrato_speed": 0, "vibrato_depth": 0, "vibrato_pos": 0, "tremolo_speed": 0, "tremolo_depth": 0, "tremolo_pos": 0,
		"loop_row": 0, "loop_count": 0}

func replay() -> void:
	var speed : int = initialSpeed if initialSpeed > 0 else 6
	var bpm : int = initialBpm if initialBpm >= 32 else 125
	var time : float = 0.0
	var order_pos : int = 0
	var row : int = 0
	var visited : Dictionary = {}
	var state : Array = []
	globalVolume = 64
	for c in channels:
		state.append(newXmChannel())
	while order_pos < order.size() and time < MAX_LENGTH:
		var cells : PackedByteArray = patterns[order[order_pos]]
		var rows : int = cells.size() / (channels * 5)
		if row >= rows:
			row = 0
			order_pos += 1
			continue
		var key : int = order_pos * 256 + row
		if visited.has(key) and not state.any(func(ch): return ch.loop_count > 0):
			break
		visited[key] = true
		if row % ROWS_PER_MEASURE == 0:
			measures.append(time)
		var flow : Dictionary = {"jump_order": -1, "break_row": -1, "loop_row": -1, "row_delay": 0, "stop": false}
		for c in channels:
			var o : int = (row * channels + c) * 5
			if cells[o + 3] == 0xF:
				if cells[o + 4] == 0:
					flow.stop = true
				elif cells[o + 4] < 32:
					speed = cells[o + 4]
				else:
					bpm = cells[o + 4]
		for c in channels:
			var o : int = (row * channels + c) * 5
			startXmRow(state[c], c, cells.slice(o, o + 5), row, time, flow)
		var tick_length : float = 2.5 / bpm
		for tick in speed * (flow.row_delay + 1):
			for c in channels:
				if tick % speed != 0:
					updateTick(state[c], c, tick % speed, row, time)
				recordTick(state[c], time)
			time += tick_length
		if flow.stop:
			break
		if flow.jump_order >= 0 or flow.break_row >= 0:
			order_pos = flow.jump_order if flow.jump_order >= 0 else order_pos + 1
			row = flow.break_row if flow.break_row >= 0 else 0
		elif flow.loop_row >= 0:
			row = flow.loop_row
		else:
			row += 1
	length = time
	notes.sort_custom(func(a, b): return a.time < b.time)

# Tick 0 of a row, cell is [note, instrument, volume column, effect, parameter]
func startXmRow(ch : Dictionary, c : int, cell : PackedByteArray, row : int, time : float, flow : Dictionary) -> void:
	var effect : int = cell[3]
	var param : int = cell[4]
	var x : int = param >> 4
	var y : int = param & 0x0F
	ch.effect = effect
	ch.param = param
	ch.volcol = cell[2]
	ch.delayed = []
	if effect == 0x9 and param > 0:
		ch.offset = param * 256
	if effect == 0xE and x == 0xD and y > 0:
		ch.delayed = [cell[0], cell[1], cell[2]]
	else:
		playNote(ch, c, cell[0], cell[1], row, time)
		volumeColumnRow(ch, cell[2])
	match effect:
		0x1:
			if param > 0:
				ch.porta_up = param
		0x2:
			if param > 0:
				ch.porta_down = param
		0x3:
			if param > 0:
				ch.porta_speed = param
		0x4:
			if x > 0:
				ch.vibrato_speed = x
			if y > 0:
				ch.vibrato_depth = y
		0x5, 0x6, 0xA:
			if param > 0:
				ch.vol_slide = param
		0x7:
			if x > 0:
				ch.tremolo_speed = x
			if y > 0:
				ch.tremolo_depth = y
		0x8:
			ch.pan = param
		0xB:
			flow.jump_order = param
		0xC:
			ch.volume = mini(param, 64)
		0xD:
			flow.break_row = x * 10 + y
		0xE:
			match x:
				0x1:
					if y > 0:
						ch.fine_up = y
					slidePeriod(ch, -ch.fine_up * 4)
				0x2:
					if y > 0:
						ch.fine_down = y
					slidePeriod(ch, ch.fine_down * 4)
				0x6:
					if y == 0:
						ch.loop_row = row
					elif ch.loop_count == 0:
						ch.loop_count = y
						flow.loop_row = ch.loop_row
					else:
						ch.loop_count -= 1
						if ch.loop_count > 0:
							flow.loop_row = ch.loop_row
				0xA:
					if y > 0:
						ch.fine_vol_up = y
					ch.volume = mini(ch.volume + ch.fine_vol_up, 64)
				0xB:
					if y > 0:
						ch.fine_vol_down = y
					ch.volume = maxi(ch.volume - ch.fine_vol_down, 0)
				0xC:
					if y == 0:
						ch.volume = 0
				0xE:
					flow.row_delay = y
		0x10:
			globalVolume = mini(param, 64)
		0x11:
			if param > 0:
				ch.global_slide = param
		0x14:
			if param == 0:
				keyOff(ch)
		0x15:
			ch.env_pos = param
		0x19:
			if param > 0:
				ch.pan_slide = param
		0x1B:
			if x > 0:
				ch.retrig_volume = x
			if y > 0:
				ch.retrig_interval = y
		0x1D:
			if param > 0:
				ch.tremor = param
		0x21:
			if x == 1:
				if y > 0:
					ch.xfine_up = y
				slidePeriod(ch, -ch.xfine_up)
			elif x == 2:
				if y > 0:
					ch.xfine_down = y
				slidePeriod(ch, ch.xfine_down)
	ch.period_out = ch.period
	ch.volume_out = ch.volume

# Note and instrument of a cell, a tone portamento slides to the note instead
func playNote(ch : Dictionary, c : int, note : int, instrument : int, row : int, time : float) -> void:
	if note == NOTE_OFF:
		keyOff(ch)
		return
	if instrument > 0 and instrument <= instruments.size():
		ch.instrument = instrument - 1
	var porta : bool = ch.effect in [0x3, 0x5] or ch.volcol >> 4 == 0xF
	if note >= 1 and note < NOTE_OFF and ch.instrument >= 0:
		if porta and ch.current != null and ch.sample >= 0:
			var s : Dictionary = samples[ch.sample]
			ch.porta_target = periodOf(note - 1 + s.relnote, s.finetune)
		else:
			ch.sample = instruments[ch.instrument].keymap[note - 1]
			trigger(ch, c, note, row, time)
	# An instrument number resets the volume, panning and envelope
	if instrument > 0 and ch.sample >= 0:
		ch.volume = samples[ch.sample].volume
		ch.pan = samples[ch.sample].panning
		ch.key_on = true
		ch.env_pos = 0
		ch.fade = FADE_MAX
		ch.autovib_pos = 0
		ch.autovib_amp = 0

func trigger(ch : Dictionary, c : int, note : int, row : int, time : float) -> void:
	ch.current = null
	ch.vibrato_pos = 0
	ch.tremolo_pos = 0
	ch.retrig_count = 0
	if ch.sample < 0:
		return
	var s : Dictionary = samples[ch.sample]
	var realnote : int = note - 1 + s.relnote
	var offset : int = ch.offset if ch.effect == 0x9 else 0
	if realnote < 0 or realnote > 118 or s.frames <= 2 or offset >= s.frames:
		return
	ch.period = periodOf(realnote, s.finetune)
	ch.current = {"time": time, "channel": c, "sample": ch.sample, "instrument": ch.instrument, "period": ch.period,
		"offset": offset, "row": row, "env": [], "pan": 0.0}
	notes.append(ch.current)

# Without a volume envelope a key off cuts the note, with one the envelope leaves its sustain and the note fades out
func keyOff(ch : Dictionary) -> void:
	ch.key_on = false
	if ch.instrument < 0 or not instruments[ch.instrument].env_on:
		ch.volume = 0

func volumeColumnRow(ch : Dictionary, volcol : int) -> void:
	var y : int = volcol & 0x0F
	if volcol >= 0x10 and volcol <= 0x50:
		ch.volume = volcol - 0x10
	match volcol >> 4:
		0x8:
			ch.volume = maxi(ch.volume - y, 0)
		0x9:
			ch.volume = mini(ch.volume + y, 64)
		0xA:
			if y > 0:
				ch.vibrato_speed = y
		0xB:
			if y > 0:
				ch.vibrato_depth = y
		0xC:
			ch.pan = y * 16
		0xF:
			if y > 0:
				ch.porta_speed = y * 16

# Effects done on the other ticks of a row
func updateTick(ch : Dictionary, c : int, tick : int, row : int, time : float) -> void:
	ch.period_out = ch.period
	ch.volume_out = ch.volume
	var y : int = ch.volcol & 0x0F
	match ch.volcol >> 4:
		0x6:
			ch.volume = maxi(ch.volume - y, 0)
		0x7:
			ch.volume = mini(ch.volume + y, 64)
		0xB:
			vibrato(ch)
		0xD:
			ch.pan = maxi(ch.pan - y, 0)
		0xE:
			ch.pan = mini(ch.pan + y, 255)
		0xF:
			tonePortamento(ch)
	var x : int = ch.param >> 4
	y = ch.param & 0x0F
	match ch.effect:
		0x0:
			if ch.param > 0 and ch.period > 0:
				var semitones : int = [0, x, y][tick % 3]
				ch.period_out = ch.period - semitones * 64 if linear else ch.period * pow(2.0, -semitones / 12.0)
		0x1:
			slidePeriod(ch, -ch.porta_up * 4)
		0x2:
			slidePeriod(ch, ch.porta_down * 4)
		0x3:
			tonePortamento(ch)
		0x4:
			vibrato(ch)
		0x5:
			tonePortamento(ch)
			volumeSlide(ch, ch.vol_slide >> 4, ch.vol_slide & 0x0F)
		0x6:
			vibrato(ch)
			volumeSlide(ch, ch.vol_slide >> 4, ch.vol_slide & 0x0F)
		0x7:
			tremolo(ch)
		0xA:
			volumeSlide(ch, ch.vol_slide >> 4, ch.vol_slide & 0x0F)
		0xE:
			match x:
				0x9:
					if y > 0 and tick % y == 0:
						ch.retrigger = true
				0xC:
					if tick == y:
						ch.volume = 0
				0xD:
					if tick == y and not ch.delayed.is_empty():
						playNote(ch, c, ch.delayed[0], ch.delayed[1], row, time)
						volumeColumnRow(ch, ch.delayed[2])
						ch.delayed = []
						ch.period_out = ch.period
		0x11:
			globalVolume = clampi(globalVolume + (ch.global_slide >> 4) if ch.global_slide >> 4 else globalVolume - (ch.global_slide & 0x0F), 0, 64)
		0x14:
			if tick == ch.param:
				keyOff(ch)
		0x19:
			ch.pan = clampi(ch.pan + (ch.pan_slide >> 4) if ch.pan_slide >> 4 else ch.pan - (ch.pan_slide & 0x0F), 0, 255)
		0x1B:
			ch.retrig_count += 1
			if ch.retrig_interval > 0 and ch.retrig_count >= ch.retrig_interval:
				ch.retrig_count = 0
				ch.retrigger = true
				var change : Array = RETRIG_VOLUME[ch.retrig_volume]
				ch.volume = clampi(roundi((ch.volume + change[0]) * change[1]), 0, 64)
		0x1D:
			var on : int = (ch.tremor >> 4) + 1
			if ch.tremor_pos % (on + (ch.tremor & 0x0F) + 1) >= on:
				ch.volume_out = 0
			ch.tremor_pos += 1
	if ch.effect not in [0x7, 0x1D]:
		ch.volume_out = ch.volume

func slidePeriod(ch : Dictionary, amount : float) -> void:
	if ch.period > 0:
		ch.period = clampf(ch.period + amount, XM_PERIOD_MIN, XM_PERIOD_MAX)
		ch.period_out = ch.period

func tonePortamento(ch : Dictionary) -> void:
	if ch.porta_target == 0 or ch.period == 0:
		return
	if ch.period < ch.porta_target:
		ch.period = minf(ch.period + ch.porta_speed * 4, ch.porta_target)
	else:
		ch.period = maxf(ch.period - ch.porta_speed * 4, ch.porta_target)
	ch.period_out = ch.period

# Periods are 4 times finer than ProTracker ones
func vibrato(ch : Dictionary) -> void:
	var delta : int = (SINE_TABLE[ch.vibrato_pos & 31] * ch.vibrato_depth) >> 5
	ch.period_out = ch.period - delta if ch.vibrato_pos & 32 else ch.period + delta
	ch.vibrato_pos = (ch.vibrato_pos + ch.vibrato_speed) & 63

# Volume of the envelope at a tick, linear between its points
static func envelopeValue(points : Array, pos : int) -> float:
	if pos <= points[0].x:
		return points[0].y
	for k in range(1, points.size()):
		if pos < points[k].x:
			var a : Vector2i = points[k - 1]
			var b : Vector2i = points[k]
			return lerpf(a.y, b.y, float(pos - a.x) / (b.x - a.x))
	return points[-1].y

# Save the final pitch and volume (envelope, fadeout, global volume) of the playing note, then move its envelope
func recordTick(ch : Dictionary, time : float) -> void:
	if ch.current == null or ch.instrument < 0:
		ch.retrigger = false
		return
	var instrument : Dictionary = instruments[ch.instrument]
	var period : float = ch.period_out
	if instrument.vibrato_depth > 0 and instrument.vibrato_rate > 0:
		var full : int = instrument.vibrato_depth << 8
		ch.autovib_amp = mini(ch.autovib_amp + full / instrument.vibrato_sweep, full) if instrument.vibrato_sweep > 0 and ch.key_on else full
		var p : int = ch.autovib_pos
		var wave : float = [sin(p / 256.0 * TAU) * 64.0, 64.0 if p < 128 else -64.0, 64.0 - p / 2.0, p / 2.0 - 64.0][instrument.vibrato_type & 3]
		period += wave * ch.autovib_amp / 16384.0
		ch.autovib_pos = (p + instrument.vibrato_rate) & 255
	var volume : float = ch.volume_out * ch.fade / float(FADE_MAX) * globalVolume / 64.0
	if instrument.env_on:
		volume *= envelopeValue(instrument.envelope, ch.env_pos) / 64.0
		var points : Array = instrument.envelope
		if not (ch.key_on and instrument.sustain >= 0 and ch.env_pos == points[instrument.sustain].x):
			ch.env_pos += 1
			if instrument.loop_start >= 0 and ch.env_pos >= points[instrument.loop_end].x:
				ch.env_pos = points[instrument.loop_start].x
		if not ch.key_on:
			ch.fade = maxi(ch.fade - instrument.fadeout, 0)
	var env : Array = ch.current.env
	var n : int = env.size()
	if n == 0:
		ch.current.pan = (ch.pan - 128) / 128.0
	if n == 0 or ch.retrigger or env[n - 3] != period or env[n - 2] != volume:
		env.append_array([time - ch.current.time, period, volume, 1.0 if ch.retrigger and n > 0 else 0.0])
	ch.retrigger = false
