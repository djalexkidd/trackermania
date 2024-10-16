extends ColorRect

func _on_game_option_settings_update(option, status) -> void:
	if option in name and status:
		$AnimationPlayer.play("auto")
	elif option in name and not status:
		$AnimationPlayer.play("RESET")
