extends RefCounted
class_name ModModule

# Amiga ProTracker module (.MOD) reader.
# The song is replayed tick by tick like ProTracker does to get every note with its time
# and the pitch/volume automation of its effects, so each note can be played on its own as a keysound.

# Extensions of the modules, ProTracker and FastTracker II (XmModule)
const EXTENSIONS : Array = ["mod", "xm"]
# Rate of a sample played at C-4 with no finetune
const C4_RATE : float = 8363.0
# Half of the PAL Amiga clock, the frequency of a note is AMIGA_CLOCK / period (Hz)
const AMIGA_CLOCK : float = 3546895.0
const PERIOD_MIN : int = 113
const PERIOD_MAX : int = 856
const ROWS : int = 64
# Rows of a measure, most modules have 4 rows per beat and 4 beats per measure
const ROWS_PER_MEASURE : int = 16
# Stop the replay of songs looping forever (seconds)
const MAX_LENGTH : float = 1200.0
# ProTracker vibrato and tremolo waveform
const SINE_TABLE : Array = [0, 24, 49, 74, 97, 120, 141, 161, 180, 197, 212, 224, 235, 244, 250, 253,
	255, 253, 250, 244, 235, 224, 212, 197, 180, 161, 141, 120, 97, 74, 49, 24]

var title : String = ""
# Shown as the artist of the song
var formatName : String = "Amiga module"
var channels : int = 4
# {name, data, frames, bits, loop_type (0 none, 1 forward, 2 ping-pong), finetune, volume, loop_start, loop_length},
# data is signed 8-bit PCM or 16-bit little endian PCM, loops are in frames
var samples : Array = []
# The music select only needs the notes, not the sample data
var decodeSamples : bool = true
var order : PackedByteArray
var patterns : Array = []
# Every note of the song in time order: {time, channel, sample, instrument, period, offset, row, env, pan}
# env is the automation of the note, 4 values per change: time since the note, period, volume (0~64), retrigger (0 or 1)
# pan is the panning when the note starts, from -1.0 (left) to 1.0 (right)
var notes : Array = []
# Duration of the song (seconds)
var length : float = 0.0
# Start time of each measure (seconds), they follow the tempo changes of the song
var measures : Array = []

static func is_module(path : String) -> bool:
	return path.get_extension().to_lower() in EXTENSIONS

static func load_file(path : String, with_samples : bool = true) -> ModModule:
	var module : ModModule = XmModule.new() if path.get_extension().to_lower() == "xm" else ModModule.new()
	module.decodeSamples = with_samples
	if not module.parse(FileAccess.get_file_as_bytes(path)):
		return null
	module.replay()
	return module

# Number of channels from the tag at offset 1080, 0 for old 15 samples Soundtracker modules
static func channelCount(tag : String) -> int:
	if tag in ["M.K.", "M!K!", "M&K!", "FLT4", "N.T."]:
		return 4
	if tag in ["FLT8", "OCTA", "OKTA", "CD81"]:
		return 8
	if tag.length() == 4 and tag.substr(1) == "CHN" and tag[0].is_valid_int():
		return int(tag[0])
	if tag.length() == 4 and tag.substr(2) in ["CH", "CN"] and tag.substr(0, 2).is_valid_int():
		return int(tag.substr(0, 2))
	if tag.length() == 4 and tag.begins_with("TDZ") and tag[3].is_valid_int():
		return int(tag[3])
	return 0

static func word(data : PackedByteArray, offset : int) -> int:
	return (data[offset] << 8) | data[offset + 1]

func parse(data : PackedByteArray) -> bool:
	if data.size() < 600:
		return false
	var sample_count : int = 31
	channels = channelCount(data.slice(1080, 1084).get_string_from_ascii()) if data.size() >= 1084 else 0
	if channels == 0:
		sample_count = 15
		channels = 4
	title = data.slice(0, 20).get_string_from_ascii().strip_edges()
	for i in sample_count:
		var o : int = 20 + i * 30
		var finetune : int = data[o + 24] & 0x0F
		samples.append({
			"name": data.slice(o, o + 22).get_string_from_ascii().strip_edges(),
			"length": word(data, o + 22) * 2,
			"data": PackedByteArray(),
			"finetune": finetune - 16 if finetune > 7 else finetune,
			"volume": mini(data[o + 25], 64),
			"loop_start": word(data, o + 26) * 2,
			"loop_length": word(data, o + 28) * 2,
			"bits": 8, "frames": 0, "loop_type": 0,
		})
	var pos : int = 20 + sample_count * 30
	var song_length : int = data[pos]
	var orders : PackedByteArray = data.slice(pos + 2, pos + 130)
	pos += 130 + (4 if sample_count == 31 else 0)
	# Patterns not in the song are saved too
	var pattern_count : int = 0
	for p in orders:
		pattern_count = maxi(pattern_count, p + 1)
	var pattern_size : int = ROWS * channels * 4
	if data.size() < pos + pattern_count * pattern_size:
		return false
	for p in pattern_count:
		patterns.append(data.slice(pos, pos + pattern_size))
		pos += pattern_size
	order = orders.slice(0, song_length)
	for s in samples:
		s.data = data.slice(pos, mini(pos + s.length, data.size()))
		pos += s.length
		if s.loop_start + s.loop_length > s.data.size():
			# Some trackers save the loop start in words
			if (s.loop_start >> 1) + s.loop_length <= s.data.size():
				s.loop_start = s.loop_start >> 1
			else:
				s.loop_length = maxi(s.data.size() - s.loop_start, 0)
		s.frames = s.data.size()
		s.loop_type = 1 if s.loop_length > 2 else 0
	return not order.is_empty()

