extends ColorRect

func _ready():
	pass

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("p1_key1") and visible:
		Global.auto_play = !Global.auto_play
		if Global.auto_play:
			$AutoPlayLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
		else:
			$AutoPlayLabel.remove_theme_color_override("font_color")
