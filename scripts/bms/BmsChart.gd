extends RefCounted
class_name BmsChart

# A keysounded chart for beatmania IIDX simulators: BMS (.bms, .bme, .bml) or bmson.
# Every sound of the song is a keysound event, the notes of the chart point to theirs, the others are the background music.
# Single play (5 or 7 keys and the scratch) and double play charts (both sides, played with the DOUBLE PLAY option).

const EXTENSIONS : Array = ["bms", "bme", "bml", "bmson"]
# Silence before the song starts (seconds)
const LEAD_IN : float = 2.0
const SCRATCH_LANE : int = 7
# Lane of each channel of a side (1x/5x for 1P, 2x/6x for 2P, visible then long notes): keys 1~5, 6 scratch, 8 and 9 keys 6 and 7
const KEY_CHANNELS : Dictionary = {"1": 0, "2": 1, "3": 2, "4": 3, "5": 4, "8": 5, "9": 6, "6": 7}
# The 2P side of a double play chart takes the lanes 8~15, in the same order
const SIDE_LANES : int = 8
const DOUBLE_LANES : int = 16
# The foot pedal channel has no lane, its sounds go to the background music
const PEDAL_CHANNEL : String = "17"
# Names of the #DIFFICULTY values, 5 is the INSANE of BMS
const DIFFICULTIES : Array = ["", "Beginner", "Normal", "Hyper", "Another", "Leggendaria"]
# Words of the titles and file names giving the difficulty when #DIFFICULTY is missing, searched in this order
const DIFFICULTY_WORDS : Array = [
	["leggendaria", "Leggendaria"], ["insane", "Leggendaria"], ["another", "Another"],
	["hyper", "Hyper"], ["normal", "Normal"], ["beginner", "Beginner"],
]
const DEFAULT_BPM : float = 130.0
# bmson pulses per beat when the resolution is missing
const BMSON_RESOLUTION : float = 240.0
const BMSON_MODES : Array = ["beat-7k", "beat-5k"]
const BMSON_DOUBLE_MODES : Array = ["beat-14k", "beat-10k"]

var title : String = ""
var artist : String = ""
var difficultyName : String = ""
var playLevel : int = 0
# Sound files as written in the chart, the keysound events point to them (see soundFile())
var soundFiles : PackedStringArray = []
# The BMS file names are decoded only when the sounds are loaded
var shiftJisNames : bool = false
# Sound file played as the music select preview (#PREVIEW, bmson preview_music), "" if none
var previewFile : String = ""
# Volume of all the sounds (#VOLWAV)
var volume : float = 1.0
# All the sounds of the song in time order (seconds, without the lead-in): {time, sound, offset, cut}
# offset is where the sound starts (sliced bmson sounds), cut stops the sound at the note time if it is not hit (bmson)
var keysounds : Array = []
# 8 lanes of notes (16 for a double play chart), [time] or [time, length] for a long note, in seconds with the lead-in
var noteArray : Array = []
# Index in keysounds of each note of noteArray, -1 for a note without sound
var keysoundArray : Array = []
# Double play chart: there are notes on the 2P side
var double : bool = false
# Start time of each measure, in seconds with the lead-in
var measures : Array = []
var level : int = 1

# Tempo changes and stops: from each point, the time goes on at its BPM after its stop
var pointBeats : PackedFloat64Array = []
var pointTimes : PackedFloat64Array = []
var pointStops : PackedFloat64Array = []
var pointBpms : PackedFloat64Array = []

static func is_bms(path : String) -> bool:
	return path.get_extension().to_lower() in EXTENSIONS

# Read a chart, null if it is not a chart TrackerMania can play.
# The #RANDOM blocks take a random branch, or the first one for the music select.
static func load_file(path : String, random : bool = true) -> BmsChart:
	var bytes : PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var chart : BmsChart = BmsChart.new()
	for lane in DOUBLE_LANES:
		chart.noteArray.append([])
		chart.keysoundArray.append([])
	var ok : bool = false
	if path.get_extension().to_lower() == "bmson":
		ok = chart.parseBmson(bytes.get_string_from_utf8())
	else:
		# One character per byte, the texts are decoded later from Shift-JIS or UTF-8
		ok = chart.parseBms(bytes.get_string_from_ascii(), random)
	if not ok:
		return null
	# Without notes on the 2P side, it is a single play chart
	chart.double = chart.noteArray.slice(SIDE_LANES).any(func(notes): return not notes.is_empty())
	if not chart.double:
		chart.noteArray.resize(SIDE_LANES)
		chart.keysoundArray.resize(SIDE_LANES)
	if chart.difficultyName == "":
		chart.difficultyName = chart.guessDifficulty(path.get_file().get_basename())
	chart.level = QuaChart.densityLevel(chart.noteArray)
	return chart

