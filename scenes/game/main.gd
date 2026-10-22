extends Node2D

# The one game scene for 1P, 2P and local versus: both playfields are always on screen,
# the one of a player who is not playing stays dimmed like the empty side of IIDX.

# Time the WIN/LOSE banners stay on screen before the result screen
const RESULT_DELAY : float = 3.0
# Progress bar on the left edge of the screen: from the start (top) to the end (bottom) of the song
const PROGRESS_RECT : Rect2 = Rect2(8, 8, 8, 704)
# Panel of the BPM at the bottom middle of the screen
const BPM_RECT : Rect2 = Rect2(556, 618, 168, 66)
const PROGRESS_FILL_COLOR : Color = Color(0.2, 0.7, 1.0)
const PROGRESS_TICK_COLOR : Color = Color(0.3, 0.5, 0.8, 0.35)

var playersDone : int = 0
# Playfields that play, the first one drives the progress bar and the BPM
var playing : Array[Playfield] = []
var netplay : bool = false
var progress : float = 0.0
var bpmStyle : StyleBoxFlat
var progressStyle : StyleBoxFlat

func _ready() -> void:
	# Netplay plays alone on this machine, the other side shows the live ranking
	var versus : bool = Global.p1_joined and Global.p2_joined
	netplay = not versus and Netplay.in_round()
	var solo : int = 2 if Global.p2_joined and not Global.p1_joined else 1
	for player in [1, 2]:
		var field : Playfield = get_node("P%d" % player)
		var plays : bool = versus or player == solo
		field.setup(player, plays, versus, netplay)
		if plays:
			playing.append(field)
	if versus:
		$P1.finished.connect(playerFinished)
		$P2.finished.connect(playerFinished)
	if netplay:
		var scoreboard : Control = preload("res://scripts/netplay/scoreboard.gd").new()
		scoreboard.position = Vector2($P2.position.x, 0)
		scoreboard.size = Vector2(Playfield.PLAYFIELD_WIDTH, 540)
		add_child(scoreboard)
	for field in playing:
		field.start()
	bpmStyle = StyleBoxFlat.new()
	bpmStyle.bg_color = Color(0.03, 0.05, 0.1, 0.85)
	bpmStyle.border_color = Color(0.3, 0.6, 1.0, 0.7)
	bpmStyle.set_border_width_all(2)
	bpmStyle.set_corner_radius_all(6)
	progressStyle = StyleBoxFlat.new()
	progressStyle.bg_color = Color(0.04, 0.07, 0.14)
	progressStyle.border_color = Color(0.45, 0.75, 1.0, 0.6)
	progressStyle.set_border_width_all(1)

func _process(_delta : float) -> void:
	queue_redraw()
	if playing.is_empty() or playing[0].endPos <= 0.0:
		$BpmValue.text = "---"
		progress = 0.0
		return
	var reference : Playfield = playing[0]
	progress = clampf(reference.currentSongPos / reference.endPos, 0.0, 1.0)
	var bpm : float = reference.currentBpm()
	$BpmValue.text = "%d" % roundi(bpm) if bpm > 0.0 else "---"

func _draw() -> void:
	draw_style_box(progressStyle, PROGRESS_RECT.grow(1))
	draw_style_box(bpmStyle, BPM_RECT)
	if playing.is_empty() or playing[0].endPos <= 0.0:
		return
	var reference : Playfield = playing[0]
	var top : float = PROGRESS_RECT.position.y
	var height : float = PROGRESS_RECT.size.y
	var left : float = PROGRESS_RECT.position.x
	var width : float = PROGRESS_RECT.size.x
	# Measure lines, from the start to the end of the song
	for time in reference.measures:
		var y : float = top + height * clampf(time / reference.endPos, 0.0, 1.0)
		draw_line(Vector2(left, y), Vector2(left + width, y), PROGRESS_TICK_COLOR, 1.0)
	# The part already played, lit up to its head
	var head : float = top + height * progress
	draw_rect(Rect2(left - 3, top, width + 6, head - top), Color(PROGRESS_FILL_COLOR, 0.15))
	draw_rect(Rect2(left, top, width, head - top), PROGRESS_FILL_COLOR)
	draw_rect(Rect2(left - 3, head - 3, width + 6, 6), Color(1, 1, 1, 0.3))
	draw_rect(Rect2(left, head - 1.5, width, 3), Color.WHITE)

func playerFinished() -> void:
	playersDone += 1
	if playersDone < 2:
		return
	# Both players are done, the highest score wins
	for player in [1, 2]:
		var result : String = Global.get_versus_result(player)
		var label : Label = get_node("P%dResult" % player)
		label.text = result
		label.add_theme_color_override("font_color", Global.VERSUS_RESULT_COLORS[result])
		label.show()
		get_node("P%d/getready" % player).hide()
	await get_tree().create_timer(RESULT_DELAY).timeout
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/result/result.tscn")
