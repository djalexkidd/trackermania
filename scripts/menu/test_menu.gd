extends Control

func _ready() -> void:
	$EngineLabel.text = "Godot Engine " + str(Engine.get_version_info().string)

# Test Music
func _on_test_music_texture_button_pressed() -> void:
	Global.auto_play = true
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")

# Music Select
func _on_music_select_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")

# Controller Setup
func _on_controller_setup_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/test_controller.tscn")

# Full Screen
func _on_full_screen_texture_button_pressed() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# Exit game
func _on_exit_texture_button_pressed() -> void:
	get_tree().quit()
