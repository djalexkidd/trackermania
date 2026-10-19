extends Control

const player_colors = [Color(0.305, 0.305, 0.305, 1.0), Color(0.0, 0.686, 1.0), Color(1.0, 0.157, 0.0)]

# Audio stream player node to apply effects
@onready var audio_bus = AudioServer.get_bus_index("Master")  # Replace with your bus name

# To track which effect is currently active (0 = off, 1 = chorus, 2 = phaser, 3 = reverb)
var effect_state = 0

var node_focused = ""

# Players can't join or leave when the music select is opened from netplay
var netplay = false

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
	
	# Analyse game and user folders for charts
	load_and_add_songs("user://songs")
	
	if Global.custom_music_select_bgm != "":
		$AudioStreamPlayer.stream = AudioStreamOggVorbis.load_from_file(Global.custom_music_select_bgm)
	
	$AudioStreamPlayer.play()
	
	$SongWheel/Categories/AllMusic/Category.grab_focus()
	
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
func load_and_add_songs(folder_path: String):
	var json_files = Loader.get_all_files(folder_path, "json")
	for file_path in json_files:
		var json_data = Loader.load_json_file(file_path)
		add_song_entry(file_path, json_data["Title"], json_data["Artist"], int(json_data["Difficulty"]), json_data["DifficultyName"])
	
	# Amiga modules are charts too, one entry per generated difficulty (not in netplay)
	if netplay:
		return
	var mod_files = Loader.get_all_files(folder_path, "mod") + Loader.get_all_files(folder_path, "MOD")
	for file_path in mod_files:
		var module = ModModule.load_file(file_path)
		if module == null:
			continue
		var title = module.title if module.title != "" else file_path.get_file().get_basename()
		for difficulty_name in ModChart.DIFFICULTIES:
			var chart = ModChart.new(module, difficulty_name)
			add_song_entry(file_path, title, "Amiga module", chart.level, difficulty_name)

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

func _process(delta):
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
	
	for player in joined_players():
		if game_options(player).visible:
			continue
		
		for key in ["key1", "key3", "key5", "key7"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, key]):
				get_viewport().gui_get_focus_owner()._on_pressed()
				return
		
		# Exit button
		for key in ["key2", "key4", "key6"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, key]):
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
		node_focused = get_viewport().gui_get_focus_owner()
		$SongWheel.hide()
	else:
		$SongInfo.hide()
	game_options(player).show()
	game_options(player).get_node("OpenAudio").play()

func close_game_options(player: int) -> void:
	if player == 1:
		node_focused.grab_focus()
		$SongWheel.show()
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
