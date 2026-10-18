extends ColorRect

signal update(option, status)

# Player owning this panel (1 or 2)
@export var player : int = 1

var key6_cycle = 0

func _ready():
	if get_opt("auto_play"):
		$AutoPlayLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
	
	if get_opt("keys_mode") == 5:
		$FiveKeysLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
		key6_cycle = 1
	
	if get_opt("hispeed") != 1.0:
		$HiSpeedLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
	
	if get_opt("random"):
		$RandomLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
	
	if get_opt("gauge_level") == 1:
		$EasyGaugeLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
	elif get_opt("gauge_level") == 2:
		$HardGaugeLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))

	if get_opt("auto_scratch"):
		$AutoScratchLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
		key6_cycle = 2
		
		if get_opt("keys_mode") == 5:
			key6_cycle = 3

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(key("key1")) and visible:
		set_opt("auto_play", !get_opt("auto_play"))
		if get_opt("auto_play"):
			$AutoPlayLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "auto", true)
		else:
			$AutoPlayLabel.remove_theme_color_override("font_color")
			emit_signal("update", "auto", false)
	
	if Input.is_action_just_pressed(key("key2")) and visible:
		set_opt("random", !get_opt("random"))
		if get_opt("random"):
			$RandomLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "random", true)
		else:
			$RandomLabel.remove_theme_color_override("font_color")
			emit_signal("update", "random", false)
	
	if Input.is_action_just_pressed(key("key4")) and visible:
		if get_opt("gauge_level") == 0:
			set_opt("gauge_level", 1)
			$EasyGaugeLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "difficulty", 1)
		elif get_opt("gauge_level") == 1:
			set_opt("gauge_level", 2)
			$EasyGaugeLabel.remove_theme_color_override("font_color")
			$HardGaugeLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "difficulty", 2)
		elif get_opt("gauge_level") == 2:
			set_opt("gauge_level", 0)
			$HardGaugeLabel.remove_theme_color_override("font_color")
			emit_signal("update", "difficulty", 0)
	
	if Input.is_action_just_pressed(key("key6")) and visible:
		key6_cycle += 1
		if key6_cycle == 4:
			key6_cycle = 0
		
		if key6_cycle == 0:
			set_opt("keys_mode", 7)
			$FiveKeysLabel.remove_theme_color_override("font_color")
			emit_signal("update", "five", false)
			
			set_opt("auto_scratch", false)
			$AutoScratchLabel.remove_theme_color_override("font_color")
			emit_signal("update", "ascratch", false)
		elif key6_cycle == 1 or key6_cycle == 3:
			set_opt("keys_mode", 5)
			$FiveKeysLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "five", true)
		elif key6_cycle == 2:
			set_opt("keys_mode", 7)
			$FiveKeysLabel.remove_theme_color_override("font_color")
			emit_signal("update", "five", false)
			
			set_opt("auto_scratch", true)
			$AutoScratchLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
			emit_signal("update", "ascratch", true)
	
	if Input.is_action_just_pressed(key("key7")) and visible:
		set_opt("hispeed", get_opt("hispeed") - 0.05)
		$HiSpeedLabel.add_theme_color_override("font_color", Color(1, 0.5, 0))
		
		if get_opt("hispeed") < 0.45:
			set_opt("hispeed", 1.0)
			$HiSpeedLabel.remove_theme_color_override("font_color")
		
		emit_signal("update", "hispeed", get_opt("hispeed"))

func get_opt(option : String):
	return Global.get_player_var(player, option)

func set_opt(option : String, value) -> void:
	Global.set_player_var(player, option, value)

# Input action of this player, "key1" -> "p1_key1"
func key(action : String) -> String:
	return "p%d_%s" % [player, action]
