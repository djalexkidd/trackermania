extends Node2D
class_name Playfield

# The following code is based from https://github.com/scenent/gd-rhythm

# The perfect y coordinate to press on the screen (judge line)
const PERFECT_YPOS : float = 500
# Lanes: 7 keys and the scratch lane, on the left for 1P and on the right for 2P (mirrored)
const KEY_WIDTH : float = 100.0 * KEY_SCALE
const SCRATCH_WIDTH : float = 145.0 * SCRATCH_SCALE
# The turntable frame keeps the proportions of its art (144 x 130 px), square like on the cabinet
const SCRATCH_ART_SIZE : Vector2 = Vector2(144, 130)
# Centre of the disc hole in the turntable art, the disc is put there
const SCRATCH_HOLE_CENTER : Vector2 = Vector2(72, 72)
const SCRATCH_HEIGHT : float = SCRATCH_WIDTH * SCRATCH_ART_SIZE.y / SCRATCH_ART_SIZE.x
const SCRATCH_GAP : float = 8.0
const PLAYFIELD_WIDTH : float = SCRATCH_WIDTH + SCRATCH_GAP + 7 * KEY_WIDTH
# Keys row under the judge line: the red strip on top of the key art is the judge line, centred on PERFECT_YPOS
const KEYS_TOP : float = 497.0
# The art is drawn at these scales: 100 px per key in the key frame becomes one lane, the turntable is bigger than the keys
const KEY_SCALE : float = 0.4
const SCRATCH_SCALE : float = 0.6
# The keys are as high as the turntable frame, the key art is stretched vertically to fit (130 px tall)
const KEYS_HEIGHT : float = SCRATCH_HEIGHT
const KEY_SCALE_Y : float = KEYS_HEIGHT / 130.0
const KEYS_BOTTOM : float = KEYS_TOP + KEYS_HEIGHT
# Notes are a bit narrower than their lane
const NOTE_MARGIN : float = 2.0
# Metal rails on both sides of the lanes, the outer one shows the song progress like in IIDX
const RAIL_WIDTH : float = 12.0
# Metal plate under the lanes holding the screens of the HUD, it goes past the lanes towards the middle of the screen.
# The rectangles below are for the 1P side, mirrored on the 2P side (sideRect())
const PLATE_TOP : float = 500.0
const PLATE_RIGHT : float = 488.0
const PERCENT_SCREEN : Rect2 = Rect2(392, 526, 90, 46)
const GAUGE_LABEL_Y : float = 588.0
const GAUGE_SCREEN : Rect2 = Rect2(-4, 592, 484, 30)
# Groove gauge: 50 segments of 2 %, keeps the proportions of its art (1062 x 46)
const GAUGE_RECT : Rect2 = Rect2(5, 597, 466, 20)
const SCORE_SCREEN : Rect2 = Rect2(-4, 632, 284, 78)
const DIFFICULTY_SCREEN : Rect2 = Rect2(288, 632, 192, 78)
# Gauge texture geometry: one segment every 21 px (2 %), the gaps between them are around x = 21 n + 6
const GAUGE_SEGMENT_PX : float = 21.0
const GAUGE_GAP_PX : float = 6.0
# The playfield of a player who is not playing stays on screen, empty and a bit darker like on the cabinet
const IDLE_DIM : float = 0.7
# The two gauge segments before the last filled one flicker like in IIDX: 0 to 2 lit, drawn again at this interval (ms)
const GAUGE_FLICKER_SEGMENTS : int = 2
const GAUGE_FLICKER_MS : int = 50
# Height of the beam rising from a lane when its key is held (px), and how fast the burst of a hit note fades (per second)
const LANE_LIGHT_HEIGHT : float = 280.0
const HIT_FLASH_DECAY : float = 4.0
# Judgement over the key lanes: shown this long, it pops at first (s), the P-GREAT colors change at this interval (ms)
const JUDGE_Y : float = 380.0
const JUDGE_SIZE : int = 30
const JUDGE_TIME : float = 0.8
const JUDGE_POP_TIME : float = 0.06
const PGREAT_CYCLE_MS : int = 40
const JUDGE_WORDS : Dictionary = {"PGreat": "GREAT", "Great": "GREAT", "Good": "GOOD", "Bad": "BAD", "Poor": "POOR"}
const JUDGE_COLORS : Dictionary = {"Great": Color(1, 0.85, 0.1), "Good": Color(0.35, 1, 0.4), "Bad": Color(1, 0.25, 0.45), "Poor": Color(0.7, 0.7, 0.75)}
const PGREAT_COLORS : Array = [Color(1, 1, 1), Color(0.55, 1, 1), Color(1, 0.95, 0.45), Color(1, 0.65, 0.95)]
# After the last note is finished, wait for this margin and then the game ends.
const ENDPOS_BIAS : float = +2.0
# Auxiliary line spacing when the chart has no measures (sec)
const SUBLINE_LENGTH : float = 1.0
const FONT : Font = preload("res://assets/font/04B_20__.TTF")
const NUMBER_FONT : Font = preload("res://assets/font/digitalix.ttf")
const LANE_COLOR : Color = Color(0, 0, 0)
const LANE_BLACK_KEY_COLOR : Color = Color(0.035, 0.035, 0.045)
const LANE_GAP_COLOR : Color = Color(0.1, 0.1, 0.11)
const SEPARATOR_COLOR : Color = Color(0.22, 0.22, 0.25)
const BEAM_COLOR : Color = Color(0.25, 0.55, 1.0)
const BURST_COLOR : Color = Color(0.6, 0.85, 1.0)
const MEASURE_COLOR : Color = Color(0.6, 0.6, 0.65, 0.6)
# Metal of the frames: light at the top, darker at the bottom
const METAL_LIGHT : Color = Color(0.8, 0.82, 0.86)
const METAL_DARK : Color = Color(0.36, 0.38, 0.43)
const METAL_EDGE : Color = Color(0.1, 0.1, 0.12)
const SCREEN_COLOR : Color = Color(0.02, 0.025, 0.035)
const SCREEN_GLOW : Color = Color(0.2, 0.75, 1.0, 0.35)
const LABEL_COLOR : Color = Color(0.78, 0.82, 0.88)
const GAUGE_LABEL_COLOR : Color = Color(1, 0.55, 0.1)
const PROGRESS_COLOR : Color = Color(1, 0.55, 0.1)
const NUMBER_COLOR : Color = Color(0.4, 0.95, 1.0)
const NUMBER_DIM : Color = Color(0.4, 0.95, 1.0, 0.3)
const NUMBER_GHOST : Color = Color(0.4, 0.95, 1.0, 0.1)
# Tints of the lit keys (the black keys are darker, so their tint is brighter)
const KEY_LIGHT_WHITE : Color = Color(1.0, 0.25, 0.25)
const KEY_LIGHT_BLACK : Color = Color(2.6, 0.5, 0.5)
# Key faces in p1_frame.png: white keys 1/3/5/7 and black keys 2/4/6, one key every 198 px per color
const KEY_WHITE_RECT : Rect2 = Rect2(42, 31, 68, 75)
const KEY_BLACK_RECT : Rect2 = Rect2(137, 21, 72, 71)
const KEY_SPACING : float = 198
# Centre of the first key face in p1_frame.png: the frame is placed so that this face sits on the first lane
const FRAME_FIRST_KEY_X : float = 72.0

