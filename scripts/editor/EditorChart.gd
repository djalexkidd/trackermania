extends RefCounted
class_name EditorChart

# A BMS chart in the editor: the objects are placed in beats, their times come from the tempo (see beatToTime()).
# Read from a .bms/.bme/.bml and written back as BMS text, its keysounds are files of the song folder.
# Notes: {lane, beat, length (0 for a normal note), sound}, background sounds: {beat, sound}, sound -1 is silent.

const EXTENSIONS : Array = ["bms", "bme", "bml"]
const SIDE_LANES : int = 8
const DOUBLE_LANES : int = 16
const SCRATCH_LANE : int = 7
# Channel digit of each lane of a side, keys 1~7 then the scratch (see BmsChart.KEY_CHANNELS)
const LANE_CHANNELS : Array = ["1", "2", "3", "4", "5", "8", "9", "6"]
const BASE36 : String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const BASE62 : String = BASE36 + "abcdefghijklmnopqrstuvwxyz"
# Two objects closer than this are at the same place (beats)
const EPSILON : float = 0.0001
# Finest division of a measure line when writing, and the error allowed (beats)
const MAX_DIVISION : int = 3840
const DIVISION_ERROR : float = 0.0005
const DEFAULT_BPM : float = 130.0
# Folder of the sounds cut by the editor (AudioSlicer)
const SLICE_FOLDER : String = "slices"
# Header commands written by the editor, the other ones are written back as they were
const OWN_COMMANDS : Array = ["#PLAYER", "#GENRE", "#TITLE", "#SUBTITLE", "#ARTIST", "#BPM", "#PLAYLEVEL", "#DIFFICULTY", "#LNTYPE", "#LNOBJ", "#BASE"]
# Fields saved by snapshot() for undo
const STATE : Array = ["title", "subtitle", "artist", "genre", "difficulty", "playLevel", "bpm", "double",
	"sounds", "notes", "bgm", "bpmChanges", "stops", "measureLengths"]

var path : String = ""
var title : String = ""
var subtitle : String = ""
var artist : String = ""
var genre : String = ""
# Index of BmsChart.DIFFICULTIES (1 Beginner ~ 5 Leggendaria)
var difficulty : int = 2
var playLevel : int = 1
var bpm : float = DEFAULT_BPM
var double : bool = false
# Sound files, relative to the folder of the chart
var sounds : PackedStringArray = []
var notes : Array = []
var bgm : Array = []
# Tempo changes {beat, bpm} and stops {beat, length in 1/192 of a 4/4 measure}
var bpmChanges : Array = []
var stops : Array = []
# Length of the measures that are not 4/4 (1 = 4 beats)
var measureLengths : Dictionary = {}
# Lines the editor does not use (BGA, mines...), written back as they were
var extraHeader : PackedStringArray = []
var extraLines : PackedStringArray = []
# The file had #RANDOM blocks, only their first branch is edited
var hadRandom : bool = false

# Timeline of the tempo, and the beat of the start of each measure
var timing : BmsChart = BmsChart.new()
var measureStarts : PackedFloat64Array = [0.0]

func _init() -> void:
	rebuildTiming()

static func is_editable(file : String) -> bool:
	return file.get_extension().to_lower() in EXTENSIONS

static func load_file(file : String) -> EditorChart:
	var bytes : PackedByteArray = FileAccess.get_file_as_bytes(file)
	if bytes.is_empty():
		return null
	var chart : EditorChart = EditorChart.new()
	chart.path = file
	# One character per byte like BmsChart, the texts are decoded from Shift-JIS or UTF-8
	chart.parse(bytes.get_string_from_ascii())
	chart.rebuildTiming()
	return chart

func folder() -> String:
	return path.get_base_dir()

func difficultyName() -> String:
	return BmsChart.DIFFICULTIES[difficulty]

func lanes() -> int:
	return DOUBLE_LANES if double else SIDE_LANES

# Reading

