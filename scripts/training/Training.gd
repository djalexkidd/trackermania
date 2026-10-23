class_name Training

# TRAINING mode like IIDX: a song is chosen in the music select, then a section of it (first and last measure)
# is played again and again, at the normal speed or slower. Nothing is saved.
# The state is static like Arcade, it lasts from scene to scene until the main menu stops it.

# PLAY SPEED: rate of the song, NORMAL then slower
const SPEEDS = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
# SELECT MODE: the player alone, the DOUBLE PLAY, or the BATTLE where the 2P side plays the chart mirrored
const MODES = ["SINGLE PLAY", "DOUBLE PLAY", "BATTLE"]
enum {SINGLE, DOUBLE, BATTLE}
# Bus of the slowed music: a pitch shifter keeps the pitch of the song
const BUS = "Training"
const PITCH_FFT = AudioEffectPitchShift.FFT_SIZE_1024
const PITCH_FFT_SAMPLES = 1024
const PITCH_OVERSAMPLING = 4

static var active := false
# Difficulties of the song played in both styles ({path, difficulty_name, level, double...}, from song_entry.all_charts)
static var charts: Array = []
# Player who chose the song, the one who plays in SINGLE PLAY and DOUBLE PLAY
static var player := 1
# Song of the section below, another song starts from its whole length
static var song := ""
# Section in measures from 1, last_measure 0 is the end of the song
static var first_measure := 1
static var last_measure := 0
static var speed_index := 0
static var repeat := false
# The game scene is opened again for another mode or difficulty: no DECIDE screen
static var reload := false

static func start() -> void:
	active = true
	reload = false

static func stop() -> void:
	active = false
	reload = false
	set_bus_rate(1.0)

# A song is chosen in the music select
static func choose_song(song_charts: Array, path: String) -> void:
	charts = song_charts.duplicate()
	reload = false
	if Global.p1_joined != Global.p2_joined:
		player = 1 if Global.p1_joined else 2
	var key = Arcade.song_key(path)
	if key != song:
		song = key
		first_measure = 1
		last_measure = 0

static func current_mode() -> int:
	if Global.is_battle():
		return BATTLE
	return DOUBLE if Global.is_double_play() else SINGLE

# Charts of a style, in the order of the song
static func style_charts(double: bool) -> Array:
	return charts.filter(func(chart): return chart["double"] == double)

# Chart of the song played in a mode: the same difficulty, else the same place, null when the style has none
static func mode_chart(mode: int):
	var list = style_charts(mode == DOUBLE)
	if list.is_empty():
		return null
	for chart in list:
		if chart["difficulty_name"] == Loader.chart_difficulty:
			return chart
	return list[mini(Loader.difficulty_slot, list.size() - 1)]

# Players and options of a mode, and its chart
static func set_mode(mode: int) -> void:
	var chart = mode_chart(mode)
	Global.battle = mode == BATTLE
	Global.set_player_var(player, "double_play", mode == DOUBLE)
	Global.p1_joined = mode == BATTLE or player == 1
	Global.p2_joined = mode == BATTLE or player == 2
	Loader.file_path = chart["path"]
	Loader.chart_difficulty = chart["difficulty_name"]
	Loader.difficulty_slot = style_charts(mode == DOUBLE).find(chart)

static func rate() -> float:
	return SPEEDS[speed_index]

static func speed_name() -> String:
	return "NORMAL" if speed_index == 0 else "x%.1f" % rate()

# The bus of the music, the pitch shifter only works below the normal speed
static func bus() -> String:
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		var index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
		var shifter = AudioEffectPitchShift.new()
		shifter.fft_size = PITCH_FFT
		shifter.oversampling = PITCH_OVERSAMPLING
		AudioServer.add_bus_effect(index, shifter)
		AudioServer.set_bus_effect_enabled(index, 0, false)
	return BUS

# The song played at this rate keeps its pitch
static func set_bus_rate(song_rate: float) -> void:
	var index = AudioServer.get_bus_index(BUS)
	if index == -1:
		return
	var shifter: AudioEffectPitchShift = AudioServer.get_bus_effect(index, 0)
	shifter.pitch_scale = 1.0 / song_rate
	AudioServer.set_bus_effect_enabled(index, 0, song_rate != 1.0)

# Delay of the pitch shifter (seconds of real time), the notes come later by as much
static func audio_delay() -> float:
	var index = AudioServer.get_bus_index(BUS)
	if not active or index == -1 or not AudioServer.is_bus_effect_enabled(index, 0):
		return 0.0
	return (PITCH_FFT_SAMPLES - PITCH_FFT_SAMPLES / PITCH_OVERSAMPLING) / AudioServer.get_mix_rate()