# Emitted in local versus when this player is done (song ended, failed or gave up)
signal finished
# Player number, picks the game options and where the results go
var player : int = 1
# Side of the screen, picks the layout and the input actions (p1_* or p2_*), the player's side except in double play
var side : int = 1
# This player plays on this playfield, otherwise it is only shown
var active : bool = false
# DOUBLE PLAY: the playfield of the other side, and the 1P side one which keeps the score, gauge and combo of both
var partner : Playfield = null
var scorer : Playfield = self
# Lanes of the chart taken by this side: 0~7, or 8~15 for the 2P side in double play
var laneOffset : int = 0
# Local versus flag (two playfields side by side, shared audio)
var versus : bool = false
# Online round (Netplay): same start for everyone, live ranking and the netplay results
var netplay : bool = false
# Autoplay flag
var AUTOPLAY : bool
var AUTOSCRATCH : bool
# Input action prefix of this player
var prefix : String
# 2P side layout like in IIDX (scratch lane on the right, HUD mirrored)
var mirrored : bool
# Key code for each of the 8 channels (7 keys, then the turntable)
var keycodes : PackedStringArray
# Audio Player Node Path
@export_node_path("AudioStreamPlayer") var audio
# Preload note scene
@onready var noteScene : Note = preload("res://scenes/game/note.tscn").instantiate()
# The time it takes for a note to descend from (y=0) to (y=PERFECT_YPOS)
var speed : float
# Note information corresponding to 7 channels
var noteArray      : Array = []
# Keysound of each note of noteArray (Amiga modules and BMS)
var keysoundArray  : Array   = [[], [], [], [], [], [], [], []]
# Keysound of the last note created in each lane
var lastKeysound   : Array   = [-1, -1, -1, -1, -1, -1, -1, -1]
# Lanes not played (5 keys mode), they are dimmed
var disabled       : Array   = [false, false, false, false, false, false, false, false]
# Keysound player shared by the playfields: ModPlayer for an Amiga module, BmsPlayer for a BMS (same methods)
var keysoundPlayer
# Start time of each measure of the chart (seconds)
var measures       : Array = []
# Tempo changes as [time, bpm]
var bpms           : Array = []
# Auxiliary line information
var subLineArray   : Array = []
# Time when the chart started, the music of a .qua starts after the lead-in
var startUsec      : int     = 0
var musicStarted   : bool    = false
# Current audio playback time (seconds)
var currentSongPos : float   = 0.0
# The y-coordinate at which the note descends per frame
var coordPerFrame  : float
# Time until game ends (in seconds)
var endPos         : float   = 0.0

# 7 cues containing currently valid note scenes
var queue          : Array   = [[], [], [], [], [], [], [], []]
# Check the pressed state of each channel
var pressed        : Array   = [false, false, false, false, false, false, false, false]
# Check if you should press and hold now
var shouldPress    : Array   = [false, false, false, false, false, false, false, false]
# The time when the currently pressed long note ends
var shouldPressEnd : Array   = [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0]
# Brightness of the flash of each lane after a note is hit, fades out
var hitFlash       : Array   = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
# Flag to check if the game is over
var done           : bool    = false
# Current combo count
var combo          : int     = 0
# Maximum number of combos
var comboMax       : int     = 0
# Current EX score
var exScore        : int     = 0
# Number of each judgement, for the netplay results
var judgeCounts    : Dictionary = {"PGreat": 0, "Great": 0, "Good": 0, "Bad": 0, "Poor": 0}
# Early and late GREAT, GOOD and BAD, and judgements that broke the combo, for the result screen
var fastCount      : int     = 0
var slowCount      : int     = 0
var comboBreak     : int     = 0
# Gauge after each judgement, as (song progress 0~1, shown gauge) for the graph of the result screen
var gaugeHistory   : PackedVector2Array = []
# Song shown on the result screen
var songInfo       : Dictionary = {}
# Number of judgements of the chart, a long note counts twice (press and release) like a CN
var noteCount      : int     = 0
# Groove gauge in percent (Judge rules), and what a PGREAT or GREAT recovers
var gauge          : float   = 0.0
var gaugeRecovery  : float   = 0.0
# Groove gauge bar, and the segments drawn over it by the flicker, and when the flicker was last drawn
var gaugeBar       : TextureProgressBar
var gaugeFlicker   : TextureRect
var gaugeFlickerMs : int     = 0
# Analog
var previous_value := 0.0
# The scratch lane stays lit this long after the analog turntable moved
const SCRATCH_LIGHT_MS : int = 100
var lastScratchMove : int = -SCRATCH_LIGHT_MS
# Turntable disc speed in turns per second, clockwise is positive
const DISC_SPEED     : float = 0.5
const DISC_SPEED_FWD : float = 2.0
const DISC_SPEED_REW : float = -1.5
# Direction of the last analog turntable move (1 forward, -1 rewind)
var scratchDirection : float = 1.0
# Position and width of each lane (0~6 keys, 7 scratch), in playfield coordinates
var laneLeft       : PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
var laneWidth      : PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
# Frames of the keys and of the scratch lane, and where the key frame is drawn
var keyFrame       : Texture2D
var scratchFrame   : Texture2D
var keyFrameOrigin : Vector2
# Last judgement shown over the lanes, when it was shown (ms), and the timing of the hit under it
var judgeShown     : String  = ""
var judgeMs        : int     = 0
var timingText     : String  = ""
var timingColor    : Color
# Nodes made by buildLayout()
var overlay        : Overlay
var disc           : Sprite2D

# Set the side of this playfield before start(): the player, whether it plays here, and the mode
func setup(p : int, plays : bool, both : bool, online : bool, s : int = p) -> void:
	player = p
	side = s
	active = plays
	versus = both
	netplay = online
	prefix = "p%d_" % side
	mirrored = side == 2
	keycodes = PackedStringArray([prefix + "key1", prefix + "key2", prefix + "key3", prefix + "key4",
		prefix + "key5", prefix + "key6", prefix + "key7", prefix + "digital_turntable_fwd"])
	buildLayout()
	if not active:
		modulate = Color(IDLE_DIM, IDLE_DIM, IDLE_DIM)
	set_process(false)

# DOUBLE PLAY: the two playfields play one chart, the 1P side counts for both
func pairWith(other : Playfield) -> void:
	partner = other
	other.partner = self
	other.scorer = self
	other.laneOffset = ModChart.SIDE_LANES