func parse(text : String) -> void:
	var wavs : Dictionary = {}
	var bpmDefs : Dictionary = {}
	var stopDefs : Dictionary = {}
	var lnObjects : Dictionary = {}
	# [measure, channel, data] of each channel line
	var lines : Array = []
	var base62 : bool = false
	# #RANDOM values, and for each #IF: [this branch is read, a branch was already read]
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
		# Control flow: the first branch of each #RANDOM
		match command:
			"#RANDOM", "#SETRANDOM":
				hadRandom = true
				randoms.append(1 if command == "#RANDOM" else maxi(value.to_int(), 1))
				continue
			"#ENDRANDOM":
				randoms.pop_back()
				continue
			"#IF":
				var read : bool = not randoms.is_empty() and value.to_int() == randoms[-1]
				conditions.append([read, read])
				continue
			"#ELSEIF":
				if not conditions.is_empty():
					var read : bool = not conditions[-1][1] and not randoms.is_empty() and value.to_int() == randoms[-1]
					conditions[-1] = [read, conditions[-1][1] or read]
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
				if data.to_float() > 0.0:
					measureLengths[measure] = data.to_float()
			elif channel in ["01", "03", "08", "09", BmsChart.PEDAL_CHANNEL] or isKeyChannel(channel):
				lines.append([measure, channel, data])
			else:
				extraLines.append(ShiftJIS.decode(line))
			continue
		if command.length() == 6 and command.begins_with("#WAV"):
			wavs[line.substr(4, 2)] = ShiftJIS.decode(value)
		elif command.length() == 6 and command.begins_with("#BPM"):
			bpmDefs[line.substr(4, 2)] = value.to_float()
		elif command.length() == 7 and command.begins_with("#STOP"):
			stopDefs[line.substr(5, 2)] = value.to_float()
		elif command == "#LNOBJ":
			lnObjects[value] = true
		elif command == "#BASE":
			base62 = value == "62"
		elif command in OWN_COMMANDS:
			match command:
				"#TITLE": title = ShiftJIS.decode(value)
				"#SUBTITLE": subtitle = ShiftJIS.decode(value)
				"#ARTIST": artist = ShiftJIS.decode(value)
				"#GENRE": genre = ShiftJIS.decode(value)
				"#BPM": bpm = value.to_float() if value.to_float() > 0.0 else DEFAULT_BPM
				"#PLAYLEVEL": playLevel = value.to_int()
				"#DIFFICULTY": difficulty = clampi(value.to_int(), 1, BmsChart.DIFFICULTIES.size() - 1)
				"#PLAYER": double = value == "3"
		else:
			extraHeader.append(ShiftJIS.decode(line))

	# The ids are case sensitive only with #BASE 62
	if not base62:
		for dictionary in [wavs, bpmDefs, stopDefs, lnObjects]:
			var copy : Dictionary = dictionary.duplicate()
			dictionary.clear()
			for id in copy:
				dictionary[id.to_upper()] = copy[id]
	var ids : Array = wavs.keys()
	ids.sort_custom(func(a, b): return idValue(a) < idValue(b))
	var soundIds : Dictionary = {}
	for id in ids:
		soundIds[id] = sounds.size()
		sounds.append(wavs[id])

	# [lane, beat] -> id, a later line replaces the notes of an earlier one
	var visible : Dictionary = {}
	var long : Dictionary = {}
	for l in lines:
		var channel : String = l[1]
		var data : String = l[2] if base62 else l[2].to_upper()
		var count : int = data.length() / 2
		var start : float = measureBeat(l[0])
		var span : float = measureBeat(l[0] + 1) - start
		for k in count:
			var id : String = data.substr(k * 2, 2)
			if id == "00":
				continue
			var beat : float = start + span * k / count
			match channel:
				"01", BmsChart.PEDAL_CHANNEL:
					if soundIds.has(id):
						bgm.append({"beat": beat, "sound": soundIds[id]})
				"03":
					bpmChanges.append({"beat": beat, "bpm": float(id.hex_to_int())})
				"08":
					if bpmDefs.has(id) and bpmDefs[id] > 0.0:
						bpmChanges.append({"beat": beat, "bpm": bpmDefs[id]})
				"09":
					if stopDefs.has(id) and stopDefs[id] > 0.0:
						stops.append({"beat": beat, "length": stopDefs[id]})
				_:
					var lane : int = LANE_CHANNELS.find(channel[1]) + (SIDE_LANES if channel[0] in ["2", "6"] else 0)
					if channel[0] in ["1", "2"]:
						visible[[lane, beat]] = id
					else:
						long[[lane, beat]] = id

	for lane in DOUBLE_LANES:
		var heads : Array = []
		for key in visible:
			if key[0] == lane:
				heads.append([key[1], visible[key]])
		heads.sort()
		# #LNOBJ: this object ends the long note started by the previous note of the lane
		var laneNotes : Array = []
		for head in heads:
			if lnObjects.has(head[1]) and laneNotes and laneNotes[-1]["length"] == 0.0:
				laneNotes[-1]["length"] = head[0] - laneNotes[-1]["beat"]
			else:
				laneNotes.append({"lane": lane, "beat": head[0], "length": 0.0, "sound": soundIds.get(head[1], -1)})
		# Long note channels: one object starts the long note, the next one ends it
		var ends : Array = []
		for key in long:
			if key[0] == lane:
				ends.append([key[1], long[key]])
		ends.sort()
		for k in range(0, ends.size() - 1, 2):
			laneNotes.append({"lane": lane, "beat": ends[k][0], "length": ends[k + 1][0] - ends[k][0], "sound": soundIds.get(ends[k][1], -1)})
		notes.append_array(laneNotes)
	double = double or notes.any(func(n): return n.lane >= SIDE_LANES)

