extends ColorRect

# Player whose game options are shown (1 or 2)
@export var player : int = 1

func _ready() -> void:
	_on_game_option_settings_update("auto", Global.get_player_var(player, "auto_play"))
	
	_on_game_option_settings_update("ascratch", Global.get_player_var(player, "auto_scratch"))
	
	if Global.get_player_var(player, "keys_mode") == 5:
		_on_game_option_settings_update("five", true)
	
	if Global.get_player_var(player, "hispeed") != 1.0:
		_on_game_option_settings_update("hispeed", Global.get_player_var(player, "hispeed"))
	
	_on_game_option_settings_update("random", Global.get_player_var(player, "random"))
	
	_on_game_option_settings_update("double", Global.get_player_var(player, "double_play"))
	
	if Global.get_player_var(player, "gauge_level") != 0:
		_on_game_option_settings_update("difficulty", Global.get_player_var(player, "gauge_level"))

func _on_game_option_settings_update(option, status) -> void:
	if option in name and status:
		$AnimationPlayer.play("auto")
	elif option in name and not status:
		$AnimationPlayer.play("RESET")
	
	if name == "hispeedColorRect":
		if Global.get_player_var(player, "hispeed") == 1.0:
			$AnimationPlayer.play("RESET")
		$Label.text = str("HI-S   " + str(Global.get_player_var(player, "hispeed")))
	
	if name == "difficultyColorRect":
		if Global.get_player_var(player, "gauge_level") < 2:
			$Label.text = "EASY"
		elif Global.get_player_var(player, "gauge_level") == 2:
			$Label.text = "HARD"
	
	$AnimationPlayer.seek(0)
