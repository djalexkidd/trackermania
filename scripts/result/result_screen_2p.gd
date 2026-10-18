extends "res://scripts/result/result_screen.gd"

func _ready() -> void:
	for player in [1, 2]:
		var panel = get_node("P%dResult" % player)
		var result = Global.get_versus_result(player)
		var clear = get_clear(player)
		
		panel.get_node("VersusLabel").text = result
		panel.get_node("VersusLabel").add_theme_color_override("font_color", Global.VERSUS_RESULT_COLORS[result])
		panel.get_node("ClearLabel").text = clear[0]
		panel.get_node("ClearLabel").add_theme_color_override("font_color", clear[1])
		panel.get_node("ScoreLabel").text = "Accuracy: " + str(Global.get_player_var(player, "score")) + "%"
		panel.get_node("ComboLabel").text = "Max combo: " + str(Global.get_player_var(player, "combo_max"))
		panel.get_node("RankLabelValue").text = get_rank(player)
	
	Global.failed = false
	Global.p2_failed = false

func _on_button_pressed() -> void:
	Global.score = 0
	Global.combo_max = 0
	Global.p2_score = 0
	Global.p2_combo_max = 0
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")
