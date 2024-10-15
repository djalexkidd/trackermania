extends Control

func _ready() -> void:
	$SysinfoContainer/EngineLabel.text = "Godot Engine " + str(Engine.get_version_info().string)

func _process(delta: float) -> void:
	$SysinfoContainer/FPSLabel.text = str(Engine.get_frames_per_second()) + " FPS"

# Music Select
func _on_music_select_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")

# Controller Setup
func _on_controller_setup_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/test_controller.tscn")

# Exit game
func _on_exit_texture_button_pressed() -> void:
	get_tree().quit()
