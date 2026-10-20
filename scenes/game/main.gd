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
# Auxiliary line spacing (sec)
const SUBLINE_LENGTH : float = 1.0
# Emitted in local versus when this player is done (song ended, failed or gave up)
signal finished
# Player number, picks the game options and the input actions (p1_* or p2_*)
@export var player : int = 1
# Local versus flag (two playfields side by side, shared audio)
@export var versus : bool = false
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
# Keysound of each note of noteArray (Amiga modules only)
var keysoundArray  : Array   = [[], [], [], [], [], [], [], []]
# Keysound of the last note created in each lane
var lastKeysound   : Array   = [-1, -1, -1, -1, -1, -1, -1, -1]
# Module player shared by the playfields when the chart is an Amiga module
var modPlayer      : ModPlayer
# Auxiliary line information
var subLineArray   : Array = []
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
# Number of judgements of the chart, a long note counts twice (press and release) like a CN
var noteCount      : int     = 0
# Groove gauge in percent (Judge rules), and what a PGREAT or GREAT recovers
var gauge          : float   = 0.0
var gaugeRecovery  : float   = 0.0
# Analog
var previous_value := 0.0
# The scratch lane stays lit this long after the analog turntable moved
const SCRATCH_LIGHT_MS : int = 100
var lastScratchMove : int = -SCRATCH_LIGHT_MS
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
func addJudge(judgement : String) -> void:
	exScore += Judge.EX_POINTS.get(judgement, 0)
	updateGauge(judgement)
	if judgement == "Bad" or judgement == "Poor":
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
	if gauge <= 0.0:
		# Deferred because the note queues are still being iterated
		finish.call_deferred(true)
func showGauge() -> void:
	$GrooveGauge.value = Judge.gaugeDisplay(opt("gauge_level"), gauge)
	$GrooveGauge/Label.text = str(int($GrooveGauge.value)) + " %"
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
	else:
		loadJsonChart()
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
	if (modPlayer == null and get_node(audio).stream == null):
		OS.alert("Please assign a music")
	for i in range(0, 8):
		noteArray[i] = getCorrectArr(noteArray[i], speed)
	coordPerFrame = getCoordPerFrame(speed, PERFECT_YPOS)
	for i in range(0, 8):
		if getEndPos(noteArray[i], speed, ENDPOS_BIAS) > endPos:
			endPos = getEndPos(noteArray[i], speed, ENDPOS_BIAS)
	if modPlayer:
		# The background music goes on after the last note
		endPos = maxf(endPos, modPlayer.length + ENDPOS_BIAS)
	elif (get_node(audio).stream.get_length() < endPos):
		OS.alert("Please add enough space after the music, or decrease the ENDPOS_BIAS")
	if modPlayer:
		# The lines follow the measures of the module
		var measures : Array = modPlayer.module.measures.map(func(t): return t + ModChart.LEAD_IN)
		subLineArray = getLineArr(measures, speed)
	else:
		subLineArray = getSubLineArr(endPos, speed, SUBLINE_LENGTH)
	if modPlayer:
		# Auto played notes are played on time by the background music
		for i in range(0, 8):
			if not AUTOPLAY and not (AUTOSCRATCH and i == 7):
				modPlayer.claim([keysoundArray[i]])
	if (AUTOPLAY):
		$isautoplay.visible = true
	await get_tree().create_timer(1.0).timeout
	$getready.hide()
	if modPlayer:
		if not modPlayer.playing:
			modPlayer.play()
	elif not get_node(audio).playing:
		get_node(audio).play()
	set_process(true)

# Load the notes and the music of a TrackerMania chart
func loadJsonChart() -> void:
	var json_data = Loader.load_json_file(Loader.file_path)
	var directory_path = Loader.file_path.substr(0, Loader.file_path.rfind("/") + 1)
	var file_extension = json_data["AudioFile"].get_extension()
	noteArray = json_data["noteArray"]
	# In local versus both playfields share the same audio player, only load it once
	if get_node(audio).stream == null:
		if file_extension == "mp3":
			get_node(audio).stream = load_mp3(directory_path + json_data["AudioFile"])
		elif file_extension == "ogg":
			get_node(audio).stream = AudioStreamOggVorbis.load_from_file(directory_path + json_data["AudioFile"])

