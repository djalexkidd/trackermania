extends TextureButton

var song_name = ""
var difficulty = ""
var creator = ""
var path = ""

func _on_pressed() -> void:
	Loader.file_path = path
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")
