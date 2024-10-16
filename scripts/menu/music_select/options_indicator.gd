extends ColorRect

func _ready() -> void:
	_on_game_option_settings_update("auto", Global.auto_play)
	
	if Global.keys_mode == 5:
		_on_game_option_settings_update("five", true)

func _on_game_option_settings_update(option, status) -> void:
	if option in name and status:
		$AnimationPlayer.play("auto")
	elif option in name and not status:
		$AnimationPlayer.play("RESET")
	
	$AnimationPlayer.seek(0)
