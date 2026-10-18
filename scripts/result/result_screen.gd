extends Control

# Player shown on this screen, player 2 when playing alone
var player = 1 if Global.p1_joined else 2

func _ready() -> void:
	$ScoreLabel.text = "Accuracy: " + str(Global.get_player_var(player, "score")) + "%"
	$ComboLabel.text = "Max combo: " + str(Global.get_player_var(player, "combo_max"))
	$VBoxContainer/RankLabelValue.text = get_rank(player)
	
	var clear = get_clear(player)
	$ClearLabel.text = clear[0]
	$ClearLabel.add_theme_color_override("font_color", clear[1])
	
	Global.set_player_var(player, "failed", false)

# Rank letter of a player's score
func get_rank(player: int) -> String:
	var score = Global.get_player_var(player, "score")
	if score >= 88.89:
		return "AAA"
	elif score >= 77.78:
		return "AA"
	elif score >= 66.67:
		return "A"
	elif score >= 55.56:
		return "B"
	elif score >= 44.44:
		return "C"
	elif score >= 33.33:
		return "D"
	elif score >= 22.22:
		return "E"
	return "F"

# Clear lamp of a player as [text, color]
func get_clear(player: int) -> Array:
	var score = Global.get_player_var(player, "score")
	var gauge_level = Global.get_player_var(player, "gauge_level")
	var clear = ["CLEAR", Color(0, 0.735801, 1)]
	
	if Global.get_player_var(player, "gauge_score") < 80 and gauge_level < 2 or Global.get_player_var(player, "failed"):
		return ["FAILED", Color(1, 0.1, 0)]
	
	if gauge_level == 1:
		clear = ["EASY CLEAR", Color(0.3, 1, 0.3)]
	
	if gauge_level == 2:
		clear = ["HARD CLEAR", Color(1, 0.3, 0)]
	
	if Global.get_player_var(player, "combo_max") == Global.get_player_var(player, "combo_max_top"):
		clear = ["FULL COMBO", Color(1, 1, 0)]
	
	if score == 100:
		clear = ["PERFECT", Color(1, 1, 1)]
	
	return clear

func _on_button_pressed() -> void:
	Global.set_player_var(player, "score", 0)
	Global.set_player_var(player, "combo_max", 0)
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")
