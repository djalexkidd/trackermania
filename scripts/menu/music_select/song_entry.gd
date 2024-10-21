extends TextureButton

var song_name = ""
var difficulty = ""
var creator = ""
var path = ""

func _on_pressed() -> void:
	Loader.file_path = path
	if get_node("../../../../../..").name == "Main":
		get_node("../../../../../..").music_selected()
		get_node("../../../../..").queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/game/main.tscn")

func _on_focus_entered() -> void:
	$AnimationPlayer.play("open")

func _on_focus_exited() -> void:
	$AnimationPlayer.play("RESET")
