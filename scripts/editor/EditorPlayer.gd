extends Node
class_name EditorPlayer

# Plays the chart of the BMS editor from any time: every keysound at its time (notes and background music),
# with the metronome and a tick on each note (hitsounds). Each sound has its own voice like in BmsPlayer.

const CLICK_VOLUME_DB : float = -4.0
const METRONOME_HZ : float = 1500.0
const METRONOME_ACCENT_HZ : float = 2200.0
const HITSOUND_HZ : float = 900.0

var chart : EditorChart
var metronome : bool = false
var hitsounds : bool = false
var playing : bool = false
# Speed of the playback, slower keeps the pitch (Training bus)
var rate : float = 1.0

# File -> stream (null if it could not be loaded)
var streams : Dictionary = {}
# Files of the folder, see BmsPlayer.indexFiles()
var files : Dictionary = {}
# Sound -> voice
var voices : Dictionary = {}
# [time, sound, note] in time order
var events : Array = []
var nextEvent : int = 0
var startUsec : int = 0
var startTime : float = 0.0
# Last metronome beat played: [measure, beat]
var lastTick : Array = []
var tickVoice : AudioStreamPlayer
var accentVoice : AudioStreamPlayer
var hitVoice : AudioStreamPlayer

func _ready() -> void:
	tickVoice = addVoice(AudioSlicer.click(METRONOME_HZ))
	accentVoice = addVoice(AudioSlicer.click(METRONOME_ACCENT_HZ))
	hitVoice = addVoice(AudioSlicer.click(HITSOUND_HZ, 0.03))
	hitVoice.max_polyphony = 8

func addVoice(stream : AudioStream) -> AudioStreamPlayer:
	var voice : AudioStreamPlayer = AudioStreamPlayer.new()
	voice.stream = stream
	voice.volume_db = CLICK_VOLUME_DB
	add_child(voice)
	return voice

func setChart(newChart : EditorChart) -> void:
	stop()
	chart = newChart
	streams.clear()
	files.clear()
	for voice in voices.values():
		voice.queue_free()
	voices.clear()
	loadSounds()

# Load the sounds not loaded yet (new files are indexed again)
func loadSounds() -> void:
	if chart == null:
		return
	var indexed : bool = false
	for file in chart.sounds:
		if streams.has(file):
			continue
		if not indexed:
			files.clear()
			BmsPlayer.indexFiles(chart.folder(), "", files)
			indexed = true
		streams[file] = BmsPlayer.loadSound(chart.folder(), file, files)

func stream(sound : int) -> AudioStream:
	if sound < 0 or sound >= chart.sounds.size():
		return null
	return streams.get(chart.sounds[sound])

func soundLength(sound : int) -> float:
	var s : AudioStream = stream(sound)
	return s.get_length() if s != null else 0.0

func voice(sound : int) -> AudioStreamPlayer:
	if not voices.has(sound):
		var s : AudioStream = stream(sound)
		if s == null:
			return null
		var player : AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = s
		add_child(player)
		voices[sound] = player
	return voices[sound]

# The events follow the chart, call after each change
func refresh() -> void:
	events.clear()
	if chart == null:
		return
	for e in chart.bgm:
		events.append([chart.beatToTime(e.beat), e.sound, false])
	for n in chart.notes:
		events.append([chart.beatToTime(n.beat), n.sound, true])
	events.sort_custom(func(a, b): return a[0] < b[0])
	if playing:
		var t : float = position()
		nextEvent = events.bsearch_custom(t, func(e, time): return e[0] <= time)

# End of the last sound (seconds)
func songLength() -> float:
	var length : float = 0.0
	for event in events:
		length = maxf(length, event[0] + (soundLength(event[1]) if event[1] >= 0 else 0.0))
	return length

func play_from(t : float, speed : float = 1.0) -> void:
	stop()
	rate = speed
	var bus : String = "Master"
	if rate != 1.0:
		bus = Training.bus()
	Training.set_bus_rate(rate)
	for v in voices.values():
		v.bus = bus
		v.pitch_scale = rate
	# The sounds started before and still playing go on from where they are
	nextEvent = 0
	while nextEvent < events.size() and events[nextEvent][0] < t:
		var event : Array = events[nextEvent]
		if event[1] >= 0 and event[0] + soundLength(event[1]) > t:
			start(event[1], t - event[0], bus)
		nextEvent += 1
	startUsec = Time.get_ticks_usec()
	startTime = t
	lastTick = []
	playing = true

func stop() -> void:
	if playing:
		startTime = position()
	playing = false
	for v in voices.values():
		v.stop()

func position() -> float:
	if not playing:
		return startTime
	return startTime + (Time.get_ticks_usec() - startUsec) / 1000000.0 * rate

# Time of what is heard now
func heardTime() -> float:
	if not playing:
		return startTime
	return position() - AudioServer.get_output_latency() * rate

# Play a sound alone (keysound list, notes clicked)
func preview(sound : int) -> void:
	var v : AudioStreamPlayer = voice(sound)
	if v != null:
		v.bus = "Master"
		v.pitch_scale = 1.0
		v.play()

func start(sound : int, offset : float, bus : String) -> void:
	var v : AudioStreamPlayer = voice(sound)
	if v == null:
		return
	v.bus = bus
	v.pitch_scale = rate
	v.play(offset)

func _process(_delta) -> void:
	if not playing or chart == null:
		return
	var t : float = position()
	var bus : String = "Master" if rate == 1.0 else Training.bus()
	while nextEvent < events.size() and events[nextEvent][0] <= t:
		var event : Array = events[nextEvent]
		# A frame late: the sound starts where it should be
		if event[1] >= 0:
			start(event[1], t - event[0], bus)
		if event[2] and hitsounds:
			hitVoice.play()
		nextEvent += 1
	if metronome:
		var beat : float = chart.timeToBeat(t)
		var m : int = chart.measureAt(beat)
		var tick : Array = [m, int(floor(beat - chart.measureBeat(m) + EditorChart.EPSILON))]
		if tick != lastTick:
			if not lastTick.is_empty():
				(accentVoice if tick[1] == 0 else tickVoice).play()
			lastTick = tick
