extends Control

# Controller Setup
func _on_controller_setup_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/test_controller.tscn")

# Exit game
func _on_exit_texture_button_pressed() -> void:
	get_tree().quit()
