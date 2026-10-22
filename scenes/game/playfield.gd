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
# Keys row under the judge line
const KEYS_TOP : float = 504.0
# The art is drawn at these scales: 100 px per key in the key frame becomes one lane, the turntable is bigger than the keys
const KEY_SCALE : float = 0.4
const SCRATCH_SCALE : float = 0.6
# The keys are as high as the turntable frame, the key art is stretched vertically to fit (130 px tall)
const KEYS_HEIGHT : float = SCRATCH_HEIGHT
const KEY_SCALE_Y : float = KEYS_HEIGHT / 130.0
const KEYS_BOTTOM : float = KEYS_TOP + KEYS_HEIGHT
# Groove gauge under the keys: 50 segments of 2 %, with the percentage box beside it
const GAUGE_TOP : float = 588.0
const GAUGE_HEIGHT : float = 24.0
const GAUGE_PERCENT_WIDTH : float = 84.0
const GAUGE_WIDTH : float = PLAYFIELD_WIDTH - GAUGE_PERCENT_WIDTH - 6.0
# Gauge texture geometry: one segment every 21 px (2 %), the gaps between them are around x = 21 n + 6
const GAUGE_SEGMENT_PX : float = 21.0
const GAUGE_GAP_PX : float = 6.0
# HUD under the gauge: score, then max combo
const HUD_TOP : float = 614.0
const HUD_ROW_HEIGHT : float = 48.0
const HUD_ROW_GAP : float = 4.0
# The playfield of a player who is not playing stays on screen, dimmed
const IDLE_ALPHA : float = 0.3
# The two gauge segments before the last filled one flicker like in IIDX: 0 to 2 lit, drawn again at this interval (ms)
const GAUGE_FLICKER_SEGMENTS : int = 2
const GAUGE_FLICKER_MS : int = 50
# Height of the light rising from a lane when its key is held or a note is hit (px), and how fast a hit flash fades (per second)
const LANE_LIGHT_HEIGHT : float = 180.0
const HIT_FLASH_DECAY : float = 4.0
# After the last note is finished, wait for this margin and then the game ends.
const ENDPOS_BIAS : float = +2.0
# Auxiliary line spacing when the chart has no measures (sec)
const SUBLINE_LENGTH : float = 1.0
const FONT : Font = preload("res://assets/font/04B_20__.TTF")
const LANE_TOP_COLOR : Color = Color(0.02, 0.03, 0.08)
const LANE_BOTTOM_COLOR : Color = Color(0.07, 0.11, 0.22)
const LANE_LIGHT_COLOR : Color = Color(0.35, 0.8, 1.0)
const LIGHT_PRESSED_COLOR : Color = Color(1.0, 0.3, 0.3)
const SEPARATOR_COLOR : Color = Color(0.45, 0.65, 1.0, 0.3)
const JUDGE_LINE_COLOR : Color = Color(0.75, 0.95, 1.0)
const FRAME_COLOR : Color = Color(0.55, 0.8, 1.0, 0.85)
const TITLE_COLOR : Color = Color(0.45, 0.75, 1.0)
const VALUE_COLOR : Color = Color(0.85, 1.0, 1.0)
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
# Player number, picks the game options and the input actions (p1_* or p2_*)
var player : int = 1
# This player plays on this playfield, otherwise it is only shown
var active : bool = false
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
# Boxes of the HUD and of the gauge percentage
var hudStyle       : StyleBoxFlat
var percentStyle   : StyleBoxFlat
# Nodes made by buildLayout()
var overlay        : Overlay
var disc           : Sprite2D
var hud            : Node2D
var scoreValue     : Label
var comboValue     : Label
var percentLabel   : Label

# Set the side of this playfield before start(): the player, whether it plays here, and the mode
func setup(p : int, plays : bool, both : bool, online : bool) -> void:
	player = p
	active = plays
	versus = both
	netplay = online
	prefix = "p%d_" % player
	mirrored = player == 2
	keycodes = PackedStringArray([prefix + "key1", prefix + "key2", prefix + "key3", prefix + "key4",
		prefix + "key5", prefix + "key6", prefix + "key7", prefix + "digital_turntable_fwd"])
	buildLayout()
	modulate = Color(1, 1, 1, 1.0 if active else IDLE_ALPHA)
	set_process(false)

