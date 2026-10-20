extends Node2D

# The following code is based from https://github.com/scenent/gd-rhythm

# The perfect y coordinate to press on the screen
const PERFECT_YPOS : float = 500
# After the last note is finished, wait for this margin and then the game ends.
const ENDPOS_BIAS : float = +2.0
# Auxiliary line spacing (sec)
const SUBLINE_LENGTH : float = 1.0
# Network node
@onready var networkRoot = get_node("..")
# Key code for each of the 4 channels (can be added in the input map)
@export var keycodes : PackedStringArray
# Audio Player Node Path
@export_node_path("AudioStreamPlayer") var audio
# Preload note scene
@onready var noteScene : Note = preload("res://scenes/game/note.tscn").instantiate()
# The time it takes for a note to descend from (y=0) to (y=PERFECT_YPOS)
var speed : float = Global.hispeed
# Note information corresponding to 7 channels
var noteArray      : Array = []
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
	for i in range(len(arr)):
		arr[i] -= sp
	while (arr[0] < sp):
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
	gauge = Judge.gaugeChange(Global.gauge_level, judgement, gauge, gaugeRecovery)
	showGauge()
	if gauge <= 0.0 and not done:
		done = true
		set_process(false)
		saveResults()
		Global.failed = true
		get_tree().change_scene_to_file.call_deferred("res://scenes/result/result_screen.tscn")
func showGauge() -> void:
	$GrooveGauge.value = Judge.gaugeDisplay(Global.gauge_level, gauge)
	$GrooveGauge/Label.text = str(int($GrooveGauge.value)) + " %"
# A key pressed without a note to hit: an empty POOR if a note comes soon, it only hurts the gauge
func emptyPress(i : int) -> void:
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
# Store the results in Global for the result screen
func saveResults() -> void:
	Global.combo_max = comboMax
	Global.gauge_score = $GrooveGauge.value
	Global.ex_score = exScore
	Global.score = exScore * 100.0 / maxi(noteCount * 2, 1)

func load_mp3(path):
	var file = FileAccess.open(path, FileAccess.READ)
	var sound = AudioStreamMP3.new()
	sound.data = file.get_buffer(file.get_length())
	return sound

func _ready() -> void:
	var json_data = Loader.load_json_file(Loader.file_path)
	var directory_path = Loader.file_path.substr(0, Loader.file_path.rfind("/") + 1)
	var file_extension = json_data["AudioFile"].get_extension()
	
	noteArray = json_data["noteArray"]
	if Global.keys_mode == 5:
		noteArray[5] = []
		noteArray[6] = []
	noteCount = Judge.noteCount(noteArray)
	Global.combo_max_top = noteCount
	gauge = Judge.gaugeStart(Global.gauge_level)
	gaugeRecovery = Judge.gaugeRecovery(Global.gauge_level, noteCount)
	showGauge()
	
	if Global.random:
		randomize()
		noteArray.shuffle()
	
	if file_extension == "mp3":
		get_node(audio).stream = load_mp3(directory_path + json_data["AudioFile"])
	elif file_extension == "ogg":
		get_node(audio).stream = AudioStreamOggVorbis.load_from_file(directory_path + json_data["AudioFile"])
	
	for i in range(0, networkRoot._game._players.size()):
		var player_score_container = HBoxContainer.new()
		var label = Label.new()
		var score_label = Label.new()
		
		$PlayersContainer.add_child(player_score_container)
		player_score_container.add_child(label)
		player_score_container.add_child(score_label)
		player_score_container.name = str(networkRoot._game._players[i])
		label.text = str(networkRoot._game.get_player_name(i))
		score_label.name = "score"
	
	set_process(false)
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
	if (get_node(audio).stream == null):
		OS.alert("Please assign a music")
	for i in range(0, 8):
		noteArray[i] = getCorrectArr(noteArray[i], speed)
	coordPerFrame = getCoordPerFrame(speed, PERFECT_YPOS)
	for i in range(0, 8):
		if getEndPos(noteArray[i], speed, ENDPOS_BIAS) > endPos:
			endPos = getEndPos(noteArray[i], speed, ENDPOS_BIAS)
	if (get_node(audio).stream.get_length() < endPos):
		OS.alert("Please add enough space after the music, or decrease the ENDPOS_BIAS")
	subLineArray = getSubLineArr(endPos, speed, SUBLINE_LENGTH)
	await get_tree().create_timer(1.0).timeout
	$getready.hide()
	get_node(audio).play()
	set_process(true)

