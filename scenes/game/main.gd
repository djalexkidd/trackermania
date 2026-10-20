extends Node2D

# The following code is based from https://github.com/scenent/gd-rhythm

# The perfect y coordinate to press on the screen
const PERFECT_YPOS : float = 500
# 2P side: horizontal shift of the keys, the scratch lane goes to their right
const KEYS_SHIFT_2P : float = -142
# 2P side: axis used to mirror the scratch lane (P1 scratch lane 28~164 becomes 722~858)
const SCRATCH_AXIS_2P : float = 886
# Width of the playfield, the HUD is mirrored around it on the 2P side
const PLAYFIELD_WIDTH : float = 870
# After the last note is finished, wait for this margin and then the game ends.
const ENDPOS_BIAS : float = +2.0
# Auxiliary line spacing when the chart has no measures (sec)
const SUBLINE_LENGTH : float = 1.0
# The two gauge segments before the last filled one flicker like in IIDX: 0 to 2 lit, drawn again at this interval (ms)
const GAUGE_FLICKER_SEGMENTS : int = 2
const GAUGE_FLICKER_MS : int = 50
# Gauge texture geometry: one segment every 21 px (2 %), the gaps between them are around x = 21 n + 6
const GAUGE_SEGMENT_PX : float = 21.0
const GAUGE_GAP_PX : float = 6.0
# Emitted in local versus when this player is done (song ended, failed or gave up)
signal finished
# Player number, picks the game options and the input actions (p1_* or p2_*)
@export var player : int = 1
# Local versus flag (two playfields side by side, shared audio)
@export var versus : bool = false
# Online round (Netplay): same start for everyone, live ranking and the netplay results
var netplay : bool = false
# Autoplay flag
var AUTOPLAY : bool
var AUTOSCRATCH : bool
# Input action prefix of this player
var prefix : String
# 2P side layout like in IIDX (scratch lane on the right)
var mirrored : bool
# Key code for each of the 4 channels (can be added in the input map)
@export var keycodes : PackedStringArray
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
# Keysound player shared by the playfields: ModPlayer for an Amiga module, BmsPlayer for a BMS (same methods)
var keysoundPlayer
# Start time of each measure of the chart (seconds)
var measures       : Array = []
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
# Flickering segments drawn over the gauge, and when they were last drawn
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
# Key faces in p1_frame.png: white keys 1/3/5/7 and black keys 2/4/6, one key every 198 px per color
const KEY_WHITE_RECT : Rect2 = Rect2(42, 31, 68, 75)
const KEY_BLACK_RECT : Rect2 = Rect2(137, 21, 72, 71)
const KEY_SPACING    : float = 198
# Pressed keys light up in red like in IIDX (the black keys are darker, so their tint is brighter)
const KEY_LIGHT_WHITE : Color = Color(1.0, 0.25, 0.25)
const KEY_LIGHT_BLACK : Color = Color(2.6, 0.5, 0.5)
var keyLights : Array[TextureRect] = []
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
	showGauge()
	gaugeHistory.append(Vector2(clampf(currentSongPos / endPos, 0.0, 1.0), $GrooveGauge.value))
	if gauge <= 0.0:
		# Deferred because the note queues are still being iterated
		finish.call_deferred(true)
func showGauge() -> void:
	$GrooveGauge.value = Judge.gaugeDisplay(opt("gauge_level"), gauge)
	$GrooveGauge/Label.text = str(int($GrooveGauge.value)) + " %"
# The last filled segment stays lit, the GAUGE_FLICKER_SEGMENTS before it light up from the left like a spectrum analyzer
func flickerGauge() -> void:
	var bar : TextureProgressBar = $GrooveGauge
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
	# The bar may be stretched in versus
	var scale : float = bar.size.x / width
	gaugeFlicker.position = Vector2(from * scale, 0)
	gaugeFlicker.size = Vector2((to - from) * scale, bar.size.y)
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

# Get a game option of this player
func opt(option : String):
	return Global.get_player_var(player, option)

func load_mp3(path):
	var file = FileAccess.open(path, FileAccess.READ)
	var sound = AudioStreamMP3.new()
	sound.data = file.get_buffer(file.get_length())
	return sound

