extends Node
class_name ModPlayer

# Plays a module with one voice per channel like on the Amiga.
# Notes in a player's chart only sound when the player hits them (keysounds),
# the other notes are played on time as background music.

# Rate of the sample streams, the pitch of each note is set with pitch_scale
const MIX_RATE : int = 8363
# Stereo separation of the Amiga channels (left, right, right, left), 1.0 is hard panning
const STEREO_SEPARATION : float = 0.6

var module : ModModule
var playing : bool = false
# Duration including the lead-in (seconds)
var length : float = 0.0

# AudioStreamWAV of each sample (null for empty samples)
var streams : Array = []
# Pitch correction of each sample from its finetune
var finetunes : PackedFloat32Array = []
var voices : Array = []
# Note played by each voice (-1 if none) and its next envelope value
var voiceNote : PackedInt32Array = []
var voiceEnv : PackedInt32Array = []
# Number of players having each note in their chart, 0 for background music
var owners : PackedByteArray = []
# Notes already played by a hit or by the background music
var triggered : PackedByteArray = []
# Next note to check in time order
var nextNote : int = 0
var gain : float = 1.0
var startUsec : int = 0
# Song time at startUsec, and its speed (TRAINING plays slower, the voices are slowed as much)
var startTime : float = 0.0
var rate : float = 1.0

# The voices go to the panning buses sending to the bus send (the music select preview has its own)
func _init(_module : ModModule, send : String = "Master") -> void:
	module = _module
	length = module.length + ModChart.LEAD_IN
	owners.resize(module.notes.size())
	triggered.resize(module.notes.size())
	gain = 1.0 / sqrt(module.channels)
	for s in module.samples:
		finetunes.append(pow(2.0, s.finetune / 96.0))
		if s.data.size() <= 2:
			streams.append(null)
			continue
		var stream : AudioStreamWAV = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_8_BITS
		stream.mix_rate = MIX_RATE
		stream.data = s.data
		if s.loop_length > 2:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = s.loop_start
			stream.loop_end = s.loop_start + s.loop_length
		streams.append(stream)
	for c in module.channels:
		var voice : AudioStreamPlayer = AudioStreamPlayer.new()
		voice.bus = panningBus(-1.0 if c % 4 in [0, 3] else 1.0, send)
		add_child(voice)
		voices.append(voice)
		voiceNote.append(-1)
		voiceEnv.append(0)

# Bus panning the voices of one side, created once and kept for the next songs
static func panningBus(side : float, send : String = "Master") -> String:
	var bus_name : String = ("ModLeft" if side < 0 else "ModRight") + ("" if send == "Master" else send)
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var index : int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, send)
		var panner : AudioEffectPanner = AudioEffectPanner.new()
		panner.pan = side * STEREO_SEPARATION
		AudioServer.add_bus_effect(index, panner)
	return bus_name

# The notes of a chart only sound when they are hit
func claim(keysounds : Array) -> void:
	for lane in keysounds:
		for i in lane:
			owners[i] += 1

func play() -> void:
	startUsec = Time.get_ticks_usec()
	startTime = 0.0
	playing = true

# Start again at a time of the module, the earlier notes are skipped (music select preview, TRAINING at a slower rate)
func play_from(t : float, song_rate : float = 1.0) -> void:
	stop()
	triggered.fill(0)
	nextNote = 0
	while nextNote < module.notes.size() and module.notes[nextNote].time < t:
		nextNote += 1
	play()
	startTime = t + ModChart.LEAD_IN
	rate = song_rate

func stop() -> void:
	playing = false
	for c in voices.size():
		voices[c].stop()
		voiceNote[c] = -1

func get_playback_position() -> float:
	return startTime + (Time.get_ticks_usec() - startUsec) / 1000000.0 * rate if playing else 0.0

# Time in the module (without the lead-in)
func songTime() -> float:
	return get_playback_position() - ModChart.LEAD_IN

# A note of a chart is hit
func hit(i : int) -> void:
	if i >= 0 and not triggered[i]:
		trigger(i, songTime(), false)

# A key is pressed without a note to hit, play the sound of the lane
func preview(i : int) -> void:
	if i >= 0:
		var t : float = songTime()
		var was_triggered : int = triggered[i]
		trigger(i, t, false)
		triggered[i] = was_triggered

func _process(_delta) -> void:
	if not playing:
		return
	var t : float = songTime()
	while nextNote < module.notes.size() and module.notes[nextNote].time <= t:
		var c : int = module.notes[nextNote].channel
		if owners[nextNote] == 0:
			# Background music, unless a later note of the channel was already hit early
			if voiceNote[c] < nextNote or not triggered[voiceNote[c]]:
				trigger(nextNote, t, true)
		elif not triggered[nextNote] and voiceNote[c] < nextNote:
			# Not hit yet: the previous note of the channel stops like in the module
			voices[c].stop()
			voiceNote[c] = -1
		nextNote += 1
	for c in voices.size():
		updateVoice(c, t, true)

# Start a note on the voice of its channel. On time notes start where they should be if the frame is late.
func trigger(i : int, t : float, on_time : bool) -> void:
	var note : Dictionary = module.notes[i]
	var c : int = note.channel
	triggered[i] = 1
	voiceNote[c] = i
	voiceEnv[c] = 0
	updateVoice(c, t, false)
	var voice : AudioStreamPlayer = voices[c]
	voice.stream = streams[note.sample]
	var late : float = maxf(t - note.time, 0.0) * voice.pitch_scale / rate if on_time else 0.0
	voice.play(note.offset / float(MIX_RATE) + late)

# Apply the pitch and volume automation of the note played by a voice
func updateVoice(c : int, t : float, retrigger : bool) -> void:
	var i : int = voiceNote[c]
	if i < 0:
		return
	var note : Dictionary = module.notes[i]
	var env : Array = note.env
	var e : int = voiceEnv[c]
	# A note hit early keeps its first pitch and volume until its time
	var current : int = maxi(e - 4, 0)
	while e < env.size() and env[e] <= t - note.time:
		if retrigger and env[e + 3] > 0.0:
			voices[c].play(note.offset / float(MIX_RATE))
		current = e
		e += 4
	voiceEnv[c] = e
	var period : float = env[current + 1]
	if period > 0:
		voices[c].pitch_scale = ModModule.AMIGA_CLOCK / period / MIX_RATE * finetunes[note.sample] * rate
	var volume : float = env[current + 2] / 64.0 * gain
	voices[c].volume_db = linear_to_db(volume) if volume > 0.0 else -80.0