func _process(_delta) -> void:
	# Get current audio playback time
	# The playback position only moves at each audio mix, the time since then makes it smooth
	currentSongPos = get_node(audio).get_playback_position() + AudioServer.get_time_since_last_mix()
	currentSongPos -= AudioServer.get_output_latency()
	# Confirm game end
	if (currentSongPos >= endPos):
		done = true
		for i in range(1, 5): get_node("pressed" + str(i)).visible = false
		for i in $sublinecontainer.get_children(): i.free()
		saveResults()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		set_process(false)
		get_node("..").game_finished("EX Score: %d (%.2f%%)" % [exScore, Global.score])
		queue_free()
		return
	# Confirm completion of long note
	for i in range(0, 8):
		if shouldPressEnd[i] != -1.0 and currentSongPos - shouldPressEnd[i] > Judge.BAD_WINDOW / 1000.0:
			# Still held long after the end
			endLongnote(i, "Bad")
	# Create a note
	for i in range(0, 8):
		if (noteArray[i] and noteArray[i][0][0] <= currentSongPos):
			var note : Note = noteScene.duplicate()
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
			if i == 7:
				container.get_child(container.get_child_count()-1).global_position.x = 64
			else:
				container.get_child(container.get_child_count()-1).global_position.x = 64+(100 * (i+1))
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
	# Assign points to all notes in the queue
	updateQueue()
	# Input verification and [Failure while holding down long note] processing
	updateInputState()
	# [Failure to press at all, normal note and long note] Processing
	dequeue()
	# Delete all notes that are outside the screen
	killGarbage()
	# Update score
	rpc("updateRemote", exScore)

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
	var current_value := Input.get_action_strength("p1_analog_turntable_fwd") - Input.get_action_strength("p1_analog_turntable_rew")
	# Check if the analog value has changed since the last frame
	if current_value != previous_value:
		keyPressed(7)
		lastScratchMove = Time.get_ticks_msec()
		# Update the previous value to the current one
		previous_value = current_value
	
	if (Input.is_action_just_pressed("p1_digital_turntable_rew")):
		if not keyPressed(7):
			emptyPress(7)
	
	# Scratch held while a digital direction is held or just after the analog turntable moved
	pressed[7] = Input.is_action_pressed("p1_digital_turntable_fwd") or Input.is_action_pressed("p1_digital_turntable_rew") \
		or Time.get_ticks_msec() - lastScratchMove < SCRATCH_LIGHT_MS

	for i in range(0, 8):
		if (Input.is_action_just_pressed(keycodes[i])):
			if i != 7:
				pressed[i] = true
			if not keyPressed(i):
				emptyPress(i)
		if (Input.is_action_just_released(keycodes[i]) and i != 7):
			pressed[i] = false
		if (pressed[i] == false and shouldPress[i]):
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
					queue[i][0].longnoteFailed()
					queue[i].pop_front()
					addJudge("Poor")
					addJudge("Poor")
			# If it's a general note
			else:
				queue[i].pop_front()
				addJudge("Poor")
func killGarbage() -> void:
	for i in range(1, 9):
		for n in get_node("container" + str(i)).get_children():
			# The late notes stay until they are judged
			if (n.position.y - n.effect.size.y >= 600 and not queue[i-1].has(n)):
				n.free()

var sender = ""
@rpc("any_peer", "call_local")
func updateRemote(score):
	sender = multiplayer.get_remote_sender_id()
	get_node("PlayersContainer/" + str(sender) + "/score").text = str(score)
