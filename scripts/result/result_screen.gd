extends Control

func _ready() -> void:
	$ScoreLabel.text = "Accuracy: " + str(Global.score) + "%"
	$ComboLabel.text = "Max combo: " + str(Global.combo_max)
	
	if Global.gauge_score < 80 and Global.gauge_level < 2 or Global.failed:
		$ClearLabel.text = "FAILED"
		$ClearLabel.add_theme_color_override("font_color", Color(1, 0.1, 0))
	else:
		if Global.gauge_level == 1:
			$ClearLabel.text = "EASY CLEAR"
			$ClearLabel.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	
		if Global.gauge_level == 2:
			$ClearLabel.text = "HARD CLEAR"
			$ClearLabel.add_theme_color_override("font_color", Color(1, 0.3, 0))
		
		if Global.combo_max == Global.combo_max_top:
			$ClearLabel.text = "FULL COMBO"
			$ClearLabel.add_theme_color_override("font_color", Color(1, 1, 0))
		
		if Global.score == 100:
			$ClearLabel.text = "PERFECT"
			$ClearLabel.add_theme_color_override("font_color", Color(1, 1, 1))
	
	Global.failed = false

func _on_button_pressed() -> void:
	Global.score = 0
	Global.combo_max = 0
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")