func parseBms(text : String, random : bool) -> bool:
	var header : Dictionary = {}
	var wavs : Dictionary = {}
	var bpms : Dictionary = {}
	var stops : Dictionary = {}
	var lnObjects : Dictionary = {}
	var measureLengths : Dictionary = {}
	# [measure, channel, data] of each channel line
	var lines : Array = []
	var base62 : bool = false
	# #RANDOM values, and for each #IF: [this branch is played, a branch was already played]
	var randoms : Array = []
	var conditions : Array = []
	for line in text.split("\n"):
		line = line.strip_edges()
		if not line.begins_with("#"):
			continue
		var space : int = line.find(" ")
		var tab : int = line.find("\t")
		if space == -1 or (tab != -1 and tab < space):
			space = tab
		var command : String = (line if space == -1 else line.left(space)).to_upper()
		var value : String = "" if space == -1 else line.substr(space + 1).strip_edges()
		# Control flow
		match command:
			"#RANDOM", "#SETRANDOM":
				var count : int = maxi(value.to_int(), 1)
				randoms.append((randi_range(1, count) if random else 1) if command == "#RANDOM" else count)
				continue
			"#ENDRANDOM":
				randoms.pop_back()
				continue
			"#IF":
				var played : bool = not randoms.is_empty() and value.to_int() == randoms[-1]
				conditions.append([played, played])
				continue
			"#ELSEIF":
				if not conditions.is_empty():
					var played : bool = not conditions[-1][1] and not randoms.is_empty() and value.to_int() == randoms[-1]
					conditions[-1] = [played, conditions[-1][1] or played]
				continue
			"#ELSE":
				if not conditions.is_empty():
					conditions[-1] = [not conditions[-1][1], true]
				continue
			"#ENDIF", "#END":
				conditions.pop_back()
				continue
		if conditions.any(func(c): return not c[0]):
			continue
		# #mmmcc:data
		if line.length() > 7 and line[6] == ":" and line.substr(1, 3).is_valid_int():
			var measure : int = line.substr(1, 3).to_int()
			var channel : String = line.substr(4, 2).to_upper()
			var data : String = line.substr(7).strip_edges()
			if channel == "02":
				measureLengths[measure] = data.to_float()
			else:
				lines.append([measure, channel, data])
			continue
		if command.length() == 6 and command.begins_with("#WAV"):
			wavs[line.substr(4, 2)] = value
		elif command.length() == 6 and command.begins_with("#BPM"):
			bpms[line.substr(4, 2)] = value.to_float()
		elif command.length() == 7 and command.begins_with("#STOP"):
			stops[line.substr(5, 2)] = value.to_float()
		elif command == "#LNOBJ":
			lnObjects[value] = true
		elif command == "#BASE":
			base62 = value == "62"
		else:
			header[command] = value

	# The ids are case sensitive only with #BASE 62
	if not base62:
		for dictionary in [wavs, bpms, stops, lnObjects]:
			var copy : Dictionary = dictionary.duplicate()
			dictionary.clear()
			for id in copy:
				dictionary[id.to_upper()] = copy[id]
	var sounds : Dictionary = {}
	for id in wavs:
		sounds[id] = soundFiles.size()
		soundFiles.append(wavs[id])
	shiftJisNames = true

	title = ShiftJIS.decode(header.get("#TITLE", ""))
	var subtitle : String = ShiftJIS.decode(header.get("#SUBTITLE", ""))
	if subtitle != "":
		title += " " + subtitle
	artist = ShiftJIS.decode(header.get("#ARTIST", ""))
	playLevel = header.get("#PLAYLEVEL", "0").to_int()
	var difficulty : int = header.get("#DIFFICULTY", "0").to_int()
	if difficulty > 0 and difficulty < DIFFICULTIES.size():
		difficultyName = DIFFICULTIES[difficulty]
	previewFile = ShiftJIS.decode(header.get("#PREVIEW", ""))
	if header.has("#VOLWAV"):
		volume = maxf(header["#VOLWAV"].to_float(), 0.0) / 100.0

	# Beat of the start of each measure, a measure has 4 beats times its length
	var lastMeasure : int = 0
	for l in lines:
		lastMeasure = maxi(lastMeasure, l[0])
	var measureBeats : PackedFloat64Array = [0.0]
	for m in lastMeasure + 1:
		var length : float = measureLengths.get(m, 1.0)
		measureBeats.append(measureBeats[m] + 4.0 * (length if length > 0.0 else 1.0))

	# [beat, 0 for a tempo or 1 for a stop, value]
	var timing : Array = []
	# [beat, sound id]
	var background : Array = []
	# [lane, beat] -> sound id, a later line replaces the notes of an earlier one
	var visible : Dictionary = {}
	var long : Dictionary = {}
	for l in lines:
		var channel : String = l[1]
		var data : String = l[2]
		if not base62:
			data = data.to_upper()
		var count : int = data.length() / 2
		for k in count:
			# Most objects are empty ("00")
			if data.unicode_at(k * 2) == 48 and data.unicode_at(k * 2 + 1) == 48:
				continue
			var id : String = data.substr(k * 2, 2)
			var beat : float = measureBeats[l[0]] + (measureBeats[l[0] + 1] - measureBeats[l[0]]) * k / count
			match channel:
				"01", PEDAL_CHANNEL:
					background.append([beat, id])
				"03":
					timing.append([beat, 0, float(id.hex_to_int())])
				"08":
					if bpms.has(id):
						timing.append([beat, 0, bpms[id]])
				"09":
					# Stops are in 1/192 of a 4/4 measure
					if stops.has(id):
						timing.append([beat, 1, stops[id] / 48.0])
				_:
					if KEY_CHANNELS.has(channel[1]) and channel[0] in ["1", "2", "5", "6"]:
						var lane : int = KEY_CHANNELS[channel[1]] + (SIDE_LANES if channel[0] in ["2", "6"] else 0)
						if channel[0] in ["1", "2"]:
							visible[[lane, beat]] = id
						else:
							long[[lane, beat]] = id
	buildTimeline(header.get("#BPM", "").to_float(), timing)

	# [beat, sound id, end beat or -1] of each lane
	var laneNotes : Array = []
	for lane in DOUBLE_LANES:
		laneNotes.append([])
	for key in visible:
		laneNotes[key[0]].append([key[1], visible[key], -1.0])
	for lane in DOUBLE_LANES:
		laneNotes[lane].sort()
		# #LNOBJ: this sound ends the long note started by the previous note of the lane
		var notes : Array = []
		for note in laneNotes[lane]:
			if lnObjects.has(note[1]) and notes and notes[-1][2] < 0.0:
				notes[-1][2] = note[0]
			else:
				notes.append(note)
		# Long note channels: one object starts the long note, the next one ends it
		var ends : Array = []
		for key in long:
			if key[0] == lane:
				ends.append([key[1], long[key]])
		ends.sort()
		for k in range(0, ends.size() - 1, 2):
			notes.append([ends[k][0], ends[k][1], ends[k + 1][0]])
		laneNotes[lane] = notes

	# Key notes are [time, sound, lane, end time], the background music [time, sound, -1, 0]
	var events : Array = []
	for note in background:
		if sounds.has(note[1]):
			events.append([beatToTime(note[0]), sounds[note[1]], -1, 0.0])
	for lane in DOUBLE_LANES:
		for note in laneNotes[lane]:
			events.append([beatToTime(note[0]), sounds.get(note[1], -1), lane, beatToTime(note[2]) if note[2] >= 0.0 else -1.0])
	events.sort()
	for event in events:
		addEvent(event[0], event[1], 0.0, false, event[2], event[3])

	for m in lastMeasure + 2:
		measures.append(beatToTime(measureBeats[m]) + LEAD_IN)
	return true

