extends TextureButton

var song_name = ""
var difficulty = ""
var difficulty_name = ""
var creator = ""
var path = ""
var is_random = false

var color_map = {
	"Beginner": Color(0.3, 1, 0.3),
	"Normal": Color(0.5, 0.5, 1),
	"Hyper": Color(1, 1, 0),
	"Another": Color(1, 0.3, 0.3),
	"Leggendaria": Color(0.8, 0.3, 1),
}

# Keep the moving title inside the ordinary song title area.
func setup_random_title() -> void:
	var title = $Label
	var clip = preload("res://scripts/menu/music_select/random_title.gd").new()
	clip.name = "RandomTitle"
	clip.position = title.position
	clip.size = Vector2(texture_normal.get_width() - title.position.x, title.size.y)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.font = title.get_theme_font("font")
	clip.font_size = title.get_theme_font_size("font_size")
	clip.font_color = title.get_theme_color("font_color")
	clip.outline_color = title.get_theme_color("font_outline_color")
	clip.outline_size = title.get_theme_constant("outline_size")
	remove_child(title)
	title.queue_free()
	add_child(clip)

func _on_pressed() -> void:
	if is_random:
		get_node("../../../..").play_random_song(self)
		return
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

# The random entry previews songs without their score
func update_song_info(show_score := true) -> void:
	var song_info = get_node("../../../../../SongInfo")
	song_info.get_node("SongName").text = song_name
	song_info.get_node("BestScore").visible = show_score
	if show_score:
		update_best_score(song_info.get_node("BestScore"))
	song_info.get_node("ArtistName").text = creator
	song_info.get_node("DifficultyName").text = difficulty_name
	song_info.get_node("DifficultyName").add_theme_color_override("font_color", color_map.get(difficulty_name, Color.WHITE))

# Best solo score of the chart
func update_best_score(best_score: Control) -> void:
	var best = Scores.get_best(path, difficulty_name)
	var lamp_label = best_score.get_node("Lamp")
	var score_label = best_score.get_node("Score")
	if best.is_empty():
		lamp_label.text = "NO PLAY"
		lamp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		score_label.text = ""
		return
	lamp_label.text = Scores.LAMPS[best["lamp"]]
	lamp_label.add_theme_color_override("font_color", Scores.LAMP_COLORS[best["lamp"]])
	score_label.text = "%s  EX %d (%.2f%%)" % [Scores.rank(best["rate"]), best["ex_score"], best["rate"]]

func _on_focus_exited() -> void:
	$AnimationPlayer.play("RESET")