# Generate the chart of an Amiga module, its notes are the keysounds
func loadModule() -> bool:
	# In local versus both playfields share the same module player, only load it once
	modPlayer = get_node(audio).get_node_or_null("ModPlayer")
	if modPlayer == null:
		var module : ModModule = ModModule.load_file(Loader.file_path)
		if module == null:
			OS.alert("Invalid Amiga module: " + Loader.file_path)
			get_tree().change_scene_to_file.call_deferred("res://scenes/menu/music_select.tscn")
			return false
		modPlayer = ModPlayer.new(module)
		modPlayer.name = "ModPlayer"
		get_node(audio).add_child(modPlayer)
	var chart : ModChart = ModChart.new(modPlayer.module, Loader.chart_difficulty, opt("keys_mode"))
	noteArray = chart.noteArray
	keysoundArray = chart.keysoundArray
	return true

# Current time of the song (seconds)
func songPosition() -> float:
	if modPlayer:
		return modPlayer.get_playback_position()
	# The playback position only moves at each audio mix, the time since then makes it smooth
	return get_node(audio).get_playback_position() + AudioServer.get_time_since_last_mix()

func _process(_delta) -> void:
	# Get current audio playback time
	currentSongPos = songPosition()
	# The notes come later when the sound is late (output latency and user offset)
	currentSongPos -= AudioServer.get_output_latency() + Global.audio_offset / 1000.0
	# Confirm game end
	if (currentSongPos >= endPos):
		finish(false)
		return
	# Confirm completion of long note
	for i in range(0, 8):
		if shouldPressEnd[i] == -1.0:
			continue
		if (AUTOPLAY or (AUTOSCRATCH and i == 7)) and shouldPressEnd[i] <= currentSongPos:
			endLongnote(i, "PGreat")
		elif currentSongPos - shouldPressEnd[i] > Judge.BAD_WINDOW / 1000.0:
			# Still held long after the end
			endLongnote(i, "Bad")
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
			note.comboTicks = false
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
		if modPlayer:
			modPlayer.hit(queue[i][0].keysound)
		if queue[i][0].isLongnote == false:
			# General note
			addJudge(queue[i][0].score)
			queue[i][0].free()
			queue[i].pop_front()
		elif queue[i][0].score == "Bad":
			# Long note failure, its release is lost too
			addJudge("Bad")
			addJudge("Poor")
			queue[i][0].longnoteFailed()
			queue[i].pop_front()
		else:
			# Long note normal entry
			startLongnote(i)
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
	if modPlayer == null:
		return
	for n in queue[i]:
		if n != null:
			modPlayer.preview(n.keysound)
			return
	modPlayer.preview(keysoundArray[i][0] if keysoundArray[i] else lastKeysound[i])
# Judge the notes from the time left before them
func updateQueue() -> void:
	for q in queue:
		for n in q:
			if n.longnoteScore == "":
				var judgement : String = Judge.judge(currentSongPos - n.hitTime)
				n.score = judgement if judgement != "" else "Default"
# Press a long note: the head is judged, the release will be judged at its end
func startLongnote(i : int) -> void:
	addJudge(queue[i][0].score)
	shouldPress[i] = true
	shouldPressEnd[i] = queue[i][0].hitTime + queue[i][0].longnoteTime
	queue[i][0].longnoteStart()
# Judge the release of the held long note of a lane
func endLongnote(i : int, judgement : String) -> void:
	addJudge(judgement)
	if judgement == "Poor":
		queue[i][0].longnoteFailed()
	queue[i].pop_front()
	shouldPress[i] = false
	shouldPressEnd[i] = -1.0
# Y position of a note at the current time, it reaches PERFECT_YPOS at its time
func notePosition(time : float) -> float:
	return PERFECT_YPOS * (1.0 - (time - currentSongPos) / speed)
func updateInputState() -> void:
	# Get the current analog value from the turntable
	var current_value := Input.get_action_strength(prefix + "analog_turntable_fwd") - Input.get_action_strength(prefix + "analog_turntable_rew")
	# Check if the analog value has changed since the last frame
	if current_value != previous_value:
		keyPressed(7)
		lastScratchMove = Time.get_ticks_msec()
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
			endLongnote(i, judgement if judgement != "" else "Poor")
	# Light the lanes, the scratch lane included
	for i in range(0, 8):
		get_node("pressed" + str(i+1)).visible = pressed[i]
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
	if versus:
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
		get_tree().change_scene_to_file("res://scenes/result/result_screen.tscn")
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