# Playback rate of a sample at a period, relative to C4_RATE
func pitchScale(sample : int, period : float) -> float:
	return AMIGA_CLOCK / period / C4_RATE * pow(2.0, samples[sample].finetune / 96.0)

func newChannel() -> Dictionary:
	return {"sample": 0, "period": 0, "volume": 0, "period_out": 0, "volume_out": 0,
		"effect": 0, "param": 0, "note": null, "delayed_period": 0, "offset": 0, "retrigger": false,
		"porta_target": 0, "porta_speed": 0, "vibrato_speed": 0, "vibrato_depth": 0, "vibrato_pos": 0,
		"tremolo_speed": 0, "tremolo_depth": 0, "tremolo_pos": 0, "loop_row": 0, "loop_count": 0}

# Play the whole song without sound to fill the notes
func replay() -> void:
	var speed : int = 6
	var bpm : int = 125
	var time : float = 0.0
	var order_pos : int = 0
	var row : int = 0
	var visited : Dictionary = {}
	var state : Array = []
	for c in channels:
		state.append(newChannel())
	while order_pos < order.size() and order[order_pos] < patterns.size() and time < MAX_LENGTH:
		# Going back to a row already played means the song loops (except inside a pattern loop)
		var key : int = order_pos * ROWS + row
		if visited.has(key) and not state.any(func(ch): return ch.loop_count > 0):
			break
		visited[key] = true
		if row % ROWS_PER_MEASURE == 0:
			measures.append(time)
		var pattern : PackedByteArray = patterns[order[order_pos]]
		var flow : Dictionary = {"jump_order": -1, "break_row": -1, "loop_row": -1, "row_delay": 0, "stop": false}
		for c in channels:
			var o : int = (row * channels + c) * 4
			var effect : int = pattern[o + 2] & 0x0F
			var param : int = pattern[o + 3]
			# Speed changes apply to the whole row
			if effect == 0xF:
				if param == 0:
					flow.stop = true
				elif param < 32:
					speed = param
				else:
					bpm = param
			startRow(state[c], c, (pattern[o] & 0xF0) | (pattern[o + 2] >> 4), ((pattern[o] & 0x0F) << 8) | pattern[o + 1], effect, param, row, time, flow)
		var tick_length : float = 2.5 / bpm
		for tick in speed * (flow.row_delay + 1):
			for c in channels:
				if tick % speed != 0:
					updateTick(state[c], c, tick % speed, row, time)
				recordTick(state[c], time)
			time += tick_length
		if flow.stop:
			break
		# Next row
		if flow.jump_order >= 0 or flow.break_row >= 0:
			order_pos = flow.jump_order if flow.jump_order >= 0 else order_pos + 1
			row = flow.break_row if flow.break_row >= 0 and flow.break_row < ROWS else 0
		elif flow.loop_row >= 0:
			row = flow.loop_row
		else:
			row += 1
			if row >= ROWS:
				row = 0
				order_pos += 1
	length = time
	# Delayed notes (EDx) can be after the next notes of other channels
	notes.sort_custom(func(a, b): return a.time < b.time)

# Tick 0 of a row: new note, instrument and effects done once per row
func startRow(ch : Dictionary, c : int, sample : int, period : int, effect : int, param : int, row : int, time : float, flow : Dictionary) -> void:
	ch.effect = effect
	ch.param = param
	ch.delayed_period = 0
	var x : int = param >> 4
	var y : int = param & 0x0F
	if sample > 0 and sample <= samples.size():
		ch.sample = sample
		ch.volume = samples[sample - 1].volume
	if effect == 0x9 and param > 0:
		ch.offset = param * 256
	if period > 0:
		if effect == 0x3 or effect == 0x5:
			ch.porta_target = period
		elif effect == 0xE and x == 0xD and y > 0:
			ch.delayed_period = period
		else:
			trigger(ch, c, period, row, time)
	match effect:
		0x3:
			if param > 0:
				ch.porta_speed = param
		0x4:
			if x > 0:
				ch.vibrato_speed = x
			if y > 0:
				ch.vibrato_depth = y
		0x7:
			if x > 0:
				ch.tremolo_speed = x
			if y > 0:
				ch.tremolo_depth = y
		0xB:
			flow.jump_order = param
		0xC:
			ch.volume = mini(param, 64)
		0xD:
			flow.break_row = x * 10 + y
		0xE:
			match x:
				0x1:
					if ch.period > 0:
						ch.period = maxi(ch.period - y, PERIOD_MIN)
				0x2:
					if ch.period > 0:
						ch.period = mini(ch.period + y, PERIOD_MAX)
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
					ch.volume = mini(ch.volume + y, 64)
				0xB:
					ch.volume = maxi(ch.volume - y, 0)
				0xC:
					if y == 0:
						ch.volume = 0
				0xE:
					flow.row_delay = y
	ch.period_out = ch.period
	ch.volume_out = ch.volume