func _ready() -> void:
	AUTOPLAY = opt("auto_play")
	AUTOSCRATCH = opt("auto_scratch")
	speed = opt("hispeed")
	prefix = "p%d_" % player
	mirrored = player == 2
	netplay = not versus and Netplay.in_round()
	if netplay:
		# Same #RANDOM branches for everyone
		seed(Netplay.room["seed"])
		var scoreboard : Control = preload("res://scripts/netplay/scoreboard.gd").new()
		scoreboard.position = Vector2(PLAYFIELD_WIDTH + 24, 90)
		scoreboard.size = Vector2(1280 - PLAYFIELD_WIDTH - 40, 520)
		add_child(scoreboard)
	# Touch buttons follow this player's actions
	for button in $P1Frame.find_children("*", "TouchScreenButton"):
		button.action = button.action.replace("p1_", prefix)
	if versus:
		setupVersusLayout()
	if mirrored:
		setupMirroredLayout()
	
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
	showGauge()
	if opt("gauge_level") == Judge.HARD:
		$GrooveGauge.texture_progress = load("res://assets/play/progress_hard.png")
		$GrooveGauge.texture_under = load("res://assets/play/groove_gauge_hard.png")
	createKeyLights()
	gaugeFlicker = TextureRect.new()
	gaugeFlicker.texture = AtlasTexture.new()
	gaugeFlicker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gaugeFlicker.stretch_mode = TextureRect.STRETCH_SCALE
	gaugeFlicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gaugeFlicker.visible = false
	$GrooveGauge.add_child(gaugeFlicker)
	$GrooveGauge.move_child(gaugeFlicker, 0)
	
	set_process(false)
	if opt("keys_mode") == 5:
		$AutoPlay6.show()
		$AutoPlay7.show()
	for i in range(1, 9):
		get_node("pressed" + str(i)).visible = false
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
	gaugeHistory.append(Vector2(0.0, $GrooveGauge.value))
	if measures:
		subLineArray = getLineArr(measures, speed)
	else:
		subLineArray = getSubLineArr(endPos, speed, SUBLINE_LENGTH)
	if keysoundPlayer:
		# Auto played notes are played on time by the background music
		for i in range(0, 8):
			if not AUTOPLAY and not (AUTOSCRATCH and i == 7):
				keysoundPlayer.claim([keysoundArray[i]])
	if (AUTOPLAY):
		$isautoplay.visible = true
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

# Load the notes and the music of a Quaver beatmap
func loadQuaChart() -> bool:
	var chart : QuaChart = QuaChart.load_file(Loader.file_path)
	if chart == null:
		OS.alert("Invalid Quaver beatmap: " + Loader.file_path)
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu/music_select.tscn")
		return false
	noteArray = chart.noteArray
	measures = chart.measures
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
	return true

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
	songInfo = {"title": keysoundPlayer.chart.title, "artist": keysoundPlayer.chart.artist, "level": keysoundPlayer.chart.level}
	return true

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
	spinDisc(delta)
	# Get current audio playback time
	currentSongPos = songPosition()
	# The notes come later when the sound is late (output latency and user offset)
	currentSongPos -= AudioServer.get_output_latency() + Global.audio_offset / 1000.0
	# Confirm game end
	if (currentSongPos >= endPos):
		finish(false)
		return
	if netplay:
		Netplay.send_live(exScore, noteCount * 2, int($GrooveGauge.value), combo)
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
			note.scratchOnRight = mirrored
			if keysoundArray[i]:
				note.keysound = keysoundArray[i].pop_front()
				lastKeysound[i] = note.keysound
			var info : Array = noteArray[i].pop_front()
			note.hitTime = info[0] + speed
			note.perfectYpos = PERFECT_YPOS
			if (len(info) == 1):
				# Create a general note
				note.setNote(i+1, speed, coordPerFrame)
			else:
				# Create long note
				note.setNote(i+1, speed, coordPerFrame, info[1])
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
		line.points = [Vector2(-37, 0), Vector2(800, 0)]
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
	$P1Frame/TextureRect/Disc.rotation += TAU * turns * delta
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
	# Light the lanes, the scratch lane included, and the keys
	for i in range(0, 8):
		get_node("pressed" + str(i+1)).visible = pressed[i]
	for i in range(0, 7):
		keyLights[i].visible = pressed[i]
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
	for i in range(1, 9): get_node("pressed" + str(i)).visible = false
	for light in keyLights: light.visible = false
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
	Global.set_player_var(player, "gauge_score", $GrooveGauge.value)
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
			"failed": failed, "gauge": int($GrooveGauge.value), "combo_max": comboMax, "counts": judgeCounts,
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
# X position of the notes of a lane (0~6 keys, 7 scratch)
func laneX(i : int) -> float:
	if i == 7:
		return SCRATCH_AXIS_2P - 164 if mirrored else 64
	return 64 + 100 * (i+1) + (KEYS_SHIFT_2P if mirrored else 0)
