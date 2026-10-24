extends RefCounted
class_name ModChart

# Turns the notes of a module into a noiseBMS chart, the module is the chart.
# The notes given to the player are keysounds, the others are played automatically as background music.

# max_nps: note density limit, max_chord: notes at the same time, scratch: one sound goes to the scratch lane
const DIFFICULTIES : Dictionary = {
	"Normal": {"max_nps": 4.0, "max_chord": 2, "scratch": true},
	"Hyper": {"max_nps": 8.0, "max_chord": 3, "scratch": true},
	"Another": {"max_nps": INF, "max_chord": 8, "scratch": true},
}
# Silence before the song starts (seconds)
const LEAD_IN : float = 2.0
# Window used to measure the note density (seconds)
const DENSITY_WINDOW : float = 2.0
# Minimum time between two notes of the same lane (seconds)
const LANE_MIN_GAP : float = 0.1
# Faster notes of the same lane go to the next lanes when possible (seconds)
const LANE_COMFORT_GAP : float = 0.25
# Notes closer than this are a chord (seconds)
const CHORD_TIME : float = 0.001
# A sound needs this many notes to go to the scratch lane
const SCRATCH_MIN_NOTES : int = 4
const SCRATCH_LANE : int = 7
# Double play: the 2P side takes the lanes 8~15 (keys, then its scratch), with more notes for the two hands
const SIDE_LANES : int = 8
const DOUBLE_NPS_FACTOR : float = 1.5
const DOUBLE_EXTRA_CHORD : int = 1
# Level given for each note per second, the music select has levels 1~8
const LEVEL_PER_NPS : float = 0.6
const MAX_LEVEL : int = 8

# 8 lanes of note time information (16 in double play), like the JSON charts
var noteArray : Array = []
# Index of the keysound (in module.notes) of each note of noteArray
var keysoundArray : Array = []
var level : int = 1
# Lanes of the keys from left to right, and of the scratches (one per side in double play)
var keyLanes : Array = []
var scratchLanes : Array = []

func _init(module : ModModule, difficulty : String, keys : int = 7, double : bool = false) -> void:
	var settings : Dictionary = DIFFICULTIES.get(difficulty, DIFFICULTIES["Another"]).duplicate()
	var sides : int = 2 if double else 1
	for side in sides:
		for lane in SIDE_LANES:
			noteArray.append([])
			keysoundArray.append([])
		keyLanes.append_array(range(side * SIDE_LANES, side * SIDE_LANES + keys))
		scratchLanes.append(side * SIDE_LANES + SCRATCH_LANE)
	if double:
		settings.max_nps *= DOUBLE_NPS_FACTOR
		settings.max_chord += DOUBLE_EXTRA_CHORD
	assignLanes(module.notes, selectNotes(module.notes, settings), settings.scratch)
	var times : Array = []
	for lane in noteArray:
		for note in lane:
			times.append(note[0])
	if times.size() > 1:
		var span : float = maxf(times.max() - times.min(), 1.0)
		level = clampi(roundi(times.size() / span * LEVEL_PER_NPS), 1, MAX_LEVEL)

# Weight of a row in the pattern, notes on the beats are kept first in the easy difficulties
static func rowWeight(row : int) -> int:
	if row == 0:
		return 6
	var weight : int = 0
	while row % 2 == 0:
		row >>= 1
		weight += 1
	return weight

# Indices of the notes given to the player, in time order
func selectNotes(notes : Array, settings : Dictionary) -> Array:
	var candidates : Array = range(notes.size())
	candidates.sort_custom(func(a, b):
		var weight_a : int = rowWeight(notes[a].row)
		var weight_b : int = rowWeight(notes[b].row)
		return weight_a > weight_b if weight_a != weight_b else a < b)
	var max_count : float = settings.max_nps * DENSITY_WINDOW
	var times : PackedFloat64Array = []
	var selected : Array = []
	for i in candidates:
		var t : float = notes[i].time
		if times.bsearch(t + DENSITY_WINDOW / 2, false) - times.bsearch(t - DENSITY_WINDOW / 2) >= max_count:
			continue
		if times.bsearch(t + CHORD_TIME, false) - times.bsearch(t - CHORD_TIME) >= settings.max_chord:
			continue
		times.insert(times.bsearch(t), t)
		selected.append(i)
	selected.sort()
	return selected

# Notes of the same instrument start from the same lane, higher pitches go to the right
func assignLanes(notes : Array, selected : Array, scratch : bool) -> void:
	var keys : int = keyLanes.size()
	var groups : Dictionary = {}
	for i in selected:
		var key : int = notes[i].instrument
		if not groups.has(key):
			groups[key] = []
		if not notes[i].period in groups[key]:
			groups[key].append(notes[i].period)
	var group_keys : Array = groups.keys()
	group_keys.sort()
	var home : Dictionary = {}
	for g in group_keys.size():
		home[group_keys[g]] = int(g * keys / float(group_keys.size()))
		# Periods sorted from the lowest pitch (highest period) to the highest pitch
		groups[group_keys[g]].sort()
		groups[group_keys[g]].reverse()
	# The sounds with the fewest notes go to the scratch lanes, the lower one on the left in double play
	var scratch_groups : Array = []
	if scratch and group_keys.size() > scratchLanes.size():
		var counts : Dictionary = {}
		for i in selected:
			var key : int = notes[i].instrument
			counts[key] = counts.get(key, 0) + 1
		var candidates : Array = group_keys.filter(func(key): return counts[key] >= SCRATCH_MIN_NOTES)
		candidates.sort_custom(func(a, b): return counts[a] < counts[b] if counts[a] != counts[b] else a < b)
		scratch_groups = candidates.slice(0, scratchLanes.size())
		scratch_groups.sort_custom(func(a, b): return home[a] < home[b])
	var last_time : Array = []
	last_time.resize(noteArray.size())
	last_time.fill(-INF)
	for i in selected:
		var note : Dictionary = notes[i]
		var key : int = note.instrument
		var lane : int = -1
		var scratch_lane : int = scratchLanes[scratch_groups.find(key)] if key in scratch_groups else -1
		if scratch_lane != -1 and note.time - last_time[scratch_lane] >= LANE_MIN_GAP:
			lane = scratch_lane
		else:
			var wanted : int = home[key] + groups[key].find(note.period)
			lane = findFreeLane(wanted, keys, note.time, last_time, LANE_COMFORT_GAP)
			if lane == -1:
				lane = findFreeLane(wanted, keys, note.time, last_time, LANE_MIN_GAP)
		# No room for this note, it stays in the background music
		if lane == -1:
			continue
		last_time[lane] = note.time
		noteArray[lane].append([note.time + LEAD_IN])
		keysoundArray[lane].append(i)

# Nearest key lane from the wanted one without a note too close (positions in keyLanes)
func findFreeLane(wanted : int, keys : int, time : float, last_time : Array, gap : float) -> int:
	for distance in keys:
		for side in ([1] if distance == 0 else [1, -1]):
			var lane : int = keyLanes[posmod(wanted + distance * side, keys)]
			if time - last_time[lane] >= gap:
				return lane
	return -1