static func isKeyChannel(channel : String) -> bool:
	return channel[0] in ["1", "2", "5", "6"] and channel[1] in LANE_CHANNELS and channel != BmsChart.PEDAL_CHANNEL

static func idValue(id : String) -> int:
	return BASE62.find(id[0]) * 62 + BASE62.find(id[1])

# Writing

func save() -> Error:
	var file : FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(toBms())
	file.close()
	return OK

# The sounds actually used are numbered from 01, #BASE 62 when there are too many for base 36
func toBms() -> String:
	var used : Array = []
	for list in [notes, bgm]:
		for object in list:
			if object.sound >= 0 and not object.sound in used:
				used.append(object.sound)
	used.sort()
	var base62 : bool = used.size() >= BASE36.length() * BASE36.length() - 1
	var ids : Dictionary = {}
	for k in used.size():
		ids[used[k]] = encodeId(k + 1, base62)
	# A note without sound points to an id without file
	var silent : String = encodeId(used.size() + 1, base62)

	var header : PackedStringArray = ["", "*---------------------- HEADER FIELD", ""]
	header.append("#PLAYER %d" % (3 if double else 1))
	header.append("#GENRE " + genre)
	header.append("#TITLE " + title)
	if subtitle != "":
		header.append("#SUBTITLE " + subtitle)
	header.append("#ARTIST " + artist)
	header.append("#BPM " + number(bpm))
	header.append("#PLAYLEVEL %d" % playLevel)
	header.append("#DIFFICULTY %d" % difficulty)
	header.append("#LNTYPE 1")
	header.append_array(extraHeader)
	if base62:
		header.append("#BASE 62")
	header.append("")
	for sound in used:
		header.append("#WAV%s %s" % [ids[sound], sounds[sound]])

	# Objects of each measure: [channel, beat, id], several lines when two objects of a channel are at the same place
	var objects : Dictionary = {}
	for e in bgm:
		if e.sound >= 0:
			addObject(objects, "01", e.beat, ids[e.sound])
	var bpmIds : Dictionary = {}
	var stopIds : Dictionary = {}
	var definitions : PackedStringArray = []
	for change in bpmChanges:
		if change.bpm == int(change.bpm) and change.bpm >= 1 and change.bpm <= 255:
			addObject(objects, "03", change.beat, "%02X" % int(change.bpm))
			continue
		if not bpmIds.has(change.bpm):
			bpmIds[change.bpm] = encodeId(bpmIds.size() + 1, base62)
			definitions.append("#BPM%s %s" % [bpmIds[change.bpm], number(change.bpm)])
		addObject(objects, "08", change.beat, bpmIds[change.bpm])
	for stop in stops:
		if not stopIds.has(stop.length):
			stopIds[stop.length] = encodeId(stopIds.size() + 1, base62)
			definitions.append("#STOP%s %s" % [stopIds[stop.length], number(stop.length)])
		addObject(objects, "09", stop.beat, stopIds[stop.length])
	for n in notes:
		var side : int = 1 if n.lane < SIDE_LANES else 2
		var digit : String = LANE_CHANNELS[n.lane % SIDE_LANES]
		var id : String = ids.get(n.sound, silent)
		if n.length > EPSILON:
			addObject(objects, str(side + 4) + digit, n.beat, id)
			addObject(objects, str(side + 4) + digit, n.beat + n.length, id)
		else:
			addObject(objects, str(side) + digit, n.beat, id)
	header.append_array(definitions)

	var body : PackedStringArray = ["", "*---------------------- MAIN DATA FIELD", ""]
	var measures : Array = objects.keys()
	for m in measureLengths:
		if not m in measures:
			measures.append(m)
	measures.sort()
	for m in measures:
		if measureLength(m) != 1.0:
			body.append("#%03d02:%s" % [m, number(measureLength(m))])
		var channels : Dictionary = objects.get(m, {})
		var names : Array = channels.keys()
		names.sort()
		for channel in names:
			for line in channels[channel]:
				body.append("#%03d%s:%s" % [m, channel, measureData(m, line)])
		body.append("")
	body.append_array(extraLines)
	return "\r\n".join(header + body) + "\r\n"

# Put an object on the first line of its channel free at its place
func addObject(objects : Dictionary, channel : String, beat : float, id : String) -> void:
	var m : int = measureAt(beat)
	if not objects.has(m):
		objects[m] = {}
	if not objects[m].has(channel):
		objects[m][channel] = []
	for line in objects[m][channel]:
		if not line.any(func(o): return absf(o[0] - beat) < EPSILON):
			line.append([beat, id])
			return
	objects[m][channel].append([[beat, id]])