# Fit the HUD inside the playfield width so two playfields can stand side by side
func setupVersusLayout() -> void:
	$GrooveGauge.nine_patch_stretch = true
	$GrooveGauge.size.x = PLAYFIELD_WIDTH - $GrooveGauge.position.x * 2
	# Gauge percentage goes under the gauge instead of beside it
	$GrooveGauge/Label.position = Vector2($GrooveGauge.size.x - $GrooveGauge/Label.size.x, $GrooveGauge.size.y + 8)
	$isautoplay.position.x = PLAYFIELD_WIDTH - $isautoplay.size.x
	$isautoplay.move_to_front()
	# The background must still hide long notes below the frame, down to the bottom of the screen
	$Background.size = Vector2(PLAYFIELD_WIDTH, 1000)
# Red copy of each key face of the frame, shown while the key is held
func createKeyLights() -> void:
	for i in range(0, 7):
		var white : bool = i % 2 == 0
		var region : Rect2 = KEY_WHITE_RECT if white else KEY_BLACK_RECT
		region.position.x += KEY_SPACING * floorf(i / 2.0)
		var atlas := AtlasTexture.new()
		atlas.atlas = $P1Frame.texture
		atlas.region = region
		var light := TextureRect.new()
		light.texture = atlas
		light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		light.position = region.position
		light.modulate = KEY_LIGHT_WHITE if white else KEY_LIGHT_BLACK
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		light.visible = false
		$P1Frame.add_child(light)
		keyLights.append(light)
# 2P side like in IIDX: keys on the left, scratch lane on the right, HUD mirrored
func setupMirroredLayout() -> void:
	# Keys
	for i in range(1, 9):
		get_node("ui/" + str(i)).position.x += KEYS_SHIFT_2P
	for i in range(1, 8):
		get_node("pressed" + str(i)).position.x += KEYS_SHIFT_2P
	for node in [$AutoPlay6, $AutoPlay7, $P1Frame, $getready, $score]:
		node.position.x += KEYS_SHIFT_2P
	# Scratch lane
	for line in [$"ui/10", $"ui/11"]:
		var x : float = $ui.position.x + line.position.x + line.points[0].x
		line.position.x += SCRATCH_AXIS_2P - 2 * x
	$pressed8.position.x = SCRATCH_AXIS_2P - $pressed8.position.x - $pressed8.size.x
	var turntable : TextureRect = $P1Frame/TextureRect
	turntable.flip_h = true
	turntable.position.x = PLAYFIELD_WIDTH - turntable.size.x - $P1Frame.position.x
	$P1Frame/TextureRect/Key8.position.x = turntable.size.x - $P1Frame/TextureRect/Key8.position.x
	$P1Frame/TextureRect/Disc.position.x = turntable.size.x - $P1Frame/TextureRect/Disc.position.x
	# Lines and judgement areas across the whole playfield (29~864 on 1P side, 22~857 on 2P side)
	for node in [$"ui/9", $"ui/400~440", $"ui/440~480", $"ui/480~520", $sublinecontainer]:
		node.position.x -= 7
	# HUD, the combo grows towards the left edge instead of going out of the screen
	$combo.size.x = 220
	$combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for node in [$combo, $isautoplay, $GrooveGauge, $Background]:
		node.position.x = PLAYFIELD_WIDTH - node.position.x - node.size.x
	$GrooveGauge/Label.position.x = $GrooveGauge.size.x - $GrooveGauge/Label.position.x - $GrooveGauge/Label.size.x
	$GrooveGauge/Label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# The combo bounce animation must keep the mirrored x position
	var library : AnimationLibrary = $anim.get_animation_library("").duplicate(true)
	var combo_anim : Animation = library.get_animation("combo")
	var track : int = combo_anim.find_track(NodePath("combo:position"), Animation.TYPE_VALUE)
	for k in combo_anim.track_get_key_count(track):
		var value : Vector2 = combo_anim.track_get_key_value(track, k)
		combo_anim.track_set_key_value(track, k, Vector2($combo.position.x, value.y))
	$anim.remove_animation_library("")
	$anim.add_animation_library("", library)
