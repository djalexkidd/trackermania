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
# Scratch notes are shown in green when auto scratch is on
var autoScratch : bool = Global.auto_scratch
# Keysound played when the note is hit (Amiga modules only)
var keysound : int = -1
# Song time when the note reaches perfectYpos, the note then follows the song time instead of the frames
var hitTime : float = -1.0
var perfectYpos : float
# Score when long note is pressed
var longnoteScore : String = ""

# The note is centered on its lane, width is the width of the lane
func setNote(_channel : int, _speed : float, _coordPerFrame : float, width : float, _longnoteTime : float = -1.0) -> void:
	self.position.y = 0.0
	channel = _channel
	speed = _speed
	coordPerFrame = _coordPerFrame
	effect = $LN_Effect
	for part in [$bar, $LN_Effect, $LN_EffectEnd]:
		part.size.x = width
		part.position.x = -width / 2.0
	# Long note settings
	if (_longnoteTime != -1.0):
		isLongnote = true
		longnoteTime = _longnoteTime
		var size : float = float((Engine.get_frames_per_second() * coordPerFrame) * longnoteTime)
		$LN_Effect.position.y = -size
		$LN_Effect.size.y = size
		$LN_EffectEnd.position.y = -size
		$LN_EffectEnd.visible = true
		# The body of a long note is a soft blue instead of plain grey
		$LN_Effect.color = Color(0.3, 0.6, 1.0, 0.45)
	# Color the note in blue if it's on the upper keys like in beatmania.
	if channel in [2, 4, 6]:
		$bar.color = Color(0, 0, 1)
		$LN_EffectEnd.color = Color(0, 0, 1)
	# Color the note in red if in scratch lane
	if channel == 8:
		if !autoScratch:
			$bar.color = Color(1, 0, 0)
		else:
			$bar.color = Color(0, 1, 0)

func longnoteStart():
	longnoteScore = score

func longnoteFailed():
	$LN_Effect.color = Color("d38b8e")

func _process(_delta):
	if hitTime >= 0.0:
		position.y = perfectYpos * (1.0 - (hitTime - get_parent().get_parent().currentSongPos) / speed)
	else:
		self.position.y += coordPerFrame
