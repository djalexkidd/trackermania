extends Node2D
class_name Note

# The following code is based from https://github.com/scenent/gd-rhythm

# Channel value
var channel : int
# The y-coordinate at which the note descends per frame
var coordPerFrame : float
# Note Status
var score : String = "Default"
# Flag to check if it is a long note
var isLongnote : bool = false
# Long note time
var longnoteTime : float = -1.0
# The time it takes for the current note to go down to PERFECT_YPOS
var speed : float
# Long note effect node
var effect : Object

# Score when long note is pressed
var longnoteScore : String = ""
# Coordinate queue corresponding to long note combo
var longnoteComboQueue : Array = []

func setNote(_channel : int, _speed : float, _coordPerFrame : float, _longnoteTime : float = -1.0) -> void:
	self.global_position.y = 0.0
	channel = _channel
	speed = _speed
	coordPerFrame = _coordPerFrame
	effect = $LN_Effect
	# Long note settings
	if (_longnoteTime != -1.0):
		isLongnote = true
		longnoteTime = _longnoteTime
		var size : float = float((60.0 * coordPerFrame) * longnoteTime)
		$LN_Effect.position.y = -size
		$LN_Effect.size.y = size
		$LN_EffectEnd.position.y = -size
		$LN_EffectEnd.visible = true
	# Color the note in blue if it's on the upper keys like in beatmania.
	if channel in [2, 4, 6]:
		$bar.color = Color(0, 0, 1)
	# Color the note in red if in scratch lane
	if channel == 8:
		$bar.color = Color(1, 0, 0)
		$bar.size.x = 132
		$bar.position.x = -35

func longnoteStart():
	longnoteScore = score
	var longnoteStartPos = global_position.y
	var step = 10 / speed
	var index = snapped(longnoteStartPos, 1)
	var tempComboQueue = []
	# Creates a combo queue of 50 elements per second.
	while (index <= longnoteStartPos + effect.size.y):
		tempComboQueue.append(index)
		index += step
	# If the number of combo queue elements is not a multiple of 2, remove one from the back.
	if (len(tempComboQueue) != snapped(len(tempComboQueue), 2)):
		tempComboQueue.pop_back()
	# 10 combo queues are selected from the 50 combo queues per second.
	for i in range(1, len(tempComboQueue), 5):
		longnoteComboQueue.append(tempComboQueue[i-1])

func longnoteFailed():
	longnoteComboQueue.clear()
	$LN_Effect.color = Color("d38b8e")

func _process(_delta):
	self.global_position.y += coordPerFrame
	# If it is a long note and the combo queue is not empty, add the combo.
	if (isLongnote and longnoteComboQueue != []):
		if (global_position.y >= longnoteComboQueue[0]):
			longnoteComboQueue.pop_front()
			get_parent().get_parent().addCombo(longnoteScore)
