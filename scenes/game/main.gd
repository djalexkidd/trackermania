extends Node2D

# The following code is based from https://github.com/scenent/gd-rhythm

# The perfect y coordinate to press on the screen
const PERFECT_YPOS : float = 500
# Y-axis end of the Gear UI
const GEAR_END : float = 520
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
# Current score
var currentScore   : float   = 0.0
# Maximum points you can get
var maximumScore   : float   = 0.0
# Analog
var previous_value := 0.0
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
	for i in range(len(arr)):
		arr[i] -= sp
	while (arr[0] < sp):
		arr.pop_front()
	return arr
# Get the maximum number of points you can get.
func getMaximumScore(notearr : Array) -> float:
	var result : float = 0.0
	
	if opt("keys_mode") == 5:
		noteArray[5] = []
		noteArray[6] = []
		keysoundArray[5] = []
		keysoundArray[6] = []
	
	for i in notearr:
		for note in i:
			if (len(note) == 1):
				result += 1.0
			else:
				result += note[1] * 10.0
	return result
# Add a combo.
func addCombo(score : String) -> void:
	combo += 1
	if combo > comboMax:
		comboMax = combo
	if (score == "Perfect"):
		currentScore += 1.0
	elif (score == "Good"):
		currentScore += 0.7
	$combo.text = str(combo)
	if combo % 2 == 0 and combo >= 50 and opt("gauge_level") == 2:
		$GrooveGauge.value += 2
	if combo % 2 == 0 and opt("gauge_level") < 2:
		$GrooveGauge.value += 2
	$GrooveGauge/Label.text = str(int($GrooveGauge.value)) + " %"
	$anim.play(score)
	await $anim.animation_finished
	$anim.play("combo")
	await $anim.animation_finished
# Resets the combo.
func resetCombo() -> void:
	combo = 0
	$combo.text = str(combo)
	$anim.play("Bad")
	if opt("gauge_level") == 1:
		$GrooveGauge.value -= 2
	elif opt("gauge_level") == 2:
		$GrooveGauge.value -= 8
	else:
		$GrooveGauge.value -= 4
	$GrooveGauge/Label.text = str(int($GrooveGauge.value)) + " %"
	if $GrooveGauge.value == 0 and opt("gauge_level") == 2:
		# Deferred because the note queues are still being iterated
		finish.call_deferred(true)
	await $anim.animation_finished
	$anim.play("combo")
	await $anim.animation_finished

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
	Global.set_player_var(player, "combo_max_top", getMaximumScore(noteArray))
	
	if opt("random"):
		randomize()
		# The keysounds follow their lane
		var lanes : Array = range(8)
		lanes.shuffle()
		noteArray = lanes.map(func(i): return noteArray[i])
		keysoundArray = lanes.map(func(i): return keysoundArray[i])
	
	if opt("gauge_level") == 2:
		$GrooveGauge.value = 100
		$GrooveGauge/Label.text = "100 %"
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
	subLineArray = getSubLineArr(endPos, speed, SUBLINE_LENGTH)
	maximumScore = getMaximumScore(noteArray)
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
	return modPlayer.get_playback_position() if modPlayer else get_node(audio).get_playback_position()

func _process(_delta) -> void:
	# Get current audio playback time
	currentSongPos = songPosition()
	currentSongPos -= AudioServer.get_output_latency()
	# Confirm game end
	if (currentSongPos >= endPos):
		finish(false)
		return
	# Confirm completion of long note
	for i in range(0, 8):
		if shouldPressEnd[i] != -1.0 and shouldPressEnd[i] <= currentSongPos:
			shouldPress[i] = false
			shouldPressEnd[i] = -1.0
			queue[i].pop_front()
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
			if (len(info) == 1):
				# Create a general note
				note.setNote(i+1, speed, coordPerFrame)
			else:
				# Create long note
				note.setNote(i+1, speed, coordPerFrame, info[1])
			var container = get_node("container" + str(i+1))
			container.add_child(note)
			container.get_child(container.get_child_count()-1).position.x = laneX(i)
			container.get_child(container.get_child_count()-1).position.y += coordPerFrame * (currentSongPos - info[0]) / 60
			queue[i].append(container.get_child(container.get_child_count()-1))
	# Create auxiliary line
	if (subLineArray and subLineArray[0] <= currentSongPos):
		subLineArray.pop_front()
		var line : Line2D = Line2D.new()
		line.width = 1
		line.points = [Vector2(-37, 0), Vector2(800, 0)]
		$sublinecontainer.add_child(line)
	# Move & Delete Auxiliary Lines
	for line in $sublinecontainer.get_children():
		if line.position.y >= PERFECT_YPOS:
			line.queue_free()
		line.position.y += coordPerFrame
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
		if (queue[7][0].position.y >= PERFECT_YPOS):
			queue[7][0].score = "Perfect"
			addCombo(queue[7][0].score)
			queue[7][0].free()
			queue[7].pop_front()
	elif (queue[7] and queue[7][0].isLongnote == true and queue[7][0].longnoteScore == ""):
		if (queue[7][0].position.y >= PERFECT_YPOS):
			queue[7][0].score = "Perfect"
			shouldPress[7] = true
			shouldPressEnd[7] = currentSongPos + queue[7][0].longnoteTime
			queue[7][0].longnoteStart()