# Effects done on the other ticks of a row
func updateTick(ch : Dictionary, c : int, tick : int, row : int, time : float) -> void:
	ch.period_out = ch.period
	ch.volume_out = ch.volume
	var x : int = ch.param >> 4
	var y : int = ch.param & 0x0F
	match ch.effect:
		0x0:
			if ch.param > 0 and ch.period > 0:
				var semitones : int = [0, x, y][tick % 3]
				ch.period_out = roundi(ch.period * pow(2.0, -semitones / 12.0))
		0x1:
			if ch.period > 0:
				ch.period = maxi(ch.period - ch.param, PERIOD_MIN)
				ch.period_out = ch.period
		0x2:
			if ch.period > 0:
				ch.period = mini(ch.period + ch.param, PERIOD_MAX)
				ch.period_out = ch.period
		0x3:
			tonePortamento(ch)
		0x4:
			vibrato(ch)
		0x5:
			tonePortamento(ch)
			volumeSlide(ch, x, y)
		0x6:
			vibrato(ch)
			volumeSlide(ch, x, y)
		0x7:
			tremolo(ch)
		0xA:
			volumeSlide(ch, x, y)
		0xE:
			match x:
				0x9:
					if y > 0 and tick % y == 0:
						ch.retrigger = true
				0xC:
					if tick == y:
						ch.volume = 0
						ch.volume_out = 0
				0xD:
					if tick == y and ch.delayed_period > 0:
						trigger(ch, c, ch.delayed_period, row, time)
						ch.delayed_period = 0
						ch.period_out = ch.period

func trigger(ch : Dictionary, c : int, period : int, row : int, time : float) -> void:
	ch.period = period
	ch.vibrato_pos = 0
	ch.tremolo_pos = 0
	ch.note = null
	if ch.sample == 0:
		return
	var s : Dictionary = samples[ch.sample - 1]
	var offset : int = ch.offset if ch.effect == 0x9 else 0
	if s.data.size() <= 2 or offset >= s.data.size():
		return
	ch.note = {"time": time, "channel": c, "sample": ch.sample - 1, "instrument": ch.sample - 1, "period": period, "offset": offset,
		"row": row, "env": [], "pan": -1.0 if c % 4 in [0, 3] else 1.0}
	notes.append(ch.note)

# Save the pitch and volume of the playing note when they change
func recordTick(ch : Dictionary, time : float) -> void:
	if ch.note != null:
		var env : Array = ch.note.env
		var n : int = env.size()
		if n == 0 or ch.retrigger or env[n - 3] != ch.period_out or env[n - 2] != ch.volume_out:
			env.append_array([time - ch.note.time, ch.period_out, ch.volume_out, 1.0 if ch.retrigger and n > 0 else 0.0])
	ch.retrigger = false

func tonePortamento(ch : Dictionary) -> void:
	if ch.porta_target == 0 or ch.period == 0:
		return
	if ch.period < ch.porta_target:
		ch.period = mini(ch.period + ch.porta_speed, ch.porta_target)
	else:
		ch.period = maxi(ch.period - ch.porta_speed, ch.porta_target)
	ch.period_out = ch.period

func vibrato(ch : Dictionary) -> void:
	var delta : int = (SINE_TABLE[ch.vibrato_pos & 31] * ch.vibrato_depth) >> 7
	ch.period_out = ch.period - delta if ch.vibrato_pos & 32 else ch.period + delta
	ch.vibrato_pos = (ch.vibrato_pos + ch.vibrato_speed) & 63

func tremolo(ch : Dictionary) -> void:
	var delta : int = (SINE_TABLE[ch.tremolo_pos & 31] * ch.tremolo_depth) >> 6
	ch.volume_out = clampi(ch.volume - delta if ch.tremolo_pos & 32 else ch.volume + delta, 0, 64)
	ch.tremolo_pos = (ch.tremolo_pos + ch.tremolo_speed) & 63

func volumeSlide(ch : Dictionary, up : int, down : int) -> void:
	ch.volume = mini(ch.volume + up, 64) if up > 0 else maxi(ch.volume - down, 0)
	ch.volume_out = ch.volume