func parseBmson(text : String) -> bool:
	var data = JSON.parse_string(text)
	if not data is Dictionary or not data.get("info") is Dictionary:
		return false
	var info : Dictionary = data["info"]
	var mode = info.get("mode_hint", "beat-7k")
	if not mode in BMSON_MODES and not mode in BMSON_DOUBLE_MODES:
		return false
	var double_mode : bool = mode in BMSON_DOUBLE_MODES
	title = str(info.get("title", ""))
	var subtitle : String = str(info.get("subtitle", "")) if info.get("subtitle") != null else ""
	if subtitle != "":
		title += " " + subtitle
	artist = str(info.get("artist", "")) if info.get("artist") != null else ""
	playLevel = int(num(info.get("level")))
	if info.get("difficulty") is float and int(info["difficulty"]) > 0 and int(info["difficulty"]) < DIFFICULTIES.size():
		difficultyName = DIFFICULTIES[int(info["difficulty"])]
	elif info.get("chart_name") is String:
		difficultyName = guessDifficulty(info["chart_name"])
	if info.get("preview_music") is String:
		previewFile = info["preview_music"]
	var resolution : float = num(info.get("resolution"), BMSON_RESOLUTION)
	if resolution <= 0.0:
		resolution = BMSON_RESOLUTION

	# Stops are in pulses like the positions
	var timing : Array = []
	for e in arrayField(data, "bpm_events"):
		if e is Dictionary:
			timing.append([num(e.get("y")) / resolution, 0, num(e.get("bpm"))])
	for e in arrayField(data, "stop_events"):
		if e is Dictionary:
			timing.append([num(e.get("y")) / resolution, 1, num(e.get("duration")) / resolution])
	buildTimeline(num(info.get("init_bpm")), timing)

	# [time, sound, lane, end time, offset], a sound restarts at each note without the continue flag
	var events : Array = []
	var lastBeat : float = 0.0
	for channel in arrayField(data, "sound_channels"):
		if not channel is Dictionary:
			continue
		var sound : int = soundFiles.size()
		soundFiles.append(str(channel.get("name", "")))
		var notes : Array = channel.get("notes", []).filter(func(n): return n is Dictionary) if channel.get("notes") is Array else []
		notes.sort_custom(func(a, b): return num(a.get("y")) < num(b.get("y")))
		var start : float = 0.0
		for n in notes:
			var beat : float = num(n.get("y")) / resolution
			var time : float = beatToTime(beat)
			if not n.get("c", false):
				start = time
			var x : int = int(n["x"]) if n.get("x") is float else 0
			# x: 1~7 keys, 8 scratch, then 9~16 on the 2P side of a double play chart, the others are the background music
			var lane : int = -1
			if x >= 1 and x <= (DOUBLE_LANES if double_mode else SIDE_LANES):
				lane = x - 1
			var length : float = num(n.get("l")) / resolution
			var end : float = beatToTime(beat + length) if lane != -1 and length > 0.0 else -1.0
			events.append([time, sound, lane, end, time - start])
			lastBeat = maxf(lastBeat, beat + length)
	events.sort()
	for event in events:
		addEvent(event[0], event[1], event[4], true, event[2], event[3])

	var lines : Array = arrayField(data, "lines")
	if lines.is_empty():
		for k in int(lastBeat / 4.0) + 2:
			measures.append(beatToTime(k * 4.0) + LEAD_IN)
	for line in lines:
		if line is Dictionary:
			measures.append(beatToTime(num(line.get("y")) / resolution) + LEAD_IN)
	measures.sort()
	return true