# Load the chart and start the playfield, called by main.gd for each player who plays
func start() -> void:
	if not active:
		return
	AUTOPLAY = opt("auto_play") and not Arcade.active
	AUTOSCRATCH = opt("auto_scratch")
	speed = opt("hispeed")
	if netplay:
		# Same #RANDOM branches for everyone
		seed(Netplay.room["seed"])
	if Loader.file_path.get_extension().to_lower() == "mod":
		if not loadModule():
			set_process(false)
			return
	elif BmsChart.is_bms(Loader.file_path):
		if not loadBms():
			set_process(false)
			return
	elif not loadQuaChart():
		set_process(false)
		return
	# Key lanes shuffled by RANDOM, the scratch lane never moves like in IIDX
	var lanes : Array = range(7)
	# The 6th and 7th keys are not played in 5 keys mode
	if opt("keys_mode") == 5:
		noteArray[5] = []
		noteArray[6] = []
		keysoundArray[5] = []
		keysoundArray[6] = []
		disabled[5] = true
		disabled[6] = true
		lanes = range(5)
	# In double play the 1P side counts the notes of both sides
	scorer.noteCount += Judge.noteCount(noteArray)
	Global.set_player_var(player, "combo_max_top", scorer.noteCount)

	# BATTLE: the 2P side plays the chart mirrored, like on IIDX
	if versus and Global.is_battle() and side == 2:
		var flippedNotes : Array = noteArray.duplicate()
		var flippedKeysounds : Array = keysoundArray.duplicate()
		for i in lanes.size():
			flippedNotes[lanes[i]] = noteArray[lanes[-1 - i]]
			flippedKeysounds[lanes[i]] = keysoundArray[lanes[-1 - i]]
		noteArray = flippedNotes
		keysoundArray = flippedKeysounds

	if opt("random"):
		randomize()
		# The keysounds follow their lane
		var shuffled : Array = lanes.duplicate()
		shuffled.shuffle()
		var shuffledNotes : Array = noteArray.duplicate()
		var shuffledKeysounds : Array = keysoundArray.duplicate()
		for i in lanes.size():
			shuffledNotes[lanes[i]] = noteArray[shuffled[i]]
			shuffledKeysounds[lanes[i]] = keysoundArray[shuffled[i]]
		noteArray = shuffledNotes
		keysoundArray = shuffledKeysounds

	if scorer == self:
		gauge = Judge.gaugeStart(opt("gauge_level"))
	# The 2P side of a double play starts after the 1P side, the recovery counts the notes of both
	scorer.gaugeRecovery = Judge.gaugeRecovery(opt("gauge_level"), scorer.noteCount)
	refreshHud()

	set_process(false)
	if AUTOPLAY:
		$isautoplay.visible = true
	var noteStart : float = INF
	for i in range(0, 8):
		if len(noteArray[i]) > 0:
			if (noteStart > noteArray[i][0][0]):
				noteStart = noteArray[i][0][0]
	if (noteStart <= speed):
		OS.alert("There is no enough space in front of note info")
	for key in keycodes:
		if key == "":
			OS.alert("Please assign a keycode")
			break
	if (audio == null):
		OS.alert("Please assign a AudioStreamPlayer node")
	if (keysoundPlayer == null and get_node(audio).stream == null):
		OS.alert("Please assign a music")
	for i in range(0, 8):
		noteArray[i] = getCorrectArr(noteArray[i], speed)
	coordPerFrame = getCoordPerFrame(speed, PERFECT_YPOS)
	for i in range(0, 8):
		if getEndPos(noteArray[i], speed, ENDPOS_BIAS) > endPos:
			endPos = getEndPos(noteArray[i], speed, ENDPOS_BIAS)
	if keysoundPlayer:
		# The background music goes on after the last note
		endPos = maxf(endPos, keysoundPlayer.length + ENDPOS_BIAS)
	# Both sides of a double play end together
	if partner:
		endPos = maxf(endPos, partner.endPos)
		partner.endPos = endPos
	if scorer == self:
		gaugeHistory.append(Vector2(0.0, shownGauge()))
	if measures:
		subLineArray = getLineArr(measures, speed)
	else:
		subLineArray = getSubLineArr(endPos, speed, SUBLINE_LENGTH)
	if keysoundPlayer:
		# Auto played notes are played on time by the background music
		for i in range(0, 8):
			if not AUTOPLAY and not (AUTOSCRATCH and i == 7):
				keysoundPlayer.claim([keysoundArray[i]])
	if netplay:
		# Everyone starts together once all the charts are loaded
		$getready.text = "Waiting for the DJs…"
		Netplay.mark_loaded()
		await Netplay.wait_begin()
		$getready.text = "Get Ready !"
	await get_tree().create_timer(1.0).timeout
	$getready.hide()
	if keysoundPlayer:
		if not keysoundPlayer.playing:
			keysoundPlayer.play()
	startUsec = Time.get_ticks_usec()
	set_process(true)

# Gets the end value of the note time information.
func getEndPos(array : Array, sp : float, bias : float) -> float:
	var result : float  = -1.0
	for noteInfo in array:
		if (len(noteInfo) == 1):
			if (result < noteInfo[0]):
				result = noteInfo[0]
		elif (len(noteInfo) == 2):
			if (result < noteInfo[0] + noteInfo[1]):
				result = noteInfo[0] + noteInfo[1]
	return result + sp + bias
# Get the coordinates at which the note should drop per frame.
func getCoordPerFrame(sp : float, perfectYpos : float) -> float:
	if (sp != 1.0):
		perfectYpos /= sp
		sp          /= sp
	perfectYpos /= Engine.get_frames_per_second()
	return perfectYpos
# Subtract the speed value from all note time information.
func getCorrectArr(array : Array, sp : float) -> Array:
	var result : Array = []
	for noteInfo in array:
		noteInfo[0] -= sp
		result.append(noteInfo)
	return result
# Get a list of auxiliary lines.
func getSubLineArr(endpos : float, sp : float, sec : float) -> Array:
	var arr : Array = []
	var index : float = sec
	while (index < endpos):
		arr.append(index)
		index += sec
	return getLineArr(arr, sp)
# Shift line times like the notes, dropping the lines too early to come from the top
func getLineArr(times : Array, sp : float) -> Array:
	var arr : Array = times.duplicate()
	for i in range(len(arr)):
		arr[i] -= sp
	while (arr and arr[0] < sp):
		arr.pop_front()
	return arr

# Get a game option of this player
func opt(option : String):
	return Global.get_player_var(player, option)

func load_mp3(path):
	var file = FileAccess.open(path, FileAccess.READ)
	var sound = AudioStreamMP3.new()
	sound.data = file.get_buffer(file.get_length())
	return sound

# Load the notes and the music of a Quaver beatmap
func loadQuaChart() -> bool:
	var chart : QuaChart = QuaChart.load_file(Loader.file_path)
	if chart == null:
		OS.alert("Invalid Quaver beatmap: " + Loader.file_path)
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu/music_select.tscn")
		return false
	noteArray = chart.noteArray
	measures = chart.measures
	bpms = chart.bpmChanges
	songInfo = {"title": chart.title, "artist": chart.artist, "level": chart.level}
	var audio_path : String = Loader.file_path.get_base_dir().path_join(chart.audioFile)
	# In local versus both playfields share the same audio player, only load it once
	if get_node(audio).stream == null:
		match chart.audioFile.get_extension().to_lower():
			"mp3":
				get_node(audio).stream = load_mp3(audio_path)
			"ogg":
				get_node(audio).stream = AudioStreamOggVorbis.load_from_file(audio_path)
	return true

# Generate the chart of an Amiga module, its notes are the keysounds
func loadModule() -> bool:
	# In local versus both playfields share the same module player, only load it once
	keysoundPlayer = get_node(audio).get_node_or_null("ModPlayer")
	if keysoundPlayer == null:
		var module : ModModule = ModModule.load_file(Loader.file_path)
		if module == null:
			OS.alert("Invalid Amiga module: " + Loader.file_path)
			get_tree().change_scene_to_file.call_deferred("res://scenes/menu/music_select.tscn")
			return false
		keysoundPlayer = ModPlayer.new(module)
		keysoundPlayer.name = "ModPlayer"
		get_node(audio).add_child(keysoundPlayer)
	var chart : ModChart = ModChart.new(keysoundPlayer.module, Loader.chart_difficulty, opt("keys_mode"), partner != null)
	noteArray = sideLanes(chart.noteArray)
	keysoundArray = sideLanes(chart.keysoundArray)
	songInfo = {"title": keysoundPlayer.module.title, "artist": "Amiga module", "level": chart.level}
	# The lines follow the measures of the module
	measures = keysoundPlayer.module.measures.map(func(t): return t + ModChart.LEAD_IN)
	bpms = moduleBpms(keysoundPlayer.module)
	return true

# Tempo of a module: a measure is 16 rows, four beats in the tracker convention
func moduleBpms(module : ModModule) -> Array:
	var result : Array = []
	for k in range(module.measures.size() - 1):
		var length : float = module.measures[k + 1] - module.measures[k]
		if length > 0.0:
			result.append([module.measures[k] + ModChart.LEAD_IN, 240.0 / length])
	return result

# Load a BMS or bmson chart and its keysounds
func loadBms() -> bool:
	# In local versus both playfields share the same player, and the same #RANDOM branches
	keysoundPlayer = get_node(audio).get_node_or_null("BmsPlayer")
	if keysoundPlayer == null:
		var chart : BmsChart = BmsChart.load_file(Loader.file_path)
		if chart == null:
			OS.alert("Invalid BMS chart: " + Loader.file_path)
			get_tree().change_scene_to_file.call_deferred("res://scenes/menu/music_select.tscn")
			return false
		keysoundPlayer = BmsPlayer.new(chart, Loader.file_path.get_base_dir())
		keysoundPlayer.name = "BmsPlayer"
		get_node(audio).add_child(keysoundPlayer)
	# The notes are changed while playing, each playfield has its copy
	noteArray = sideLanes(keysoundPlayer.chart.noteArray.duplicate(true))
	keysoundArray = sideLanes(keysoundPlayer.chart.keysoundArray.duplicate(true))
	measures = keysoundPlayer.chart.measures.duplicate()
	bpms = bmsBpms(keysoundPlayer.chart)
	songInfo = {"title": keysoundPlayer.chart.title, "artist": keysoundPlayer.chart.artist, "level": keysoundPlayer.chart.level}
	return true