# Load the chart and start the playfield, called by main.gd for each player who plays
func start() -> void:
	if not active:
		return
	AUTOPLAY = opt("auto_play")
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
	noteCount = Judge.noteCount(noteArray)
	Global.set_player_var(player, "combo_max_top", noteCount)

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

	gauge = Judge.gaugeStart(opt("gauge_level"))
	gaugeRecovery = Judge.gaugeRecovery(opt("gauge_level"), noteCount)
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
	var chart : ModChart = ModChart.new(keysoundPlayer.module, Loader.chart_difficulty, opt("keys_mode"))
	noteArray = chart.noteArray
	keysoundArray = chart.keysoundArray
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
	noteArray = keysoundPlayer.chart.noteArray.duplicate(true)
	keysoundArray = keysoundPlayer.chart.keysoundArray.duplicate(true)
	measures = keysoundPlayer.chart.measures.duplicate()
	bpms = bmsBpms(keysoundPlayer.chart)
	songInfo = {"title": keysoundPlayer.chart.title, "artist": keysoundPlayer.chart.artist, "level": keysoundPlayer.chart.level}
	return true

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
				note.setNote(i+1, speed, coordPerFrame, laneWidth[i])
			else:
				# Create long note
				note.setNote(i+1, speed, coordPerFrame, laneWidth[i], info[1])
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
		line.default_color = Color(1, 1, 1, 0.25)
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
			addJudge(queue[7][0].score)
			queue[7][0].free()
			queue[7].pop_front()
	elif (queue[7] and queue[7][0].isLongnote == true and queue[7][0].longnoteScore == ""):
		if (queue[7][0].hitTime <= currentSongPos):
			queue[7][0].score = "PGreat"
			startLongnote(7)

func autoplay():
	for i in range(0, 8):
		if (queue[i] and queue[i][0] == null):
			queue[i].pop_front()
		if (queue[i] and queue[i][0].isLongnote == false):
			if (queue[i][0].hitTime <= currentSongPos):
				queue[i][0].score = "PGreat"
				addJudge(queue[i][0].score)
				queue[i][0].free()
				queue[i].pop_front()
		elif (queue[i] and queue[i][0].isLongnote == true and queue[i][0].longnoteScore == ""):
			if (queue[i][0].hitTime <= currentSongPos):
				queue[i][0].score = "PGreat"
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

# Count a judgement: EX score, gauge, then combo (GOOD keeps it, BAD and POOR break it like in IIDX)
# offset is how late the hit was in seconds (negative when early), 0 when there was no hit
func addJudge(judgement : String, offset : float = 0.0) -> void:
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
		resetCombo(judgement)
	else:
		addCombo(judgement)
	refreshHud()

# Add a combo.
func addCombo(score : String) -> void:
	combo += 1
	if combo > comboMax:
		comboMax = combo
	$combo.text = str(combo)
	$anim.play(score)
	await $anim.animation_finished
	$anim.play("combo")
	await $anim.animation_finished

# Resets the combo.
func resetCombo(judgement : String) -> void:
	combo = 0
	$combo.text = str(combo)
	$anim.play(judgement)
	await $anim.animation_finished
	$anim.play("combo")
	await $anim.animation_finished

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
	return float(Judge.gaugeDisplay(opt("gauge_level"), gauge))

# Score, max combo and gauge shown beside the playfield
func refreshHud() -> void:
	if not active:
		return
	scoreValue.text = "%06d" % exScore
	comboValue.text = "%04d" % comboMax
	gaugeBar.value = shownGauge()
	percentLabel.text = "%d%%" % int(shownGauge())

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
		judgeCounts["Poor"] += 1
		updateGauge("EmptyPoor")
		$anim.play("Poor")

# Show how early (-) or late (+) a note was hit, measured like the judgement from its y position
func showTiming(n : Note) -> void:
	if not Global.show_timing:
		return
	var ms : int = roundi((currentSongPos - n.hitTime) * 1000.0)
	$score/timing.text = "%+dms" % ms
	# Fast in blue, slow in red like in IIDX
	$score/timing.add_theme_color_override("font_color", Color(0.3, 0.6, 1) if ms < 0 else Color(1, 0.3, 0.3))
	$score/timing.show()

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
					$score/timing.hide()
					queue[i][0].longnoteFailed()
					queue[i].pop_front()
					addJudge("Poor")
					addJudge("Poor")
			# If it's a general note
			else:
				$score/timing.hide()
				queue[i].pop_front()
				addJudge("Poor")

