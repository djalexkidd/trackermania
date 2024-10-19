extends ColorRect

signal update(option, status)

func _ready():
	if Global.auto_play:
		$AutoPlayLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
	
	if Global.keys_mode == 5:
		$FiveKeysLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
	
	if Global.hispeed != 1.0:
		$HiSpeedLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
	
	if Global.random:
		$RandomLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
	
	if Global.gauge_level == 1:
		$EasyGaugeLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
	elif Global.gauge_level == 2:
		$HardGaugeLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("p1_key1") and visible:
		Global.auto_play = !Global.auto_play
		if Global.auto_play:
			$AutoPlayLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "auto", true)
		else:
			$AutoPlayLabel.remove_theme_color_override("font_color")
			emit_signal("update", "auto", false)
	
	if Input.is_action_just_pressed("p1_key2") and visible:
		Global.random = !Global.random
		if Global.random:
			$RandomLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "random", true)
		else:
			$RandomLabel.remove_theme_color_override("font_color")
			emit_signal("update", "random", false)
	
	if Input.is_action_just_pressed("p1_key4") and visible:
		if Global.gauge_level == 0:
			Global.gauge_level = 1
			$EasyGaugeLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "difficulty", 1)
		elif Global.gauge_level == 1:
			Global.gauge_level = 2
			$EasyGaugeLabel.remove_theme_color_override("font_color")
			$HardGaugeLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "difficulty", 2)
		elif Global.gauge_level == 2:
			Global.gauge_level = 0
			$HardGaugeLabel.remove_theme_color_override("font_color")
			emit_signal("update", "difficulty", 0)
	
	if Input.is_action_just_pressed("p1_key6") and visible:
		if Global.keys_mode == 7:
			Global.keys_mode = 5
			$FiveKeysLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "five", true)
		else:
			Global.keys_mode = 7
			$FiveKeysLabel.remove_theme_color_override("font_color")
			emit_signal("update", "five", false)
	
	if Input.is_action_just_pressed("p1_key7") and visible:
		Global.hispeed -= 0.05
		$HiSpeedLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
		
		if Global.hispeed < 0.45:
			Global.hispeed = 1.0
			$HiSpeedLabel.remove_theme_color_override("font_color")
		
		emit_signal("update", "hispeed", Global.hispeed)
