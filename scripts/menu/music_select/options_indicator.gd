extends ColorRect

func _ready() -> void:
	_on_game_option_settings_update("auto", Global.auto_play)
	
	if Global.keys_mode == 5:
		_on_game_option_settings_update("five", true)
	
	if Global.hispeed != 1.0:
		_on_game_option_settings_update("hispeed", Global.hispeed)
	
	_on_game_option_settings_update("random", Global.random)
	
	if Global.gauge_level != 0:
		_on_game_option_settings_update("difficulty", Global.gauge_level)

func _on_game_option_settings_update(option, status) -> void:
	if option in name and status:
		$AnimationPlayer.play("auto")
	elif option in name and not status:
		$AnimationPlayer.play("RESET")
	
	if name == "hispeedColorRect":
		if Global.hispeed == 1.0:
			$AnimationPlayer.play("RESET")
		$Label.text = str("HI-S   " + str(Global.hispeed))
	
	if name == "difficultyColorRect":
		if Global.gauge_level < 2:
			$Label.text = "EASY"
		elif Global.gauge_level == 2:
			$Label.text = "HARD"
	
	$AnimationPlayer.seek(0)
