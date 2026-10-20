extends Node
class_name BmsPlayer

# Plays the keysounds of a BMS or bmson chart, like ModPlayer for the modules.
# Notes in a player's chart only sound when the player hits them, the other sounds are played on time as background music.
# Each sound has its own voice: playing a sound again cuts it, like in LR2 and beatoraja.

# Formats Godot can read, tried in this order when the file of a sound is missing (a .wav given as .ogg is common)
const SOUND_EXTENSIONS : Array = ["ogg", "wav", "mp3"]
# A sliced bmson sound already playing near its position goes on instead of restarting (seconds)
const CONTINUE_TOLERANCE : float = 0.05

var chart : BmsChart
var playing : bool = false
# Duration including the lead-in (seconds)
var length : float = 0.0

# Stream of each sound (null if it could not be loaded) and its voice
var streams : Array = []
var voices : Array = []
# Keysound event played by each voice (-1 if none)
var voiceNote : PackedInt32Array = []
# Number of players having each event in their chart, 0 for background music
var owners : PackedByteArray = []
# Events already played by a hit or by the background music
var triggered : PackedByteArray = []
# Next event to check in time order
var nextNote : int = 0
var startUsec : int = 0

func _init(_chart : BmsChart, dir : String) -> void:
	chart = _chart
	owners.resize(chart.keysounds.size())
	triggered.resize(chart.keysounds.size())
	var files : Dictionary = {}
	indexFiles(dir, "", files)
	for sound in chart.soundFiles.size():
		streams.append(loadSound(dir, chart.soundFile(sound), files))
	voices.resize(streams.size())
	voiceNote.resize(streams.size())
	voiceNote.fill(-1)
	# A sound plays to its end or until it is played again
	var nextTime : Dictionary = {}
	for i in range(chart.keysounds.size() - 1, -1, -1):
		var event : Dictionary = chart.keysounds[i]
		var s : int = event.sound
		if streams[s] == null:
			continue
		length = maxf(length, minf(event.time + streams[s].get_length() - event.offset, nextTime.get(s, INF)))
		nextTime[s] = event.time
		if voices[s] == null:
			var voice : AudioStreamPlayer = AudioStreamPlayer.new()
			voice.stream = streams[s]
			voice.volume_db = linear_to_db(chart.volume) if chart.volume > 0.0 else -80.0
			add_child(voice)
			voices[s] = voice
	length += BmsChart.LEAD_IN

# Files of the chart folder and its subfolders: lower case path without extension -> paths
static func indexFiles(dir : String, prefix : String, files : Dictionary) -> void:
	var access : DirAccess = DirAccess.open(dir.path_join(prefix))
	if access == null:
		return
	for sub in access.get_directories():
		indexFiles(dir, prefix.path_join(sub), files)
	for file in access.get_files():
		var key : String = prefix.path_join(file.get_basename()).to_lower()
		if not files.has(key):
			files[key] = []
		files[key].append(prefix.path_join(file))

# Load a sound, the names are not case sensitive like on Windows and the extension may differ
static func loadSound(dir : String, file : String, files : Dictionary) -> AudioStream:
	file = file.replace("\\", "/").trim_prefix("./")
	var candidates : Array = files.get(file.get_basename().to_lower(), [])
	var wanted : String = file.get_extension().to_lower()
	var extensions : Array = SOUND_EXTENSIONS.duplicate()
	if wanted in extensions:
		extensions.erase(wanted)
		extensions.push_front(wanted)
	for extension in extensions:
		for candidate in candidates:
			if candidate.get_extension().to_lower() != extension:
				continue
			var path : String = dir.path_join(candidate)
			var stream : AudioStream = null
			match extension:
				"ogg":
					stream = AudioStreamOggVorbis.load_from_file(path)
				"wav":
					stream = AudioStreamWAV.load_from_file(path)
				"mp3":
					stream = AudioStreamMP3.load_from_file(path)
			if stream != null:
				return stream
	return null

# The notes of a chart only sound when they are hit
func claim(keysounds : Array) -> void:
	for lane in keysounds:
		for i in lane:
			if i >= 0:
				owners[i] += 1

func play() -> void:
	startUsec = Time.get_ticks_usec()
	playing = true

func get_playback_position() -> float:
	return (Time.get_ticks_usec() - startUsec) / 1000000.0 if playing else 0.0

# Time in the song (without the lead-in)
func songTime() -> float:
	return get_playback_position() - BmsChart.LEAD_IN

# A note of a chart is hit
func hit(i : int) -> void:
	if i >= 0 and not triggered[i]:
		trigger(i, songTime(), false)

# A key is pressed without a note to hit, play the sound of the lane
func preview(i : int) -> void:
	if i >= 0:
		var was_triggered : int = triggered[i]
		trigger(i, songTime(), false)
		triggered[i] = was_triggered

func _process(_delta) -> void:
	if not playing:
		return
	var t : float = songTime()
	while nextNote < chart.keysounds.size() and chart.keysounds[nextNote].time <= t:
		var event : Dictionary = chart.keysounds[nextNote]
		var s : int = event.sound
		if owners[nextNote] == 0:
			# Background music, unless a later note of the sound was already hit early
			if voiceNote[s] < nextNote or not triggered[voiceNote[s]]:
				trigger(nextNote, t, true)
		elif event.cut and not triggered[nextNote] and voiceNote[s] < nextNote and voices[s] != null:
			# Sliced sound not hit yet: the previous slice stops
			voices[s].stop()
			voiceNote[s] = -1
		nextNote += 1

# Start a sound on its voice. On time sounds start where they should be if the frame is late.
func trigger(i : int, t : float, on_time : bool) -> void:
	var event : Dictionary = chart.keysounds[i]
	var voice : AudioStreamPlayer = voices[event.sound]
	triggered[i] = 1
	if voice == null:
		return
	voiceNote[event.sound] = i
	var position : float = event.offset + (maxf(t - event.time, 0.0) if on_time else 0.0)
	# The next slice of a bmson sound continues the one playing
	if event.offset > 0.0 and voice.playing and absf(voice.get_playback_position() - position) < CONTINUE_TOLERANCE:
		return
	voice.play(position)