# A number of the bmson, or the default value if it is missing
static func num(value, default : float = 0.0) -> float:
	return float(value) if value is float or value is int else default

# Name of a sound file
func soundFile(sound : int) -> String:
	return ShiftJIS.decode(soundFiles[sound]) if shiftJisNames else soundFiles[sound]

static func arrayField(data : Dictionary, field : String) -> Array:
	return data[field] if data.get(field) is Array else []

# Add a sound event in time order, and the note of the chart when it has a lane
func addEvent(time : float, sound : int, offset : float, cut : bool, lane : int, end : float) -> void:
	var index : int = -1
	if sound >= 0:
		index = keysounds.size()
		keysounds.append({"time": time, "sound": sound, "offset": offset, "cut": cut})
	if lane == -1:
		return
	if end > time:
		noteArray[lane].append([time + LEAD_IN, end - time])
	else:
		noteArray[lane].append([time + LEAD_IN])
	keysoundArray[lane].append(index)

# timing: [beat, 0 for a tempo or 1 for a stop (beats), value], a tempo change applies before a stop at the same beat
func buildTimeline(bpm : float, timing : Array) -> void:
	timing.sort()
	pointBeats = [0.0]
	pointTimes = [0.0]
	pointStops = [0.0]
	pointBpms = [bpm if bpm > 0.0 else DEFAULT_BPM]
	for event in timing:
		var beat : float = event[0]
		var last : int = pointBeats.size() - 1
		if beat < 0.0:
			continue
		if beat > pointBeats[last]:
			pointTimes.append(beatToTime(beat))
			pointBeats.append(beat)
			pointStops.append(0.0)
			pointBpms.append(pointBpms[last])
			last += 1
		# Negative and null tempos are not supported
		if event[1] == 0 and event[2] > 0.0:
			pointBpms[last] = event[2]
		elif event[1] == 1 and event[2] > 0.0:
			pointStops[last] += event[2] * 60.0 / pointBpms[last]

# Time of a beat (seconds), a note on a stop is played when the stop starts
func beatToTime(beat : float) -> float:
	var k : int = maxi(pointBeats.bsearch(beat, false) - 1, 0)
	if beat <= pointBeats[k]:
		return pointTimes[k]
	return pointTimes[k] + pointStops[k] + (beat - pointBeats[k]) * 60.0 / pointBpms[k]

# Difficulty from the words of the title or a name, or the play level
func guessDifficulty(name : String) -> String:
	for text in [title, name]:
		for word in DIFFICULTY_WORDS:
			if text.to_lower().contains(word[0]):
				return word[1]
	return "Lv.%d" % playLevel if playLevel > 0 else "Normal"
