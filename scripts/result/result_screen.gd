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

# Rank letter of a player's score
func get_rank(player: int) -> String:
	return Scores.rank(Global.get_player_var(player, "score"))

# Clear lamp of a player as [text, color]
func get_clear(player: int) -> Array:
	var lamp = Scores.lamp(player)
	return [Scores.LAMPS[lamp], Scores.LAMP_COLORS[lamp]]

func _on_button_pressed() -> void:
	Global.set_player_var(player, "score", 0)
	Global.set_player_var(player, "ex_score", 0)
	Global.set_player_var(player, "combo_max", 0)
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")
