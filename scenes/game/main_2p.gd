extends Node2D

# Local versus: two playfields side by side sharing the same song

# Time the WIN/LOSE banners stay on screen before the result screen
const RESULT_DELAY : float = 3.0

var playersDone : int = 0

func _ready() -> void:
	$P1.finished.connect(playerFinished)
	$P2.finished.connect(playerFinished)

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
