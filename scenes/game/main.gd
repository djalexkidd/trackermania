extends Node2D

# The one game scene for 1P, 2P and local versus: both playfields are always on screen,
# the one of a player who is not playing stays dimmed like the empty side of IIDX.

# Time the WIN/LOSE banners stay on screen before the result screen
const RESULT_DELAY : float = 3.0
# Metal plate between the two playfields, with the song title and the BPM screens
const CENTER_PLATE : PackedVector2Array = [Vector2(496, 652), Vector2(508, 640), Vector2(772, 640), Vector2(784, 652), Vector2(784, 720), Vector2(496, 720)]
const TITLE_SCREEN : Rect2 = Rect2(512, 647, 256, 30)
const BPM_SCREEN : Rect2 = Rect2(572, 683, 136, 32)

var playersDone : int = 0
# Playfields that play, the first one gives the title and the BPM
var playing : Array[Playfield] = []
var netplay : bool = false

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
	if not playing.is_empty():
		$Title.text = playing[0].songInfo.get("title", "")

func _process(_delta : float) -> void:
	queue_redraw()

func _draw() -> void:
	Playfield.drawMetal(self, CENTER_PLATE)
	Playfield.drawScreen(self, TITLE_SCREEN)
	Playfield.drawScreen(self, BPM_SCREEN)
	draw_string(Playfield.FONT, BPM_SCREEN.position + Vector2(10, 21), "BPM", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Playfield.LABEL_COLOR)
	var bpm : float = playing[0].currentBpm() if not playing.is_empty() else 0.0
	if bpm > 0.0:
		Playfield.drawNumber(self, Vector2(BPM_SCREEN.end.x - 10, BPM_SCREEN.position.y + 25), roundi(bpm), 3, 20)

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