func autoplay():
	for i in range(0, 8):
		if (queue[i] and queue[i][0] == null):
			queue[i].pop_front()
		if (queue[i] and queue[i][0].isLongnote == false):
			if (queue[i][0].position.y >= PERFECT_YPOS):
				queue[i][0].score = "Perfect"
				addCombo(queue[i][0].score)
				queue[i][0].free()
				queue[i].pop_front()
		elif (queue[i] and queue[i][0].isLongnote == true and queue[i][0].longnoteScore == ""):
			if (queue[i][0].position.y >= PERFECT_YPOS):
				queue[i][0].score = "Perfect"
				shouldPress[i] = true
				shouldPressEnd[i] = currentSongPos + queue[i][0].longnoteTime
				queue[i][0].longnoteStart()
# Called when the i-th channel key is pressed, returns false if there was no note to hit
func keyPressed(i : int) -> bool:
	# If the first note in that channel is scored
	if len(queue[i]) != 0 and queue[i][0].score != "Default":
		# The keysound plays even for a bad timing like in IIDX
		if modPlayer:
			modPlayer.hit(queue[i][0].keysound)
		if queue[i][0].score == "Bad":
			resetCombo()
			if queue[i][0].isLongnote == false:
				# General note failure
				queue[i][0].free()
			else:
				# Long note failure
				queue[i][0].longnoteFailed()
			queue[i].pop_front()
		else:
			if (queue[i][0].isLongnote == false):
				# General notes completed
				addCombo(queue[i][0].score)
				queue[i][0].free()
				queue[i].pop_front()
			else:
				# Long note normal entry
				shouldPress[i] = true
				shouldPressEnd[i] = currentSongPos + queue[i][0].longnoteTime
				queue[i][0].longnoteStart()
		return true
	return false
# Play the keysound of the next note of a lane when its key is pressed without a note to hit
func previewKeysound(i : int) -> void:
	if modPlayer == null:
		return
	for n in queue[i]:
		if n != null:
			modPlayer.preview(n.keysound)
			return
	modPlayer.preview(keysoundArray[i][0] if keysoundArray[i] else lastKeysound[i])
func updateQueue() -> void:
	for q in queue:
		for n in q:
			var m = n.position.y
			if (m < 400): continue
			if (400 <= m and m < 440): 
				n.score = "Bad"
			elif (440 <= m and m < 480):
				n.score = "Good"
			elif (480 <= m and m < 520):
				n.score = "Perfect"
func updateInputState() -> void:
	# Get the current analog value from the turntable
	var current_value := Input.get_action_strength(prefix + "analog_turntable_fwd") - Input.get_action_strength(prefix + "analog_turntable_rew")
	# Check if the analog value has changed since the last frame
	if current_value != previous_value:
		# Calculate the rotation difference
		var rotation_difference := (current_value - previous_value)
		# Apply the rotation difference
		pressed[7] = true
		keyPressed(7)

		# Update the previous value to the current one
		previous_value = current_value
	else:
		pressed[7] = false
	
	if (Input.is_action_just_pressed(prefix + "digital_turntable_rew")):
		pressed[7] = true
		if not keyPressed(7):
			previewKeysound(7)
	if (Input.is_action_just_released(prefix + "digital_turntable_rew")):
		pressed[7] = false
	
	for i in range(0, 8):
		get_node("pressed" + str(i+1)).visible = pressed[i]
		if (Input.is_action_just_pressed(keycodes[i])):
			pressed[i] = true
			if not keyPressed(i):
				previewKeysound(i)
		if (Input.is_action_just_released(keycodes[i])):
			pressed[i] = false
		if (pressed[i] == false and shouldPress[i]):
			# Failed while pressing long note
			resetCombo()
			queue[i][0].longnoteFailed()
			queue[i].pop_front()
			shouldPressEnd[i] = -1.0
			shouldPress[i] = false
func dequeue() -> void:
	for i in range(0, 8):
		if (len(queue[i]) != 0 and queue[i][0] != null and queue[i][0].position.y >= GEAR_END):
			# If it's a long note
			if (queue[i][0].isLongnote == true):
				# If you didn't press it in the first place
				if (not shouldPress[i]):
					queue[i][0].longnoteFailed()
					queue[i].pop_front()
					resetCombo()
			# If it's a general note
			else:
				queue[i].pop_front()
				resetCombo()
func killGarbage() -> void:
	for i in range(1, 9):
		for n in get_node("container" + str(i)).get_children():
			if (n.position.y - n.effect.size.y >= 600):
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
	Global.set_player_var(player, "score", snapped(currentScore / maximumScore * 100.0, 0.1))
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