# The 8 lanes of this side in the lanes of a chart, the 2P side of a double play takes the lanes 8~15
func sideLanes(lanes : Array) -> Array:
	var result : Array = lanes.slice(laneOffset, laneOffset + ModChart.SIDE_LANES)
	while result.size() < ModChart.SIDE_LANES:
		result.append([])
	return result

# Tempo changes of a BMS chart, with the lead-in like its notes
func bmsBpms(chart : BmsChart) -> Array:
	var result : Array = []
	for k in chart.pointTimes.size():
		result.append([chart.pointTimes[k] + BmsChart.LEAD_IN, chart.pointBpms[k]])
	return result

# Tempo at the current song position, 0 when the chart has none
func currentBpm() -> float:
	var bpm : float = bpms[0][1] if bpms else 0.0
	for change in bpms:
		if change[0] > currentSongPos:
			break
		bpm = change[1]
	return bpm

# Current time of the song (seconds)
func songPosition() -> float:
	if keysoundPlayer:
		return keysoundPlayer.get_playback_position()
	var player : AudioStreamPlayer = get_node(audio)
	var clock : float = (Time.get_ticks_usec() - startUsec) / 1000000.0
	# The music starts after the lead-in, the playfields share it in versus
	if not musicStarted and clock >= QuaChart.LEAD_IN:
		musicStarted = true
		if not player.playing:
			player.play(clock - QuaChart.LEAD_IN)
	# Before and after the music, the clock goes on alone
	if not player.playing:
		return clock
	# The playback position only moves at each audio mix, the time since then makes it smooth
	return QuaChart.LEAD_IN + player.get_playback_position() + AudioServer.get_time_since_last_mix()

func _process(delta) -> void:
	queue_redraw()
	overlay.queue_redraw()
	spinDisc(delta)
	for i in range(0, 8):
		hitFlash[i] = maxf(hitFlash[i] - delta * HIT_FLASH_DECAY, 0.0)
	# Get current audio playback time
	currentSongPos = songPosition()
	# The notes come later when the sound is late (output latency and user offset)
	currentSongPos -= AudioServer.get_output_latency() + Global.audio_offset / 1000.0
	# Confirm game end
	if (currentSongPos >= endPos):
		finish(false)
		return
	if netplay:
		Netplay.send_live(exScore, noteCount * 2, int(shownGauge()), combo)
	if Time.get_ticks_msec() - gaugeFlickerMs >= GAUGE_FLICKER_MS:
		gaugeFlickerMs = Time.get_ticks_msec()
		flickerGauge()
	# Confirm completion of long note
	for i in range(0, 8):
		if shouldPressEnd[i] == -1.0:
			continue
		if (AUTOPLAY or (AUTOSCRATCH and i == 7)) and shouldPressEnd[i] <= currentSongPos:
			endLongnote(i, "PGreat")
		elif currentSongPos - shouldPressEnd[i] > Judge.BAD_WINDOW / 1000.0:
			# Still held long after the end
			endLongnote(i, "Bad", currentSongPos - shouldPressEnd[i])
	# Create a note
	for i in range(0, 8):
		if (noteArray[i] and noteArray[i][0][0] <= currentSongPos):
			var note : Note = noteScene.duplicate()
			note.autoScratch = AUTOSCRATCH
			if keysoundArray[i]:
				note.keysound = keysoundArray[i].pop_front()
				lastKeysound[i] = note.keysound
			var info : Array = noteArray[i].pop_front()
			note.hitTime = info[0] + speed
			note.perfectYpos = PERFECT_YPOS
			if (len(info) == 1):
				# Create a general note
				note.setNote(i+1, speed, coordPerFrame, laneWidth[i] - 2 * NOTE_MARGIN)
			else:
				# Create long note
				note.setNote(i+1, speed, coordPerFrame, laneWidth[i] - 2 * NOTE_MARGIN, info[1])
			var container = get_node("container" + str(i+1))
			container.add_child(note)
			container.get_child(container.get_child_count()-1).position.x = laneX(i)
			container.get_child(container.get_child_count()-1).position.y = notePosition(note.hitTime)
			queue[i].append(container.get_child(container.get_child_count()-1))
	# Create auxiliary line
	if (subLineArray and subLineArray[0] <= currentSongPos):
		var line : Line2D = Line2D.new()
		line.set_meta("time", subLineArray.pop_front() + speed)
		line.width = 1
		line.default_color = MEASURE_COLOR
		line.points = [Vector2(0, 0), Vector2(PLAYFIELD_WIDTH, 0)]
		$sublinecontainer.add_child(line)
	# Move & Delete Auxiliary Lines
	for line in $sublinecontainer.get_children():
		line.position.y = notePosition(line.get_meta("time"))
		if line.position.y >= PERFECT_YPOS:
			line.queue_free()
	# Give up (works in auto play too)
	if Input.is_action_just_pressed(prefix + "meta"):
		finish(true)
		return
	# Check auto play
	if (AUTOPLAY):
		autoplay()
		killGarbage()
		return
	if (AUTOSCRATCH):
		autoscratch()
	# Assign points to all notes in the queue
	updateQueue()
	# Input verification and [Failure while holding down long note] processing
	updateInputState()
	# [Failure to press at all, normal note and long note] Processing
	dequeue()
	# Delete all notes that are outside the screen
	killGarbage()

func autoscratch():
	if (queue[7] and queue[7][0] == null):
		queue[7].pop_front()
	if (queue[7] and queue[7][0].isLongnote == false):
		if (queue[7][0].hitTime <= currentSongPos):
			queue[7][0].score = "PGreat"
			hitFlash[7] = 1.0
			addJudge(queue[7][0].score)
			queue[7][0].free()
			queue[7].pop_front()
	elif (queue[7] and queue[7][0].isLongnote == true and queue[7][0].longnoteScore == ""):
		if (queue[7][0].hitTime <= currentSongPos):
			queue[7][0].score = "PGreat"
			hitFlash[7] = 1.0
			startLongnote(7)

func autoplay():
	for i in range(0, 8):
		if (queue[i] and queue[i][0] == null):
			queue[i].pop_front()
		if (queue[i] and queue[i][0].isLongnote == false):
			if (queue[i][0].hitTime <= currentSongPos):
				queue[i][0].score = "PGreat"
				hitFlash[i] = 1.0
				addJudge(queue[i][0].score)
				queue[i][0].free()
				queue[i].pop_front()
		elif (queue[i] and queue[i][0].isLongnote == true and queue[i][0].longnoteScore == ""):
			if (queue[i][0].hitTime <= currentSongPos):
				queue[i][0].score = "PGreat"
				hitFlash[i] = 1.0
				startLongnote(i)

# Called when the i-th channel key is pressed, returns false if there was no note to hit
func keyPressed(i : int) -> bool:
	# The long note is already held (analog turntable)
	if shouldPress[i]:
		return true
	# If the first note in that channel is scored
	if len(queue[i]) != 0 and queue[i][0].score != "Default":
		showTiming(queue[i][0])
		hitFlash[i] = 1.0
		# The keysound plays even for a bad timing like in IIDX
		if keysoundPlayer:
			keysoundPlayer.hit(queue[i][0].keysound)
		if queue[i][0].isLongnote == false:
			# General note
			addJudge(queue[i][0].score, currentSongPos - queue[i][0].hitTime)
			queue[i][0].free()
			queue[i].pop_front()
		elif queue[i][0].score == "Bad":
			# Long note failure, its release is lost too
			addJudge("Bad", currentSongPos - queue[i][0].hitTime)
			addJudge("Poor")
			queue[i][0].longnoteFailed()
			queue[i].pop_front()
		else:
			# Long note normal entry
			startLongnote(i, currentSongPos - queue[i][0].hitTime)
		return true
	return false

