extends Control

var json_files = Loader.get_all_files("user://music_select_bgm", "ogg")

func _ready() -> void:
	if Global.custom_music_select_bgm == "":
		$OptionButton.selected = 0
	
	for item in json_files:
		$OptionButton.add_item(item)

func _on_option_button_item_selected(index: int) -> void:
	var selected_value = json_files[index-1]
	Global.custom_music_select_bgm = selected_value

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")
