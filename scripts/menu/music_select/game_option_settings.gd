extends ColorRect

signal update(option, status)

func _ready():
	pass

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("p1_key1") and visible:
		Global.auto_play = !Global.auto_play
		if Global.auto_play:
			$AutoPlayLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "auto", true)
		else:
			$AutoPlayLabel.remove_theme_color_override("font_color")
			emit_signal("update", "auto", false)
	
	if Input.is_action_just_pressed("p1_key6") and visible:
		if Global.keys_mode == 7:
			Global.keys_mode = 5
			$FiveKeysLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "five", true)
		else:
			Global.keys_mode = 7
			$FiveKeysLabel.remove_theme_color_override("font_color")
			emit_signal("update", "five", false)