# A judgement of a note of this side: counted by the scorer, shown over these lanes
# offset is how late the hit was in seconds (negative when early), 0 when there was no hit
func addJudge(judgement : String, offset : float = 0.0) -> void:
	scorer.countJudge(judgement, offset)
	showJudge(judgement)

# Count a judgement: EX score, gauge, then combo (GOOD keeps it, BAD and POOR break it like in IIDX)
func countJudge(judgement : String, offset : float) -> void:
	exScore += Judge.EX_POINTS.get(judgement, 0)
	judgeCounts[judgement] += 1
	# FAST/SLOW like in IIDX: the PGREATs and the missed notes are not counted
	if offset != 0.0 and judgement in ["Great", "Good", "Bad"]:
		if offset < 0.0:
			fastCount += 1
		else:
			slowCount += 1
	updateGauge(judgement)
	if judgement == "Bad" or judgement == "Poor":
		comboBreak += 1
		combo = 0
	else:
		combo += 1
		comboMax = maxi(comboMax, combo)

# Show a judgement over the lanes, with the combo after it
func showJudge(judgement : String) -> void:
	judgeShown = judgement
	judgeMs = Time.get_ticks_msec()

# Apply a judgement to the groove gauge, the HARD gauge fails at 0
func updateGauge(judgement : String) -> void:
	gauge = Judge.gaugeChange(opt("gauge_level"), judgement, gauge, gaugeRecovery)
	refreshHud()
	gaugeHistory.append(Vector2(clampf(currentSongPos / endPos, 0.0, 1.0), shownGauge()))
	if gauge <= 0.0:
		# Deferred because the note queues are still being iterated
		finish.call_deferred(true)

# Gauge as shown on the screen, by steps of 2 %
func shownGauge() -> float:
	return float(Judge.gaugeDisplay(opt("gauge_level"), scorer.gauge))

# Gauge shown under the keys (both sides in double play), the numbers of the HUD are drawn with the overlay
func refreshHud() -> void:
	for field in [self, partner]:
		if field:
			field.gaugeBar.value = shownGauge()
			field.overlay.queue_redraw()

# A key pressed without a note to hit: an empty POOR if a note comes soon, it only hurts the gauge
func emptyPress(i : int) -> void:
	previewKeysound(i)
	var next : float = INF
	for n in queue[i]:
		if n != null and n.longnoteScore == "":
			next = n.hitTime
			break
	if next == INF and noteArray[i]:
		next = noteArray[i][0][0] + speed
	if next - currentSongPos <= Judge.EMPTY_POOR_WINDOW / 1000.0:
		# Counted in the POORs and the miss count like in IIDX, but it does not break the combo
		scorer.judgeCounts["Poor"] += 1
		scorer.updateGauge("EmptyPoor")
		showJudge("Poor")

# Show how early (-) or late (+) a note was hit, measured like the judgement from its y position
func showTiming(n : Note) -> void:
	if not Global.show_timing:
		return
	var ms : int = roundi((currentSongPos - n.hitTime) * 1000.0)
	timingText = "%+dms" % ms
	# Fast in blue, slow in red like in IIDX
	timingColor = Color(0.3, 0.6, 1) if ms < 0 else Color(1, 0.3, 0.3)

# Play the keysound of the next note of a lane when its key is pressed without a note to hit
func previewKeysound(i : int) -> void:
	if keysoundPlayer == null:
		return
	for n in queue[i]:
		if n != null:
			keysoundPlayer.preview(n.keysound)
			return
	keysoundPlayer.preview(keysoundArray[i][0] if keysoundArray[i] else lastKeysound[i])

# Judge the notes from the time left before them
func updateQueue() -> void:
	for q in queue:
		for n in q:
			if n.longnoteScore == "":
				var judgement : String = Judge.judge(currentSongPos - n.hitTime)
				n.score = judgement if judgement != "" else "Default"

# Press a long note: the head is judged, the release will be judged at its end
func startLongnote(i : int, offset : float = 0.0) -> void:
	addJudge(queue[i][0].score, offset)
	shouldPress[i] = true
	shouldPressEnd[i] = queue[i][0].hitTime + queue[i][0].longnoteTime
	queue[i][0].longnoteStart()

# Judge the release of the held long note of a lane
func endLongnote(i : int, judgement : String, offset : float = 0.0) -> void:
	addJudge(judgement, offset)
	if judgement == "Poor":
		queue[i][0].longnoteFailed()
	queue[i].pop_front()
	shouldPress[i] = false
	shouldPressEnd[i] = -1.0

# Y position of a note at the current time, it reaches PERFECT_YPOS at its time
func notePosition(time : float) -> float:
	return PERFECT_YPOS * (1.0 - (time - currentSongPos) / speed)

# Turn the disc: slowly clockwise, faster with Scratch+, backwards with Scratch-
func spinDisc(delta : float) -> void:
	var turns : float = DISC_SPEED
	if Input.is_action_pressed(prefix + "digital_turntable_fwd"):
		turns = DISC_SPEED_FWD
	elif Input.is_action_pressed(prefix + "digital_turntable_rew"):
		turns = DISC_SPEED_REW
	elif Time.get_ticks_msec() - lastScratchMove < SCRATCH_LIGHT_MS:
		turns = DISC_SPEED_FWD if scratchDirection > 0 else DISC_SPEED_REW
	disc.rotation += TAU * turns * delta

func updateInputState() -> void:
	# Get the current analog value from the turntable
	var current_value := Input.get_action_strength(prefix + "analog_turntable_fwd") - Input.get_action_strength(prefix + "analog_turntable_rew")
	# Check if the analog value has changed since the last frame
	if current_value != previous_value:
		keyPressed(7)
		lastScratchMove = Time.get_ticks_msec()
		# A jump of more than half the range is the axis wrapping around
		var move : float = current_value - previous_value
		scratchDirection = signf(move) if absf(move) < 1.0 else -signf(move)
		# Update the previous value to the current one
		previous_value = current_value

	if (Input.is_action_just_pressed(prefix + "digital_turntable_rew")):
		if not keyPressed(7):
			emptyPress(7)

	# Scratch held while a digital direction is held or just after the analog turntable moved
	pressed[7] = Input.is_action_pressed(prefix + "digital_turntable_fwd") or Input.is_action_pressed(prefix + "digital_turntable_rew") \
		or Time.get_ticks_msec() - lastScratchMove < SCRATCH_LIGHT_MS

	for i in range(0, 8):
		if (Input.is_action_just_pressed(keycodes[i])):
			if i != 7:
				pressed[i] = true
			if not keyPressed(i):
				emptyPress(i)
		if (Input.is_action_just_released(keycodes[i]) and i != 7):
			pressed[i] = false
		if (pressed[i] == false and shouldPress[i] and not (AUTOSCRATCH and i == 7)):
			# Long note released, too early it is a POOR
			var judgement : String = Judge.judge(currentSongPos - shouldPressEnd[i])
			endLongnote(i, judgement if judgement != "" else "Poor", currentSongPos - shouldPressEnd[i] if judgement != "" else 0.0)

func dequeue() -> void:
	for i in range(0, 8):
		if (len(queue[i]) != 0 and queue[i][0] != null and currentSongPos - queue[i][0].hitTime > Judge.BAD_WINDOW / 1000.0):
			# If it's a long note
			if (queue[i][0].isLongnote == true):
				# If you didn't press it in the first place, the press and the release are missed
				if (not shouldPress[i]):
					timingText = ""
					queue[i][0].longnoteFailed()
					queue[i].pop_front()
					addJudge("Poor")
					addJudge("Poor")
			# If it's a general note
			else:
				timingText = ""
				queue[i].pop_front()
				addJudge("Poor")

func killGarbage() -> void:
	for i in range(1, 9):
		for n in get_node("container" + str(i)).get_children():
			# The late notes stay until they are judged
			if (n.position.y - n.effect.size.y >= 600 and not queue[i-1].has(n)):
				n.free()

