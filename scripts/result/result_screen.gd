extends Control

# Player shown on this screen, player 2 when playing alone
var player = 1 if Global.p1_joined else 2

func _ready() -> void:
	$ScoreLabel.text = get_score_text(player)
	$ComboLabel.text = "Max combo: " + str(Global.get_player_var(player, "combo_max"))
	$VBoxContainer/RankLabelValue.text = get_rank(player)
	
	var clear = get_clear(player)
	$ClearLabel.text = clear[0]
	$ClearLabel.add_theme_color_override("font_color", clear[1])
	
	Global.set_player_var(player, "failed", false)

# EX score of a player with its rate
func get_score_text(player: int) -> String:
	return "EX Score: %d (%.2f%%)" % [Global.get_player_var(player, "ex_score"), Global.get_player_var(player, "score")]

# Rank letter of a player's score, one rank every 1/9 of the maximum EX score like in IIDX
func get_rank(player: int) -> String:
	var ranks = ["F", "F", "E", "D", "C", "B", "A", "AA", "AAA", "AAA"]
	# The small margin keeps exactly 8/9 in AAA despite the float rounding
	var ninths = int(Global.get_player_var(player, "score") * 9.0 / 100.0 + 0.000001)
	return ranks[clampi(ninths, 0, 9)]

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
	Global.set_player_var(player, "ex_score", 0)
	Global.set_player_var(player, "combo_max", 0)
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")