func killGarbage() -> void:
	for i in range(1, 9):
		for n in get_node("container" + str(i)).get_children():
			# The late notes stay until they are judged
			if (n.position.y - n.effect.size.y >= 600 and not queue[i-1].has(n)):
				n.free()

# Store this player's results, then show them (or wait for the other player in versus)
func finish(failed : bool) -> void:
	if done:
		return
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
		"gauge_history": gaugeHistory, "previous_best": Scores.get_best(Loader.file_path, Loader.chart_difficulty).duplicate(),
	})
	Global.song_info = songInfo.merged({"difficulty": Loader.chart_difficulty})
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
		$score.hide()
		if failed:
			$getready.text = "Failed"
			$getready.add_theme_color_override("font_color", Color(1, 0.1, 0))
			$getready.show()
		finished.emit()
	else:
		# Only the solo plays are saved, not the autoplay
		if not AUTOPLAY:
			Scores.save_play(player, Loader.file_path, Loader.chart_difficulty)
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
	gaugeBar.position = Vector2(GAUGE_PERCENT_WIDTH + 6.0 if mirrored else 0.0, GAUGE_TOP)
	gaugeBar.size = Vector2(GAUGE_WIDTH, GAUGE_HEIGHT)
	gaugeBar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gaugeBar)
	gaugeFlicker = TextureRect.new()
	gaugeFlicker.texture = AtlasTexture.new()
	gaugeFlicker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gaugeFlicker.stretch_mode = TextureRect.STRETCH_SCALE
	gaugeFlicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gaugeFlicker.visible = false
	gaugeBar.add_child(gaugeFlicker)
	gaugeBar.move_child(gaugeFlicker, 0)
	# Boxes
	hudStyle = makeBox(Color(0.03, 0.05, 0.1, 0.85), Color(0.3, 0.6, 1.0, 0.7), 2, 12)
	percentStyle = makeBox(Color(0.03, 0.05, 0.1, 0.85), Color(0.3, 0.6, 1.0, 0.7), 2, 8)
	# Score and max combo, the 2P side reads from the right edge
	hud = Node2D.new()
	hud.name = "hud"
	hud.visible = active
	add_child(hud)
	var title_align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	var value_align := HORIZONTAL_ALIGNMENT_LEFT if mirrored else HORIZONTAL_ALIGNMENT_RIGHT
	# Title and value share the box of their row: both are centred on its height, with the same margin inside the frame
	var value_width := PLAYFIELD_WIDTH - 24.0
	var combo_row := HUD_TOP + HUD_ROW_HEIGHT + HUD_ROW_GAP
	makeLabel(hud, "scoreTitle", "SCORE", 12, TITLE_COLOR, Rect2(12, HUD_TOP, value_width, HUD_ROW_HEIGHT), title_align)
	scoreValue = makeLabel(hud, "scoreValue", "000000", 26, VALUE_COLOR, Rect2(12, HUD_TOP, value_width, HUD_ROW_HEIGHT), value_align)
	makeLabel(hud, "comboTitle", "MAXCOMBO", 12, TITLE_COLOR, Rect2(12, combo_row, value_width, HUD_ROW_HEIGHT), title_align)
	comboValue = makeLabel(hud, "comboValue", "0000", 26, VALUE_COLOR, Rect2(12, combo_row, value_width, HUD_ROW_HEIGHT), value_align)
	# Gauge percentage in its box beside the gauge
	percentLabel = makeLabel(self, "percent", "0%", 16, VALUE_COLOR, percentRect(), HORIZONTAL_ALIGNMENT_CENTER)
	percentLabel.visible = active
	# Judgement, timing and combo over the lanes
	var judgement := makeLabel(self, "score", "", 27, Color(0.88, 0, 0.27), Rect2(0, 350, PLAYFIELD_WIDTH, 37), HORIZONTAL_ALIGNMENT_CENTER)
	var timing := makeLabel(judgement, "timing", "", 16, Color.WHITE, Rect2(-20, 36, PLAYFIELD_WIDTH + 40, 20), HORIZONTAL_ALIGNMENT_CENTER)
	timing.visible = false
	makeLabel(self, "combo", "0", 32, Color.WHITE, Rect2(0, 420, PLAYFIELD_WIDTH, 40), HORIZONTAL_ALIGNMENT_CENTER)
	var get_ready := makeLabel(self, "getready", "Get Ready !", 27, Color(0.15, 0.5, 1), Rect2(0, 240, PLAYFIELD_WIDTH, 37), HORIZONTAL_ALIGNMENT_CENTER)
	get_ready.visible = active
	var autoplay_label := makeLabel(self, "isautoplay", "AUTO PLAY", 24, Color.WHITE, Rect2(0, 190, PLAYFIELD_WIDTH, 32), HORIZONTAL_ALIGNMENT_CENTER)
	autoplay_label.visible = false