# Stop playing and clear the lanes
func stop() -> void:
	done = true
	set_process(false)
	pressed.fill(false)
	hitFlash.fill(0.0)
	queue_redraw()
	for i in $sublinecontainer.get_children(): i.free()
	for i in range(1, 9):
		for n in get_node("container" + str(i)).get_children():
			n.queue_free()
	queue = [[], [], [], [], [], [], [], []]

# Store this player's results, then show them (or wait for the other player in versus)
func finish(failed : bool) -> void:
	# In double play the 1P side ends the play of both sides
	if scorer != self:
		scorer.finish(failed)
		return
	if done:
		return
	stop()
	if partner:
		partner.stop()
	var double : bool = partner != null
	Global.set_player_var(player, "failed", failed)
	Global.set_player_var(player, "ex_score", exScore)
	# Rate of the EX score over its maximum (2 per note), gives the grade
	Global.set_player_var(player, "score", exScore * 100.0 / maxi(noteCount * 2, 1))
	Global.set_player_var(player, "combo_max", comboMax)
	Global.set_player_var(player, "gauge_score", shownGauge())
	# Details of the play and the best score before it, for the result screen
	Global.set_player_var(player, "result", {
		"counts": judgeCounts.duplicate(), "fast": fastCount, "slow": slowCount, "combo_break": comboBreak,
		"miss_count": judgeCounts["Bad"] + judgeCounts["Poor"], "note_count": noteCount,
		"gauge_history": gaugeHistory, "previous_best": Scores.get_best(Loader.file_path, Loader.chart_difficulty, double).duplicate(),
	})
	Global.song_info = songInfo.merged({"difficulty": Loader.chart_difficulty, "double": double})
	if netplay:
		if not AUTOPLAY:
			Scores.save_play(player, Loader.file_path, Loader.chart_difficulty)
		Netplay.send_result({
			"ex": exScore, "max_ex": noteCount * 2, "rate": opt("score"), "lamp": Scores.lamp(player),
			"failed": failed, "gauge": int(shownGauge()), "combo_max": comboMax, "counts": judgeCounts,
			"auto_play": AUTOPLAY,
		})
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file("res://scenes/netplay/result.tscn")
	elif versus:
		judgeShown = ""
		overlay.queue_redraw()
		if failed:
			$getready.text = "Failed"
			$getready.add_theme_color_override("font_color", Color(1, 0.1, 0))
			$getready.show()
		finished.emit()
	else:
		# Only the solo plays are saved, not the autoplay
		if not AUTOPLAY:
			Scores.save_play(player, Loader.file_path, Loader.chart_difficulty, double)
		if Arcade.active:
			Arcade.add_stage(player)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file("res://scenes/result/result.tscn")

# X position of the centre of a lane in the playfield
func laneX(i : int) -> float:
	return laneLeft[i] + laneWidth[i] / 2.0

# Lanes, keys, gauge and HUD, placed for this side of the screen (2P side mirrored)
func buildLayout() -> void:
	for i in range(8):
		if i == 7:
			laneLeft[i] = 7 * KEY_WIDTH + SCRATCH_GAP if mirrored else 0.0
			laneWidth[i] = SCRATCH_WIDTH
		else:
			laneLeft[i] = i * KEY_WIDTH if mirrored else SCRATCH_WIDTH + SCRATCH_GAP + i * KEY_WIDTH
			laneWidth[i] = KEY_WIDTH
	for i in range(8):
		var container := Node2D.new()
		container.name = "container%d" % (i + 1)
		add_child(container)
	var sublines := Node2D.new()
	sublines.name = "sublinecontainer"
	add_child(sublines)
	# Keys, gauge and HUD come after the notes so that the notes pass under them
	overlay = Overlay.new()
	overlay.name = "overlay"
	overlay.field = self
	add_child(overlay)
	# Keys and turntable, touch buttons follow this player's actions
	for i in range(8):
		var shape := RectangleShape2D.new()
		shape.size = Vector2(laneWidth[i], KEYS_HEIGHT)
		var button := TouchScreenButton.new()
		button.shape = shape
		button.position = Vector2(laneX(i), KEYS_TOP + KEYS_HEIGHT / 2.0)
		button.action = prefix + ("digital_turntable_rew" if i == 7 else "key%d" % (i + 1))
		add_child(button)
	# Key and scratch frames from the game art, and the turntable disc on the scratch lane
	keyFrame = load("res://assets/play/p1_frame.png")
	scratchFrame = load("res://assets/play/p1_frame_scratch.png")
	keyFrameOrigin = Vector2(laneX(0) - FRAME_FIRST_KEY_X * KEY_SCALE, KEYS_TOP)
	disc = Sprite2D.new()
	disc.name = "Disc"
	disc.texture = load("res://assets/play/p1_turntable_disc.png")
	disc.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# The disc goes over the hole of the frame, which is drawn at the same scale as the lane
	var frameScale := Vector2(SCRATCH_WIDTH, SCRATCH_HEIGHT) / SCRATCH_ART_SIZE
	disc.scale = Vector2.ONE * frameScale.x
	disc.position = Vector2(laneLeft[7], KEYS_TOP) + SCRATCH_HOLE_CENTER * frameScale
	add_child(disc)
	# Groove gauge from the game art, HARD has its own red textures
	var gauge_art : String = "_hard" if opt("gauge_level") == Judge.HARD else ""
	gaugeBar = TextureProgressBar.new()
	gaugeBar.name = "GrooveGauge"
	gaugeBar.max_value = 100.0
	gaugeBar.texture_under = load("res://assets/play/groove_gauge%s.png" % gauge_art)
	gaugeBar.texture_progress = load("res://assets/play/progress%s.png" % gauge_art)
	# Without nine patch the texture is the minimum size of the bar, the bar is then stretched to the gauge width
	gaugeBar.nine_patch_stretch = true
	gaugeBar.position = sideRect(GAUGE_RECT).position
	gaugeBar.size = GAUGE_RECT.size
	gaugeBar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The screen of the gauge stays empty on the side of a player who is not playing
	gaugeBar.visible = active
	add_child(gaugeBar)
	gaugeFlicker = TextureRect.new()
	gaugeFlicker.texture = AtlasTexture.new()
	gaugeFlicker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gaugeFlicker.stretch_mode = TextureRect.STRETCH_SCALE
	gaugeFlicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gaugeFlicker.visible = false
	gaugeBar.add_child(gaugeFlicker)
	gaugeBar.move_child(gaugeFlicker, 0)
	# Messages over the key lanes
	var keys := Rect2(keysCenter() - 3.5 * KEY_WIDTH, 0, 7 * KEY_WIDTH, 0)
	var get_ready := makeLabel(self, "getready", "Get Ready !", 24, Color.WHITE, Rect2(keys.position.x, 240, keys.size.x, 37), HORIZONTAL_ALIGNMENT_CENTER)
	get_ready.visible = active
	var autoplay_label := makeLabel(self, "isautoplay", "AUTO PLAY", 16, LABEL_COLOR, Rect2(keys.position.x, 16, keys.size.x, 24), HORIZONTAL_ALIGNMENT_CENTER)
	autoplay_label.visible = false

# Centre of the 7 key lanes, the judgement is shown there
func keysCenter() -> float:
	return (laneLeft[0] + laneLeft[6] + KEY_WIDTH) / 2.0

# A rectangle of the 1P layout, mirrored on the 2P side
func sideRect(rect : Rect2) -> Rect2:
	if mirrored:
		rect.position.x = PLAYFIELD_WIDTH - rect.end.x
	return rect

# An x coordinate of the 1P layout, mirrored on the 2P side
func sideX(x : float) -> float:
	return PLAYFIELD_WIDTH - x if mirrored else x

