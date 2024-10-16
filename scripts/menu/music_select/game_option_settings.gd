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
		Global.five_keys_mode = !Global.five_keys_mode
		emit_signal("update", "five")
		if Global.five_keys_mode:
			$FiveKeysLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "five", true)
		else:
			$FiveKeysLabel.remove_theme_color_override("font_color")
			emit_signal("update", "five", false)