# Data of a channel line: the smallest division of the measure where all its objects fall
func measureData(m : int, line : Array) -> String:
	var start : float = measureBeat(m)
	var span : float = measureBeat(m + 1) - start
	var division : int = MAX_DIVISION
	for d in range(1, MAX_DIVISION + 1):
		var fits : bool = true
		for o in line:
			var place : float = (o[0] - start) / span * d
			if absf(place - roundf(place)) * span / d > DIVISION_ERROR:
				fits = false
				break
		if fits:
			division = d
			break
	var cells : PackedStringArray = []
	cells.resize(division)
	cells.fill("00")
	for o in line:
		cells[clampi(roundi((o[0] - start) / span * division), 0, division - 1)] = o[1]
	return "".join(cells)

static func encodeId(value : int, base62 : bool) -> String:
	var digits : String = BASE62 if base62 else BASE36
	return digits[(value / digits.length()) % digits.length()] + digits[value % digits.length()]

# A number without a useless ".0"
static func number(value : float) -> String:
	return str(int(value)) if value == int(value) else str(value)

# Undo

func snapshot() -> Dictionary:
	var state : Dictionary = {}
	for field in STATE:
		var value = get(field)
		state[field] = value.duplicate(true) if value is Array or value is Dictionary else value.duplicate() if value is PackedStringArray else value
	return state

func restore(state : Dictionary) -> void:
	for field in STATE:
		var value = state[field]
		set(field, value.duplicate(true) if value is Array or value is Dictionary else value.duplicate() if value is PackedStringArray else value)
	rebuildTiming()

# Time

# Call after a change of the tempo, the stops or the measure lengths
func rebuildTiming() -> void:
	var events : Array = []
	for change in bpmChanges:
		events.append([change.beat, 0, change.bpm])
	for stop in stops:
		# Stops are in 1/192 of a 4/4 measure
		events.append([stop.beat, 1, stop.length / 48.0])
	timing.buildTimeline(bpm, events)
	measureStarts = [0.0]

func beatToTime(beat : float) -> float:
	if beat < 0.0:
		return beat * 60.0 / timing.pointBpms[0]
	return timing.beatToTime(beat)

func timeToBeat(time : float) -> float:
	if time < 0.0:
		return time * timing.pointBpms[0] / 60.0
	var k : int = maxi(timing.pointTimes.bsearch(time, false) - 1, 0)
	# Points at the same time: the last one, after its stop
	var passed : float = time - timing.pointTimes[k] - timing.pointStops[k]
	if passed <= 0.0:
		return timing.pointBeats[k]
	return timing.pointBeats[k] + passed * timing.pointBpms[k] / 60.0

func bpmAt(beat : float) -> float:
	return timing.pointBpms[maxi(timing.pointBeats.bsearch(beat + EPSILON, true) - 1, 0)]

func measureLength(m : int) -> float:
	return measureLengths.get(m, 1.0)

func measureBeat(m : int) -> float:
	while measureStarts.size() <= m:
		measureStarts.append(measureStarts[-1] + 4.0 * measureLength(measureStarts.size() - 1))
	return measureStarts[maxi(m, 0)]

func measureAt(beat : float) -> int:
	while measureStarts[-1] <= beat:
		measureBeat(measureStarts.size())
	return maxi(measureStarts.bsearch(beat + EPSILON, true) - 1, 0)

# Objects

func noteAt(lane : int, beat : float):
	for n in notes:
		if n.lane == lane and absf(n.beat - beat) < EPSILON:
			return n
	return null

# No other note of the lane between the start and the end of this one
func laneFree(lane : int, beat : float, length : float, ignored : Array = []) -> bool:
	for n in notes:
		if n.lane == lane and not ignored.has(n) and beat <= n.beat + n.length + EPSILON and n.beat <= beat + length + EPSILON:
			return false
	return true

func isSlice(sound : int) -> bool:
	return sound >= 0 and sound < sounds.size() and sounds[sound].begins_with(SLICE_FOLDER + "/")

# Index of a sound file, added if it is new
func addSound(file : String) -> int:
	var index : int = sounds.find(file)
	if index == -1:
		sounds.append(file)
		index = sounds.size() - 1
	return index

func soundUses(sound : int) -> int:
	var count : int = 0
	for list in [notes, bgm]:
		for object in list:
			if object.sound == sound:
				count += 1
	return count

func lastBeat() -> float:
	var last : float = 0.0
	for n in notes:
		last = maxf(last, n.beat + n.length)
	for list in [bgm, bpmChanges, stops]:
		for object in list:
			last = maxf(last, object.beat)
	return last

# Notes in the format of the game (8 or 16 lanes of [time]), for the level of QuaChart.densityLevel()
func noteTimes() -> Array:
	var result : Array = []
	for lane in lanes():
		result.append([])
	for n in notes:
		if n.lane < result.size():
			result[n.lane].append([beatToTime(n.beat)])
	return result
