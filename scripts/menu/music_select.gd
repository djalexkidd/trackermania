extends Control

const player_colors = [Color(0.305, 0.305, 0.305, 1.0), Color(0.0, 0.686, 1.0), Color(1.0, 0.157, 0.0)]
const ALPHABET_CATEGORIES = ["ABCD", "EFGH", "IJKL", "MNOP", "QRST", "UVWXYZ", "OTHERS"]

# Audio stream player node to apply effects
@onready var audio_bus = AudioServer.get_bus_index("Master")  # Replace with your bus name

# To track which effect is currently active (0 = off, 1 = chorus, 2 = phaser, 3 = reverb)
var effect_state = 0

# Players can't join or leave when the music select is opened from netplay
var netplay = false
var songs_loading = true

func _ready():
	# Ensure all effects are initially disabled
	AudioServer.set_bus_effect_enabled(audio_bus, 0, false)  # Chorus
	AudioServer.set_bus_effect_enabled(audio_bus, 1, false)  # Phaser
	AudioServer.set_bus_effect_enabled(audio_bus, 2, false)  # Reverb
	
	if Global.p1_name != "":
		$BottomBar/P1ColorRect/P1Label.hide()
		$BottomBar/P1ColorRect/P1DJPrefixLabel/P1NameLabel.text = Global.p1_name
		$BottomBar/P1ColorRect/P1DJPrefixLabel.show()
	
	netplay = get_tree().current_scene != self
	if not netplay:
		update_joined(1)
		update_joined(2)
	
	if Global.custom_music_select_bgm != "":
		$AudioStreamPlayer.stream = AudioStreamOggVorbis.load_from_file(Global.custom_music_select_bgm)
	
	$AudioStreamPlayer.play()
	$SongWheel.hide()
	$SongInfo/SongName.text = "Loading songs…"
	await load_and_add_songs()
	sort_alphabet_categories()
	add_random_entries()
	add_category_lamps()
	$SongInfo/SongName.text = ""
	
	$SongWheel.show()
	$SongWheel.setup()
	songs_loading = false
	
	# Slide animation for song wheel
	var screen_size = get_viewport().size
	var target_position = $SongWheel.position

	# Slide container to right
	$SongWheel.position.x = screen_size.x + 50

	var tween = create_tween()
	tween.tween_property($SongWheel, "position", target_position, 0.6)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

# Function to load and add song entries
func load_and_add_songs():
	var songs = await Loader.get_song_catalog()
	for song in songs:
		if netplay and song["path"].get_extension().to_lower() == "mod":
			continue
		add_song_entry(song["path"], song["Title"], song["Artist"], int(song["Difficulty"]), song["DifficultyName"])

func add_song_entry(file_path: String, title: String, artist: String, difficulty: int, difficulty_name: String):
	var song_entry = preload("res://scenes/menu/music_select/song_entry.tscn").instantiate()
	song_entry.path = file_path
	song_entry.song_name = title
	song_entry.creator = artist
	song_entry.difficulty_name = difficulty_name
	song_entry.get_node("Label").text = title
	song_entry.get_node("Label2").text = str(difficulty)

	var label2 = song_entry.get_node("Label2")
	var color_map = {
		"Beginner": Color(0.3, 1, 0.3),
		"Normal": Color(0.5, 0.5, 1),
		"Hyper": Color(1, 1, 0),
		"Another": Color(1, 0.3, 0.3),
	}
	if difficulty_name in color_map:
		label2.add_theme_color_override("font_color", color_map[difficulty_name])
	ClearLamp.attach(song_entry, Scores.get_best(file_path, difficulty_name).get("lamp", -1))

	$SongWheel/Categories/AllMusic/MusicList.add_child(song_entry)

	for category in ["Official", "Downloaded"]:
		if (category == "Official" and file_path.contains("official")) or (category == "Downloaded" and not file_path.contains("official")):
			var copied_node = song_entry.duplicate()
			copied_node.path = file_path
			copied_node.song_name = title
			copied_node.creator = artist
			copied_node.difficulty_name = difficulty_name
			$SongWheel.get_node("Categories/" + category + "/MusicList").add_child(copied_node)

	var level_path = "SongWheel/Categories/Level" + str(difficulty)
	get_node(level_path).show()
	var copied_node = song_entry.duplicate()
	copied_node.path = file_path
	copied_node.song_name = title
	copied_node.creator = artist
	copied_node.difficulty_name = difficulty_name
	get_node(level_path + "/MusicList").add_child(copied_node)

	var alphabet_entry = song_entry.duplicate()
	alphabet_entry.path = file_path
	alphabet_entry.song_name = title
	alphabet_entry.creator = artist
	alphabet_entry.difficulty_name = difficulty_name
	$SongWheel.get_node("Categories/" + alphabet_category(title) + "/MusicList").add_child(alphabet_entry)

	var file_type = "MODULE" if file_path.get_extension().to_lower() == "mod" else "QUAVER"
	var file_type_category = $SongWheel.get_node("Categories/" + file_type)
	file_type_category.show()
	var file_type_entry = song_entry.duplicate()
	file_type_entry.path = file_path
	file_type_entry.song_name = title
	file_type_entry.creator = artist
	file_type_entry.difficulty_name = difficulty_name
	file_type_category.get_node("MusicList").add_child(file_type_entry)

func alphabet_category(title: String) -> String:
	var initial = title.left(1).to_upper()
	for category in ALPHABET_CATEGORIES:
		if category != "OTHERS" and initial != "" and category.contains(initial):
			return category
	return "OTHERS"