# A label in the pixel font of the game, placed in the coordinates of its parent
func makeLabel(parent : Node, node_name : String, text : String, font_size : int, color : Color, rect : Rect2, align : HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.pivot_offset = rect.size / 2.0
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _draw() -> void:
	drawLanes()

# Black lanes with grey separators, beams over the held keys, and the metal rails on both sides
func drawLanes() -> void:
	draw_rect(Rect2(0, 0, PLAYFIELD_WIDTH, PERFECT_YPOS), LANE_COLOR)
	# Gap between the turntable lane and the keys
	var gapLeft : float = 7 * KEY_WIDTH if mirrored else SCRATCH_WIDTH
	draw_rect(Rect2(gapLeft, 0, SCRATCH_GAP, PERFECT_YPOS), LANE_GAP_COLOR)
	for i in range(8):
		var left : float = laneLeft[i]
		var right : float = left + laneWidth[i]
		if i < 7 and i % 2 == 1:
			draw_rect(Rect2(left, 0, laneWidth[i], PERFECT_YPOS), LANE_BLACK_KEY_COLOR)
		if pressed[i] and not disabled[i]:
			var top : float = PERFECT_YPOS - LANE_LIGHT_HEIGHT
			draw_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, PERFECT_YPOS), Vector2(left, PERFECT_YPOS)]),
				PackedColorArray([Color(BEAM_COLOR, 0.0), Color(BEAM_COLOR, 0.0), Color(BEAM_COLOR, 0.65), Color(BEAM_COLOR, 0.65)]))
		if disabled[i]:
			draw_rect(Rect2(left, 0, laneWidth[i], PERFECT_YPOS), Color(0.12, 0.12, 0.14))
		draw_line(Vector2(left, 0), Vector2(left, PERFECT_YPOS), SEPARATOR_COLOR, 1.0)
		draw_line(Vector2(right, 0), Vector2(right, PERFECT_YPOS), SEPARATOR_COLOR, 1.0)
	drawRail(-RAIL_WIDTH, not mirrored)
	drawRail(PLAYFIELD_WIDTH, mirrored)

# A rounded metal rail beside the lanes, the outer one has a slot where the song progress goes down
func drawRail(left : float, outer : bool) -> void:
	var mid : float = left + RAIL_WIDTH / 2.0
	var right : float = left + RAIL_WIDTH
	draw_polygon(PackedVector2Array([Vector2(left, 0), Vector2(mid, 0), Vector2(mid, PLATE_TOP), Vector2(left, PLATE_TOP)]),
		PackedColorArray([METAL_DARK, METAL_LIGHT, METAL_LIGHT, METAL_DARK]))
	draw_polygon(PackedVector2Array([Vector2(mid, 0), Vector2(right, 0), Vector2(right, PLATE_TOP), Vector2(mid, PLATE_TOP)]),
		PackedColorArray([METAL_LIGHT, METAL_DARK, METAL_DARK, METAL_LIGHT]))
	draw_line(Vector2(left, 0), Vector2(left, PLATE_TOP), METAL_EDGE, 1.0)
	draw_line(Vector2(right, 0), Vector2(right, PLATE_TOP), METAL_EDGE, 1.0)
	if not outer:
		return
	var slot := Rect2(mid - 2, 6, 4, PLATE_TOP - 18)
	draw_rect(slot, SCREEN_COLOR)
	if not active or endPos <= 0.0:
		return
	var marker : float = slot.position.y + (slot.size.y - 14) * clampf(currentSongPos / endPos, 0.0, 1.0)
	draw_rect(Rect2(mid - 4, marker - 2, 8, 18), Color(PROGRESS_COLOR, 0.3))
	draw_rect(Rect2(mid - 3, marker, 6, 14), PROGRESS_COLOR)

# Metal plate under the lanes with the screens of the HUD
func drawPlate(canvas : CanvasItem) -> void:
	var points := PackedVector2Array()
	for p in [Vector2(-RAIL_WIDTH, PLATE_TOP), Vector2(392, PLATE_TOP), Vector2(404, 512), Vector2(PLATE_RIGHT, 512),
			Vector2(PLATE_RIGHT, 708), Vector2(476, 720), Vector2(-RAIL_WIDTH, 720)]:
		points.append(Vector2(sideX(p.x), p.y))
	drawMetal(canvas, points)
	for rect in [PERCENT_SCREEN, GAUGE_SCREEN, SCORE_SCREEN, DIFFICULTY_SCREEN]:
		drawScreen(canvas, sideRect(rect))
	for screw in [Vector2(PLATE_RIGHT - 7, 519), Vector2(PLATE_RIGHT - 7, 627), Vector2(284, 627), Vector2(-6, 627)]:
		drawScrew(canvas, Vector2(sideX(screw.x), screw.y))
	# Blue lights under the bottom screens
	for rect in [SCORE_SCREEN, DIFFICULTY_SCREEN]:
		var screen : Rect2 = sideRect(rect)
		canvas.draw_rect(Rect2(screen.get_center().x - 18, screen.end.y + 4, 36, 3), Color(SCREEN_GLOW, 0.9))

