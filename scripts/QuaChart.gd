extends RefCounted
class_name QuaChart

# A Quaver beatmap (.qua), the chart format of TrackerMania.
# Only the YAML written by Quaver is read: the top level fields and the TimingPoints and HitObjects lists.

# Silence before the music starts (seconds), the first notes need time to come down
const LEAD_IN : float = 2.0
# TrackerMania lane (0~6 keys) of each Quaver lane, the scratch is the extra last lane (HasScratchKey)
const LANES : Dictionary = {
	"Keys7": [0, 1, 2, 3, 4, 5, 6],
	"Keys4": [1, 2, 3, 4],
}
const SCRATCH_LANE : int = 7
# Beats in a measure for the Quaver time signatures
const SIGNATURES : Dictionary = {"Quadruple": 4, "Triple": 3}
# Shorter measures (absurd BPMs used for effects) get no line (seconds)
const MIN_MEASURE : float = 0.05
# Level given for the average and the peak note density (notes per second), the music select has levels 1~8
const LEVEL_PER_NPS : float = 0.5
const LEVEL_PER_PEAK_NPS : float = 0.25
# Window used to measure the peak density (seconds)
const DENSITY_WINDOW : float = 2.0
const MAX_LEVEL : int = 8

var title : String = ""
var artist : String = ""
var difficultyName : String = ""
var audioFile : String = ""
# Start of the music select preview (seconds, without the lead-in), -1 if the chart has none
var previewTime : float = -1.0
# 8 lanes of notes, [time] or [time, length] for a long note, in seconds with the lead-in
var noteArray : Array = [[], [], [], [], [], [], [], []]
# Start time of each measure, in seconds with the lead-in
var measures : Array = []
# Tempo changes as [time, bpm], the time includes LEAD_IN
var bpmChanges : Array = []
var level : int = 1

# Read a .qua file, null if it is not a chart TrackerMania can play
static func load_file(path : String) -> QuaChart:
	var text : String = FileAccess.get_file_as_string(path)
	if text == "":
		return null
	var chart : QuaChart = QuaChart.new()
	return chart if chart.parse(text) else null

func parse(text : String) -> bool:
	var fields : Dictionary = {}
	var lists : Dictionary = {"TimingPoints": [], "HitObjects": []}
	var list : Array = []
	var item : Dictionary = {}
	var itemIndent : int = -1
	for line in text.split("\n"):
		var content : String = line.strip_edges()
		if content == "" or content.begins_with("#"):
			continue
		var indent : int = line.length() - line.lstrip(" ").length()
		if indent == 0 and not content.begins_with("-"):
			var field : Array = splitField(content)
			fields[field[0]] = field[1]
			list = lists.get(field[0], [])
			itemIndent = -1
		elif content.begins_with("-") and (itemIndent == -1 or indent == itemIndent):
			# New item of the list
			itemIndent = indent
			item = {}
			list.append(item)
			content = content.substr(1).strip_edges()
			if content != "":
				var field : Array = splitField(content)
				item[field[0]] = field[1]
		elif itemIndent != -1 and indent == itemIndent + 2 and not content.begins_with("-"):
			var field : Array = splitField(content)
			item[field[0]] = field[1]
		# Deeper lines (key sounds) are not used

	var lanes : Array = LANES.get(fields.get("Mode", ""), []).duplicate()
	if lanes.is_empty():
		return false
	if fields.get("HasScratchKey", "").to_lower() == "true":
		lanes.append(SCRATCH_LANE)
	title = fields.get("Title", "")
	artist = fields.get("Artist", "")
	difficultyName = fields.get("DifficultyName", "")
	audioFile = fields.get("AudioFile", "")
	if fields.has("SongPreviewTime"):
		previewTime = fields["SongPreviewTime"].to_float() / 1000.0

	# Quaver times are in milliseconds, a missing StartTime is 0
	var lastTime : float = 0.0
	for object in lists["HitObjects"]:
		var lane : int = object.get("Lane", "0").to_int() - 1
		if lane < 0 or lane >= lanes.size():
			continue
		var start : float = object.get("StartTime", "0").to_float() / 1000.0
		var end : float = object.get("EndTime", "0").to_float() / 1000.0
		if end > start:
			noteArray[lanes[lane]].append([start + LEAD_IN, end - start])
		else:
			noteArray[lanes[lane]].append([start + LEAD_IN])
		lastTime = maxf(lastTime, maxf(start, end))
	for notes in noteArray:
		notes.sort_custom(func(a, b): return a[0] < b[0])
	buildMeasures(lists["TimingPoints"], lastTime)
	computeLevel()
	return true

# "Key: value" -> [key, value]
static func splitField(content : String) -> Array:
	var colon : int = content.find(": ")
	if colon == -1:
		return [content.trim_suffix(":"), ""]
	return [content.left(colon), unquote(content.substr(colon + 2).strip_edges())]

static func unquote(value : String) -> String:
	if value.length() >= 2 and value.begins_with("'") and value.ends_with("'"):
		return value.substr(1, value.length() - 2).replace("''", "'")
	if value.length() >= 2 and value.begins_with("\"") and value.ends_with("\""):
		# Double quoted YAML escapes are close enough to JSON
		var parsed = JSON.parse_string(value)
		return parsed if parsed is String else value.substr(1, value.length() - 2)
	return value

# A line at each timing point, then one per measure until the next timing point
func buildMeasures(timingPoints : Array, end : float) -> void:
	var points : Array = timingPoints.filter(func(p): return p.get("Bpm", "0").to_float() > 0.0)
	points.sort_custom(func(a, b): return a.get("StartTime", "0").to_float() < b.get("StartTime", "0").to_float())
	for k in points.size():
		var beats : int = SIGNATURES.get(points[k].get("Signature", ""), 4)
		var length : float = 60.0 / points[k]["Bpm"].to_float() * beats
		bpmChanges.append([points[k].get("StartTime", "0").to_float() / 1000.0 + LEAD_IN, points[k]["Bpm"].to_float()])
		if length < MIN_MEASURE:
			continue
		var time : float = points[k].get("StartTime", "0").to_float() / 1000.0
		var next : float = points[k + 1].get("StartTime", "0").to_float() / 1000.0 if k + 1 < points.size() else end
		# The first tempo also goes back to the start of the song
		if k == 0:
			time -= ceilf((time + LEAD_IN) / length) * length
		while time < next - 0.001:
			measures.append(time + LEAD_IN)
			time += length

# Level from the average and the peak note density
func computeLevel() -> void:
	level = densityLevel(noteArray)

# Level of 8 lanes of notes (also used by the BMS charts)
static func densityLevel(lanes : Array) -> int:
	var times : Array = []
	for notes in lanes:
		for note in notes:
			times.append(note[0])
	if times.size() < 2:
		return 1
	times.sort()
	var span : float = maxf(times[-1] - times[0], 1.0)
	var peak : int = 0
	var first : int = 0
	for k in times.size():
		while times[k] - times[first] > DENSITY_WINDOW:
			first += 1
		peak = maxi(peak, k - first + 1)
	var nps : float = times.size() / span
	return clampi(roundi(nps * LEVEL_PER_NPS + peak / DENSITY_WINDOW * LEVEL_PER_PEAK_NPS), 1, MAX_LEVEL)