# Position of the percentage box, beside the gauge on the side of the player
func percentRect() -> Rect2:
	var left : float = 0.0 if mirrored else PLAYFIELD_WIDTH - GAUGE_PERCENT_WIDTH
	return Rect2(left, GAUGE_TOP - 2, GAUGE_PERCENT_WIDTH, GAUGE_HEIGHT + 4)

# A rounded box for the panels of the playfield
func makeBox(color : Color, border : Color, border_width : int, radius : int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box

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

# Dark lanes, columns of light over the held keys, separators and the judge line
func drawLanes() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(PLAYFIELD_WIDTH, 0), Vector2(PLAYFIELD_WIDTH, PERFECT_YPOS), Vector2(0, PERFECT_YPOS)]),
		PackedColorArray([LANE_TOP_COLOR, LANE_TOP_COLOR, LANE_BOTTOM_COLOR, LANE_BOTTOM_COLOR]))
	for i in range(8):
		var light : float = hitFlash[i] * 0.5 + (0.45 if pressed[i] else 0.0)
		if light > 0.0 and not disabled[i]:
			var left : float = laneLeft[i]
			var right : float = left + laneWidth[i]
			var top : float = PERFECT_YPOS - LANE_LIGHT_HEIGHT
			var color : Color = LIGHT_PRESSED_COLOR if pressed[i] else LANE_LIGHT_COLOR
			draw_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, PERFECT_YPOS), Vector2(left, PERFECT_YPOS)]),
				PackedColorArray([Color(color, 0.0), Color(color, 0.0), Color(color, light), Color(color, light)]))
		if disabled[i]:
			draw_rect(Rect2(laneLeft[i], 0, laneWidth[i], KEYS_BOTTOM), Color(0, 0, 0, 0.6))
		draw_line(Vector2(laneLeft[i], 0), Vector2(laneLeft[i], KEYS_BOTTOM), SEPARATOR_COLOR, 1.0)
		draw_line(Vector2(laneLeft[i] + laneWidth[i], 0), Vector2(laneLeft[i] + laneWidth[i], KEYS_BOTTOM), SEPARATOR_COLOR, 1.0)
	var flash : float = 0.0
	for value in hitFlash:
		flash = maxf(flash, value)
	draw_rect(Rect2(0, PERFECT_YPOS - 4, PLAYFIELD_WIDTH, 8), Color(JUDGE_LINE_COLOR, 0.15 + 0.3 * flash))
	draw_line(Vector2(0, PERFECT_YPOS), Vector2(PLAYFIELD_WIDTH, PERFECT_YPOS), JUDGE_LINE_COLOR, 2.0)
	draw_rect(Rect2(-1, -1, PLAYFIELD_WIDTH + 2, KEYS_BOTTOM + 2), FRAME_COLOR, false, 2.0)

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

# Percentage box and panels behind the score and the max combo
func drawHud(canvas : CanvasItem) -> void:
	canvas.draw_style_box(percentStyle, percentRect())
	for row in range(2):
		canvas.draw_style_box(hudStyle, Rect2(0, HUD_TOP + row * (HUD_ROW_HEIGHT + HUD_ROW_GAP), PLAYFIELD_WIDTH, HUD_ROW_HEIGHT))

# Drawn over the notes: the keys and the HUD
class Overlay extends Node2D:
	var field : Playfield

	func _draw() -> void:
		field.drawKeys(self)
		if field.active:
			field.drawHud(self)
