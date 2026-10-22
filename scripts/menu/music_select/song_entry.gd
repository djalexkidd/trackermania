extends TextureButton

var song_name = ""
var creator = ""
# Difficulties of the song, easiest first: {path, difficulty_name, level, notes, double}
var all_charts: Array = []
# Difficulties of the style played (single play or DOUBLE PLAY), empty when the song has none
var charts: Array = []
var chart_index = 0
# Chart shown and played, charts[chart_index]
var path = ""
var difficulty_name = ""
var is_random = false

const COLORS = {
	"Beginner": Color(0.3, 1, 0.3),
	"Normal": Color(0.5, 0.5, 1),
	"Hyper": Color(1, 1, 0),
	"Another": Color(1, 0.3, 0.3),
	"Leggendaria": Color(0.8, 0.3, 1),
}

# Free difficulty names go from green to red with the level
static func difficulty_color(name: String, level: int) -> Color:
	if COLORS.has(name):
		return COLORS[name]
	return Color.from_hsv(lerpf(0.33, 0.0, (level - 1) / 7.0), 0.55, 1.0)

func setup(title: String, artist: String, song_charts: Array) -> void:
	song_name = title
	creator = artist
	all_charts = song_charts
	$Label.text = title
	ClearLamp.attach(self, -1)
	apply_style()

# Keep the difficulties of the style played, a song without them is hidden from the wheel
func apply_style() -> void:
	var double = Global.is_double_play()
	charts = all_charts.filter(func(chart): return chart["double"] == double)
	if not charts.is_empty():
		select_preferred()

func available() -> bool:
	return is_random or not charts.is_empty()

# The difficulty chosen with E3 is kept from song to song like in IIDX: the same name, else the same place
func select_preferred() -> void:
	var index = -1
	for i in charts.size():
		if charts[i]["difficulty_name"] == Loader.chart_difficulty and (index < 0 or absi(i - Loader.difficulty_slot) < absi(index - Loader.difficulty_slot)):
			index = i
	if index < 0:
		index = mini(Loader.difficulty_slot, charts.size() - 1)
	select_chart(index)

func select_chart(index: int) -> void:
	chart_index = index
	path = charts[index]["path"]
	difficulty_name = charts[index]["difficulty_name"]
	$Label2.text = str(charts[index]["level"])
	$Label2.add_theme_color_override("font_color", chart_color(index))
	$ClearLamp.set_lamp(chart_lamp(index))

# E3: the next difficulty of the song, then of the other songs
func next_difficulty() -> bool:
	if charts.size() < 2:
		return false
	select_chart((chart_index + 1) % charts.size())
	Loader.chart_difficulty = difficulty_name
	Loader.difficulty_slot = chart_index
	return true

func chart_color(index: int) -> Color:
	return difficulty_color(charts[index]["difficulty_name"], charts[index]["level"])

func chart_lamp(index: int) -> int:
	return Scores.get_best(charts[index]["path"], charts[index]["difficulty_name"], charts[index]["double"]).get("lamp", -1)

# The same preview for every difficulty and style: changing it does not restart the song
func preview_path() -> String:
	return all_charts[0]["path"]

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
	Loader.difficulty_slot = chart_index
	if Netplay.active:
		# The host picks the song of the room, the others suggest it in the chat
		if Netplay.is_host:
			Netplay.choose_song(path, difficulty_name, song_name, creator, int($Label2.text))
		else:
			Netplay.suggest_song(song_name, difficulty_name)
		get_tree().change_scene_to_file("res://scenes/netplay/lobby.tscn")
	else:
		# One scene for 1P, 2P and versus, main.gd picks the playing sides from Global
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
	song_info.get_node("Difficulties").show_entry(self)

# Best solo score of the chart
func update_best_score(best_score: Control) -> void:
	var best = Scores.get_best(path, difficulty_name, charts[chart_index]["double"])
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
