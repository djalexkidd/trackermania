extends Control

func _ready() -> void:
	$EngineLabel.text = "Godot Engine " + str(Engine.get_version_info().string)
	# Back to the default: player 1 only, player 2 has to press start in the music select
	Global.p1_joined = true
	Global.p2_joined = false

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
	get_tree().change_scene_to_file("res://scenes/netplay/lobby.tscn")

func _on_options_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/options.tscn")

# Full Screen
func _on_full_screen_texture_button_pressed() -> void:
	Global.fullscreen = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
	Global.apply_settings()
	Global.save_settings()

# Exit game
func _on_exit_texture_button_pressed() -> void:
	get_tree().quit()