func sort_alphabet_categories() -> void:
	for category in ALPHABET_CATEGORIES:
		var music_list = $SongWheel.get_node("Categories/" + category + "/MusicList")
		var songs = music_list.get_children()
		songs.sort_custom(func(a, b): return a.song_name.nocasecmp_to(b.song_name) < 0)
		for index in songs.size():
			music_list.move_child(songs[index], index)

func add_random_entries() -> void:
	for category in $SongWheel/Categories.get_children():
		var music_list = category.get_node("MusicList")
		var entry = preload("res://scenes/menu/music_select/song_entry.tscn").instantiate()
		entry.is_random = true
		entry.song_name = "Musique aléatoire"
		entry.difficulty_name = "?"
		entry.get_node("Label2").text = "?"
		music_list.add_child(entry)
		music_list.move_child(entry, 0)
		entry.setup_random_title()

# A category shows the worst lamp of its songs like in IIDX, none while one is not played
func add_category_lamps() -> void:
	for category in $SongWheel/Categories.get_children():
		var lamp = -1
		for song in category.get_node("MusicList").get_children():
			if song.is_random:
				continue
			var song_lamp = song.get_node("ClearLamp").lamp
			if song_lamp < 0:
				lamp = -1
				break
			lamp = song_lamp if lamp < 0 else mini(lamp, song_lamp)
		ClearLamp.attach(category.get_node("Category"), lamp)

func _process(delta):
	if songs_loading:
		return
	# Check if the effector button is pressed (shared by both players)
	for player in joined_players():
		if Input.is_action_just_pressed("p%d_effect" % player):
			_cycle_audio_effects()
			break
	
	# START joins, then hold it for the game options. META leaves.
	for player in [1, 2]:
		if netplay and player == 2:
			continue
		var prefix = "p%d_" % player
		if Input.is_action_just_pressed(prefix + "start"):
			if not is_joined(player):
				set_joined(player, true)
			else:
				open_game_options(player)
		
		if Input.is_action_just_released(prefix + "start") and game_options(player).visible:
			close_game_options(player)
		
		if Input.is_action_just_pressed(prefix + "meta") and is_joined(player) and not netplay:
			if game_options(player).visible:
				close_game_options(player)
			set_joined(player, false)
			return
	
	var navigating_players = joined_players().filter(func(player): return not game_options(player).visible)
	# P1's panel covers the wheel and temporarily suspends navigation for both players.
	$SongWheel.poll_navigation(delta, navigating_players if $SongWheel.visible else [])
	for player in navigating_players:
		for key in ["key1", "key3", "key5", "key7"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, key]):
				if $SongWheel.visible:
					$SongWheel._on_pressed()
				return
		
		# Black keys first return to the categories, then leave music select.
		for key in ["key2", "key4", "key6"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, key]):
				if not $SongWheel.visible or $SongWheel.close_category():
					return
				get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")
				return

func is_joined(player: int) -> bool:
	return Global.get("p%d_joined" % player)

func joined_players() -> Array:
	return [1, 2].filter(is_joined)

func set_joined(player: int, joined: bool) -> void:
	Global.set("p%d_joined" % player, joined)
	update_joined(player)
	# Nobody left, back to the title menu
	if joined_players().is_empty():
		get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")

# Show the player's game options bar, or "PRESS START BUTTON" when the player is out
func update_joined(player: int) -> void:
	get_node("BottomBar/P%dGameOptions" % player).visible = is_joined(player)
	get_node("BottomBar/P%dPressStart" % player).visible = not is_joined(player)
	if is_joined(player):
		get_node("BottomBar/P%dColorRect" % player).color = player_colors[player]
	else:
		get_node("BottomBar/P%dColorRect" % player).color = player_colors[0]

# P1 options panel goes over the song wheel, P2 options panel over the song info
func game_options(player: int) -> Control:
	return $GameOptionSettings if player == 1 else $GameOptionSettingsP2

func open_game_options(player: int) -> void:
	if player == 1:
		$SongWheel.hide()
	else:
		$SongInfo.hide()
	game_options(player).show()
	game_options(player).get_node("OpenAudio").play()

func close_game_options(player: int) -> void:
	if player == 1:
		$SongWheel.show()
		$SongWheel.grab_focus()
	else:
		$SongInfo.show()
	game_options(player).hide()
	game_options(player).get_node("CloseAudio").play()

func _cycle_audio_effects():
	# Disable all effects before cycling to the next one
	AudioServer.set_bus_effect_enabled(audio_bus, 0, false)  # Disable Chorus
	AudioServer.set_bus_effect_enabled(audio_bus, 1, false)  # Disable Phaser
	AudioServer.set_bus_effect_enabled(audio_bus, 2, false)  # Disable Reverb
	
	# Cycle through the effects: off -> chorus -> phaser -> reverb -> off (loop)
	effect_state = (effect_state + 1) % 4  # Cycle through 0 to 3
	
	match effect_state:
		1:
			# Enable Chorus
			AudioServer.set_bus_effect_enabled(audio_bus, 0, true)
			$BottomBar/Label.text = "chorus"
		2:
			# Enable Phaser
			AudioServer.set_bus_effect_enabled(audio_bus, 1, true)
			$BottomBar/Label.text = "phaser"
		3:
			# Enable Reverb
			AudioServer.set_bus_effect_enabled(audio_bus, 2, true)
			$BottomBar/Label.text = "reverb"
		_:
			# All effects are off (default state)
			$BottomBar/Label.text = "effector off"

func _on_song_entry_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")
