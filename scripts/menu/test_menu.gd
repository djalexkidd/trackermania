extends Control

func _ready() -> void:
	$EngineLabel.text = "Godot Engine " + str(Engine.get_version_info().string)

# Music Select
func _on_music_select_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")

# Controller Setup
func _on_controller_setup_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/test_controller.tscn")

func _on_download_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/download.tscn")

func _on_custom_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/customization_menu.tscn")

func _on_netplay_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/netplay/scene/main.tscn")

# Full Screen
func _on_full_screen_texture_button_pressed() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# Exit game
func _on_exit_texture_button_pressed() -> void:
	get_tree().quit()
