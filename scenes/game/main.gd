extends Node2D

# The following code is based from https://github.com/scenent/gd-rhythm

# The perfect y coordinate to press on the screen
const PERFECT_YPOS : float = 500
# Y-axis end of the Gear UI
const GEAR_END : float = 520
# After the last note is finished, wait for this margin and then the game ends.
const ENDPOS_BIAS : float = +2.0
# Auxiliary line spacing (sec)
const SUBLINE_LENGTH : float = 1.0
# Autoplay flag
var AUTOPLAY : bool = Global.auto_play
# Key code for each of the 4 channels (can be added in the input map)
@export var keycodes : PackedStringArray
# Audio Player Node Path
@export_node_path("AudioStreamPlayer") var audio
# Preload note scene
@onready var noteScene : Note = preload("res://scenes/game/note.tscn").instantiate()
# The time it takes for a note to descend from (y=0) to (y=PERFECT_YPOS)
var speed : float = 1.0
# Note information corresponding to 7 channels
var noteArray      : Array = [
							[[5.2], [6.4], [6.8], [8], [15.2], [16.8], [18], [19.6]],
							[[8.4], [10], [14.8], [18.2], [19.8]],
							[[5.6], [7.2], [15.6], [15.8], [16], [16.4], [17.2], [17.4], [17.6], [18.4], [20]],
							[[8.8], [10.4], [12.8], [14.4], [18.6], [20.2]],
							[[6], [7.6], [12.4], [14], [18.8], [20.4]],
							[[9.2], [10.8], [11.6], [13.2], [19], [20.6]],
							[[12], [13.6], [19.2], [19.4], [20.8], [21]]
							]
# Auxiliary line information
var subLineArray   : Array = []
# Current audio playback time (seconds)
var currentSongPos : float   = 0.0
# The y-coordinate at which the note descends per frame
var coordPerFrame  : float
# Time until game ends (in seconds)
var endPos         : float   = 0.0

# 7 cues containing currently valid note scenes
var queue          : Array   = [[], [], [], [], [], [], []]
# Check the pressed state of each channel
var pressed        : Array   = [false, false, false, false, false, false, false]
# Check if you should press and hold now
var shouldPress    : Array   = [false, false, false, false, false, false, false]
# The time when the currently pressed long note ends
var shouldPressEnd : Array   = [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0]
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
	perfectYpos /= 60.0
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
	
	if Global.keys_mode == 5:
		noteArray.resize(5)
	
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
	$anim.play(score)
	await $anim.animation_finished
	$anim.play("combo")
	await $anim.animation_finished
# Resets the combo.
func resetCombo() -> void:
	combo = 0
	$combo.text = str(combo)
	$anim.play("Bad")
	await $anim.animation_finished
	$anim.play("combo")
	await $anim.animation_finished

func _ready() -> void:
	set_process(false)
	if Global.keys_mode == 5:
		$AutoPlay6.show()
		$AutoPlay7.show()
	for i in range(1, Global.keys_mode+1):
		get_node("pressed" + str(i)).visible = false
	var noteStart : float = INF
	for i in range(0, Global.keys_mode):
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
	for i in range(0, Global.keys_mode):
		noteArray[i] = getCorrectArr(noteArray[i], speed)
	coordPerFrame = getCoordPerFrame(speed, PERFECT_YPOS)
	for i in range(0, Global.keys_mode):
		if getEndPos(noteArray[i], speed, ENDPOS_BIAS) > endPos:
			endPos = getEndPos(noteArray[i], speed, ENDPOS_BIAS)
	if (get_node(audio).stream.get_length() < endPos):
		OS.alert("Please add enough space after the music, or decrease the ENDPOS_BIAS")
	subLineArray = getSubLineArr(endPos, speed, SUBLINE_LENGTH)
	maximumScore = getMaximumScore(noteArray)
	print(maximumScore)
	if (AUTOPLAY):
		$isautoplay.visible = true
		print("AUTO PLAYING...")
	await get_tree().create_timer(1.0).timeout
	$getready.hide()
	get_node(audio).play()
	set_process(true)