# Gauge title, gauge percentage, score, max combo and difficulty, in the screens of the plate
func drawHud(canvas : CanvasItem) -> void:
	var outer : HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	var gauge_screen : Rect2 = sideRect(GAUGE_SCREEN)
	var gauge_title : String = "DP GROOVE GAUGE" if partner else "P%d GROOVE GAUGE" % player
	canvas.draw_string(FONT, Vector2(gauge_screen.position.x + 4, GAUGE_LABEL_Y), gauge_title, outer, gauge_screen.size.x - 8, 10, GAUGE_LABEL_COLOR)
	var percent : Rect2 = sideRect(PERCENT_SCREEN)
	drawNumber(canvas, Vector2(percent.end.x - 22, percent.position.y + 32), int(shownGauge()), 3, 19)
	canvas.draw_string(FONT, Vector2(percent.end.x - 19, percent.position.y + 32), "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, NUMBER_COLOR)
	# Score and max combo: the titles on the outer side, the numbers towards the middle of the screen
	var score : Rect2 = sideRect(SCORE_SCREEN)
	var rows : Array = [["SCORE", scorer.exScore, 5], ["MAXCOMBO", scorer.comboMax, 4]]
	for row in range(2):
		var baseline : float = score.position.y + 33 + row * 37
		canvas.draw_string(FONT, Vector2(score.position.x + 10, baseline - 6), rows[row][0], outer, score.size.x - 20, 11, LABEL_COLOR)
		var right : float = score.position.x + 10 + numberWidth(5, 24) if mirrored else score.end.x - 10
		drawNumber(canvas, Vector2(right, baseline), rows[row][1], rows[row][2], 24)
	# Difficulty in its color, with the level of the chart under it
	var difficulty : Rect2 = sideRect(DIFFICULTY_SCREEN)
	var difficulty_name : String = Loader.chart_difficulty.to_upper()
	var size : int = 20
	while size > 10 and FONT.get_string_size(difficulty_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > difficulty.size.x - 16:
		size -= 1
	canvas.draw_string(FONT, Vector2(difficulty.position.x, difficulty.position.y + 36), difficulty_name, HORIZONTAL_ALIGNMENT_CENTER, difficulty.size.x, size,
		NetplayUI.difficulty_color(Loader.chart_difficulty))
	var middle : float = difficulty.get_center().x
	canvas.draw_string(FONT, Vector2(middle - 64, difficulty.position.y + 64), "LEVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, LABEL_COLOR)
	drawNumber(canvas, Vector2(middle + 54, difficulty.position.y + 66), songInfo.get("level", 0), 2, 20)

# Burst of light on the judge line where a note was hit
func drawBursts(canvas : CanvasItem) -> void:
	for i in range(8):
		var f : float = hitFlash[i]
		if f <= 0.0:
			continue
		var center := Vector2(laneX(i), PERFECT_YPOS)
		var radius : float = laneWidth[i] * (0.35 + 0.5 * (1.0 - f))
		canvas.draw_circle(center, radius * 1.5, Color(BURST_COLOR, 0.15 * f))
		canvas.draw_circle(center, radius, Color(BURST_COLOR, 0.35 * f))
		canvas.draw_circle(center, radius * 0.45, Color(1, 1, 1, 0.75 * f))
		canvas.draw_rect(Rect2(center.x - radius * 1.8, center.y - 1.5, radius * 3.6, 3), Color(1, 1, 1, 0.6 * f))

# Last judgement and the combo on one line over the key lanes, like "GREAT 113" in IIDX, the timing under it
func drawJudge(canvas : CanvasItem) -> void:
	var elapsed : float = (Time.get_ticks_msec() - judgeMs) / 1000.0
	if judgeShown == "" or elapsed > JUDGE_TIME:
		return
	var text : String = JUDGE_WORDS[judgeShown]
	if scorer.combo > 0 and judgeShown != "Bad" and judgeShown != "Poor":
		text += " %d" % scorer.combo
	var color : Color
	if judgeShown == "PGreat":
		color = PGREAT_COLORS[(Time.get_ticks_msec() / PGREAT_CYCLE_MS) % PGREAT_COLORS.size()]
	else:
		color = JUDGE_COLORS[judgeShown]
	var width : float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, JUDGE_SIZE).x
	# Narrowed to fit the key lanes, and bigger for a moment when it appears
	var zoom : float = minf(1.0, (7 * KEY_WIDTH - 8) / width) * (1.0 + 0.25 * maxf(0.0, 1.0 - elapsed / JUDGE_POP_TIME))
	var origin := Vector2(-width / 2.0, JUDGE_SIZE / 2.0)
	canvas.draw_set_transform(Vector2(keysCenter(), JUDGE_Y), 0.0, Vector2(zoom, zoom))
	canvas.draw_string_outline(FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, JUDGE_SIZE, 8, Color.BLACK)
	canvas.draw_string(FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, JUDGE_SIZE, color)
	canvas.draw_set_transform(Vector2.ZERO)
	if timingText != "":
		var timing := Vector2(keysCenter() - 100, JUDGE_Y + JUDGE_SIZE / 2.0 + 22)
		canvas.draw_string_outline(FONT, timing, timingText, HORIZONTAL_ALIGNMENT_CENTER, 200, 14, 4, Color.BLACK)
		canvas.draw_string(FONT, timing, timingText, HORIZONTAL_ALIGNMENT_CENTER, 200, 14, timingColor)

# Key frame and scratch frame of the game art, the held keys are drawn again in red over it
func drawKeys(canvas : CanvasItem) -> void:
	var frameSize : Vector2 = keyFrame.get_size()
	canvas.draw_texture_rect(keyFrame, Rect2(keyFrameOrigin, Vector2(frameSize.x * KEY_SCALE, frameSize.y * KEY_SCALE_Y)), false)
	for i in range(7):
		if not pressed[i]:
			continue
		var white : bool = i % 2 == 0
		var region : Rect2 = KEY_WHITE_RECT if white else KEY_BLACK_RECT
		region.position.x += KEY_SPACING * floorf(i / 2.0)
		var dest := Rect2(keyFrameOrigin + Vector2(region.position.x * KEY_SCALE, region.position.y * KEY_SCALE_Y), Vector2(region.size.x * KEY_SCALE, region.size.y * KEY_SCALE_Y))
		canvas.draw_texture_rect_region(keyFrame, dest, region, KEY_LIGHT_WHITE if white else KEY_LIGHT_BLACK)
	canvas.draw_texture_rect(scratchFrame, Rect2(laneLeft[7], KEYS_TOP, SCRATCH_WIDTH, SCRATCH_HEIGHT), false, KEY_LIGHT_WHITE if pressed[7] else Color.WHITE)

# The last filled segment stays lit, the GAUGE_FLICKER_SEGMENTS before it light up from the left like a spectrum analyzer
func flickerGauge() -> void:
	var bar : TextureProgressBar = gaugeBar
	var texture : Texture2D = bar.texture_under
	var width : float = texture.get_width()
	var last : int = int(bar.value / 2.0) - 1
	var lit : int = randi_range(0, GAUGE_FLICKER_SEGMENTS)
	# Unlit segments from the empty gauge texture, never the first one which is lit in it
	var from : float = maxf((last - GAUGE_FLICKER_SEGMENTS + lit) * GAUGE_SEGMENT_PX + GAUGE_GAP_PX, GAUGE_SEGMENT_PX + GAUGE_GAP_PX)
	var to : float = last * GAUGE_SEGMENT_PX + GAUGE_GAP_PX
	gaugeFlicker.visible = to > from
	if not gaugeFlicker.visible:
		return
	var atlas : AtlasTexture = gaugeFlicker.texture
	atlas.atlas = texture
	atlas.region = Rect2(from, 0, to - from, texture.get_height())
	# The bar is stretched to the width of the gauge
	var ratio : float = bar.size.x / width
	gaugeFlicker.position = Vector2(from * ratio, 0)
	gaugeFlicker.size = Vector2((to - from) * ratio, bar.size.y)

# A metal panel of the frame, lit from the top
static func drawMetal(canvas : CanvasItem, points : PackedVector2Array) -> void:
	var top : float = INF
	var bottom : float = -INF
	for p in points:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	var colors := PackedColorArray()
	for p in points:
		colors.append(METAL_LIGHT.lerp(METAL_DARK, (p.y - top) / maxf(bottom - top, 1.0)))
	canvas.draw_polygon(points, colors)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, METAL_EDGE, 2.0)

# A dark screen sunk in the metal: shadow on its border, a thin blue glow inside, a light lip under it
static func drawScreen(canvas : CanvasItem, rect : Rect2) -> void:
	var points := chamfered(rect, 6)
	canvas.draw_colored_polygon(points, SCREEN_COLOR)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, METAL_EDGE, 2.0)
	var glow := chamfered(rect.grow(-3), 4)
	glow.append(glow[0])
	canvas.draw_polyline(glow, SCREEN_GLOW, 1.0)
	canvas.draw_line(Vector2(rect.position.x + 6, rect.end.y + 1.5), Vector2(rect.end.x - 6, rect.end.y + 1.5), Color(1, 1, 1, 0.5), 1.0)

# Corners of a rectangle with its corners cut
static func chamfered(rect : Rect2, cut : float) -> PackedVector2Array:
	var a : Vector2 = rect.position
	var b : Vector2 = rect.end
	return PackedVector2Array([Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut), Vector2(b.x, b.y - cut),
		Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y), Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut)])

# A screw of the metal frame
static func drawScrew(canvas : CanvasItem, at : Vector2) -> void:
	canvas.draw_circle(at, 3.5, METAL_EDGE)
	canvas.draw_circle(at, 2.5, METAL_LIGHT)
	canvas.draw_line(at - Vector2(2, -2), at + Vector2(2, -2), METAL_DARK, 1.0)

# Width of a number of digits drawn by drawNumber()
static func numberWidth(digits : int, size : int) -> float:
	return digits * NUMBER_FONT.get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

# Digits of a 7-segment display, right-aligned on right: the unlit segments behind, the leading zeros dimmed
static func drawNumber(canvas : CanvasItem, right : Vector2, value : int, digits : int, size : int) -> void:
	var text : String = ("%0" + str(digits) + "d") % value
	var cell : float = numberWidth(1, size)
	var leading : bool = true
	for k in text.length():
		var x : float = right.x - (text.length() - k) * cell
		canvas.draw_string(NUMBER_FONT, Vector2(x, right.y), "8", HORIZONTAL_ALIGNMENT_LEFT, -1, size, NUMBER_GHOST)
		leading = leading and text[k] == "0" and k < text.length() - 1
		var width : float = NUMBER_FONT.get_string_size(text[k], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		canvas.draw_string(NUMBER_FONT, Vector2(x + cell - width, right.y), text[k], HORIZONTAL_ALIGNMENT_LEFT, -1, size, NUMBER_DIM if leading else NUMBER_COLOR)

# Drawn over the notes: the plate, the keys, the HUD and the judgement
class Overlay extends Node2D:
	var field : Playfield

	func _draw() -> void:
		field.drawPlate(self)
		field.drawKeys(self)
		if field.active:
			field.drawHud(self)
		field.drawBursts(self)
		field.drawJudge(self)
