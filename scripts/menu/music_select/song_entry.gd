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
	Loader.chart_difficulty = difficulty_name
	if get_node("../../../../../..").name == "Main":
		get_node("../../../../../..").music_selected()
		get_node("../../../../..").queue_free()
	elif Global.p1_joined and Global.p2_joined:
		get_tree().change_scene_to_file("res://scenes/game/main_2p.tscn")
	elif Global.p2_joined:
		get_tree().change_scene_to_file("res://scenes/game/main_p2.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/game/main.tscn")

func _on_focus_entered() -> void:
	$AnimationPlayer.play("open")
	update_song_info()

func update_song_info() -> void:
	var song_info = get_node("../../../../../SongInfo")
	song_info.get_node("SongName").text = song_name
	song_info.get_node("ArtistName").text = creator
	song_info.get_node("DifficultyName").text = difficulty_name
	if difficulty_name in color_map:
		song_info.get_node("DifficultyName").add_theme_color_override("font_color", color_map[difficulty_name])

func _on_focus_exited() -> void:
	$AnimationPlayer.play("RESET")