func _process(_delta) -> void:
	# Get current audio playback time
	currentSongPos = get_node(audio).get_playback_position()
	currentSongPos -= AudioServer.get_output_latency()
	# Confirm game end
	if (currentSongPos >= endPos):
		done = true
		for i in range(1, 5): get_node("pressed" + str(i)).visible = false
		for i in $sublinecontainer.get_children(): i.free()
		Global.score = snapped(currentScore / maximumScore * 100.0, 0.1)
		Global.combo_max = comboMax
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		set_process(false)
		get_tree().change_scene_to_file("res://scenes/result/result_screen.tscn")
	# Confirm completion of long note
	for i in range(0, Global.keys_mode):
		if shouldPressEnd[i] != -1.0 and shouldPressEnd[i] <= currentSongPos:
			shouldPress[i] = false
			shouldPressEnd[i] = -1.0
			queue[i].pop_front()
	# Create a note
	for i in range(0, Global.keys_mode):
		if (noteArray[i] and noteArray[i][0][0] <= currentSongPos):
			var note : Note = noteScene.duplicate()
			var info : Array = noteArray[i].pop_front()
			if (len(info) == 1):
				# Create a general note
				note.setNote(i+1, speed, coordPerFrame)
			else:
				# Create long note
				note.setNote(i+1, speed, coordPerFrame, info[1])
			var container = get_node("container" + str(i+1))
			container.add_child(note)
			container.get_child(container.get_child_count()-1).global_position.x = 100 * (i+1)
			container.get_child(container.get_child_count()-1).global_position.y += coordPerFrame * (currentSongPos - info[0]) / 60
			queue[i].append(container.get_child(container.get_child_count()-1))
	# Create auxiliary line
	if (subLineArray and subLineArray[0] <= currentSongPos):
		subLineArray.pop_front()
		var line : Line2D = Line2D.new()
		line.width = 1
		line.points = [Vector2(100, 0), Vector2(800, 0)]
		$sublinecontainer.add_child(line)
	# Move & Delete Auxiliary Lines
	for line in $sublinecontainer.get_children():
		if line.position.y >= PERFECT_YPOS:
			line.queue_free()
		line.position.y += coordPerFrame
	# Check auto play
	if (AUTOPLAY):
		autoplay()
		killGarbage()
		return
	# Assign points to all notes in the queue
	updateQueue()
	# Input verification and [Failure while holding down long note] processing
	updateInputState()
	# [Failure to press at all, normal note and long note] Processing
	dequeue()
	# Delete all notes that are outside the screen
	killGarbage()

func autoplay():
	for i in range(0, Global.keys_mode):
		if (queue[i] and queue[i][0] == null):
			queue[i].pop_front()
		if (queue[i] and queue[i][0].isLongnote == false):
			if (queue[i][0].global_position.y >= PERFECT_YPOS):
				queue[i][0].score = "Perfect"
				addCombo(queue[i][0].score)
				queue[i][0].free()
				queue[i].pop_front()
		elif (queue[i] and queue[i][0].isLongnote == true and queue[i][0].longnoteScore == ""):
			if (queue[i][0].global_position.y >= PERFECT_YPOS):
				queue[i][0].score = "Perfect"
				shouldPress[i] = true
				shouldPressEnd[i] = currentSongPos + queue[i][0].longnoteTime
				queue[i][0].longnoteStart()
# Called when the i-th channel key is pressed
func keyPressed(i : int) -> void:
	# If the first note in that channel is scored
	if len(queue[i]) != 0 and queue[i][0].score != "Default":
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
func updateQueue() -> void:
	for q in queue:
		for n in q:
			var m = n.global_position.y
			if (m < 400): continue
			if (400 <= m and m < 440): 
				n.score = "Bad"
			elif (440 <= m and m < 480):
				n.score = "Good"
			elif (480 <= m and m < 520):
				n.score = "Perfect"
func updateInputState() -> void:
	for i in range(0, Global.keys_mode):
		get_node("pressed" + str(i+1)).visible = pressed[i]
		if (Input.is_action_just_pressed(keycodes[i])):
			pressed[i] = true
			keyPressed(i)
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
	for i in range(0, Global.keys_mode):
		if (len(queue[i]) != 0 and queue[i][0] != null and queue[i][0].global_position.y >= GEAR_END):
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
	for i in range(1, 5):
		for n in get_node("container" + str(i)).get_children():
			if (n.global_position.y - n.effect.size.y >= 600):
				n.free()
