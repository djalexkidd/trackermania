extends TextureButton

var song_name = ""
var difficulty = ""
var difficulty_name = ""
var creator = ""
var path = ""

var color_map = {
	"Beginner": Color(0.3, 1, 0.3),
	"Normal": Color(0.5, 0.5, 1),
	"Hyper": Color(1, 1, 0),
	"Another": Color(1, 0.3, 0.3),
}

func _on_pressed() -> void:
	Loader.file_path = path
	if get_node("../../../../../..").name == "Main":
		get_node("../../../../../..").music_selected()
		get_node("../../../../..").queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/game/main.tscn")

func _on_focus_entered() -> void:
	$AnimationPlayer.play("open")
	get_node("/root/MusicSelect/SongInfo/SongName").text = song_name
	get_node("/root/MusicSelect/SongInfo/ArtistName").text = creator
	get_node("/root/MusicSelect/SongInfo/DifficultyName").text = difficulty_name
	if difficulty_name in color_map:
		get_node("/root/MusicSelect/SongInfo/DifficultyName").add_theme_color_override("font_color", color_map[difficulty_name])

func _on_focus_exited() -> void:
	$AnimationPlayer.play("RESET")
