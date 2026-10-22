extends Control

const player_colors = [Color(0.305, 0.305, 0.305, 1.0), Color(0.0, 0.686, 1.0), Color(1.0, 0.157, 0.0)]
const ALPHABET_CATEGORIES = ["ABCD", "EFGH", "IJKL", "MNOP", "QRST", "UVWXYZ", "OTHERS"]

# Audio stream player node to apply effects
@onready var audio_bus = AudioServer.get_bus_index("Master")  # Replace with your bus name

# To track which effect is currently active (0 = off, 1 = chorus, 2 = phaser, 3 = reverb)
var effect_state = 0

# Opened from the netplay lobby: only P1 plays, the chosen song goes to the room
var netplay = false
var songs_loading = true
var song_preview: Node
# Arcade mode: TIME REMAIN, a song is picked when it runs out
var arcade_timer: Control

# Opening/closing of the game options: the wheel slides out to the right, then the panel slides in
const OPTIONS_SLIDE_TIME = 0.15
var wheel_x := 0.0
var wheel_tween: Tween
var options_x := {}
var options_tweens := {}

func _ready():
	# Ensure all effects are initially disabled
	AudioServer.set_bus_effect_enabled(audio_bus, 0, false)  # Chorus
	AudioServer.set_bus_effect_enabled(audio_bus, 1, false)  # Phaser
	AudioServer.set_bus_effect_enabled(audio_bus, 2, false)  # Reverb
	
	if Global.p1_name != "":
		$BottomBar/P1ColorRect/P1Label.hide()
		$BottomBar/P1ColorRect/P1DJPrefixLabel/P1NameLabel.text = Global.p1_name
		$BottomBar/P1ColorRect/P1DJPrefixLabel.show()
	
	netplay = Netplay.active
	if netplay:
		Global.p1_joined = true
		Global.p2_joined = false
		Netplay.closed.connect(_on_netplay_closed)
	update_joined(1)
	update_joined(2)
	if Arcade.active:
		arcade_timer = preload("res://scripts/arcade/arcade_timer.gd").new()
		arcade_timer.caption = Arcade.current_stage_name()
		arcade_timer.time_left = Arcade.SELECT_TIME
		arcade_timer.timeout.connect(_on_arcade_timeout)
		add_child(arcade_timer)
		move_child(arcade_timer, $TextureRect.get_index() + 1)
	
	# NOW LOADING screen over everything until the wheel is built
	var loading_screen = preload("res://scripts/menu/loading_screen.gd").new()
	add_child(loading_screen)

	if Global.custom_music_select_bgm != "":
		$AudioStreamPlayer.stream = AudioStreamOggVorbis.load_from_file(Global.custom_music_select_bgm)

	song_preview = preload("res://scripts/menu/music_select/song_preview.gd").new()
	song_preview.bgm = $AudioStreamPlayer
	add_child(song_preview)
	wheel_x = $SongWheel.position.x
	for player in [1, 2]:
		options_x[player] = game_options(player).position.x
	$SongWheel.hide()
	# Draw the loading screen before the work starts
	await get_tree().process_frame
	await load_and_add_songs()
	# Arcade: every song was already played, the game ends there
	if Arcade.active and not Arcade.stages.is_empty() and $SongWheel/Categories/AllMusic/MusicList.get_child_count() == 0:
		get_tree().change_scene_to_file("res://scenes/arcade/name_entry.tscn")
		return
	sort_alphabet_categories()
	add_random_entries()
	add_category_lamps()

	# Built behind the loading screen, out of the screen on the right
	var target_position = $SongWheel.position
	$SongWheel.position.x = size.x + 50
	$SongWheel.show()
	$SongWheel.setup()
	await loading_screen.finish()
	$AudioStreamPlayer.play()
	songs_loading = false
	if arcade_timer:
		arcade_timer.start(Arcade.SELECT_TIME)

	# Slide animation for song wheel, while the loading screen leaves

	wheel_tween = create_tween()
	wheel_tween.tween_property($SongWheel, "position", target_position, 0.6)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

# Function to load and add song entries
func load_and_add_songs():
	var songs = await Loader.get_song_catalog()
	var batch_start = Time.get_ticks_msec()
	for song in songs:
		# Arcade: a song is played once, whatever its difficulty
		if Arcade.active and Arcade.is_played(song["path"]):
			continue
		# Small batches keep the loading screen animated
		if Time.get_ticks_msec() - batch_start >= 8:
			await get_tree().process_frame
			batch_start = Time.get_ticks_msec()
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
		"Leggendaria": Color(0.8, 0.3, 1),
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

	var file_type = "QUAVER"
	if file_path.get_extension().to_lower() == "mod":
		file_type = "MODULE"
	elif BmsChart.is_bms(file_path):
		file_type = "BMS"
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
			# The arcade mode is played alone
			if Arcade.active and not is_joined(player):
				continue
			if not is_joined(player):
				set_joined(player, true)
			else:
				open_game_options(player)
		
		if Input.is_action_just_released(prefix + "start") and game_options(player).open:
			close_game_options(player)
		
		if Input.is_action_just_pressed(prefix + "meta") and is_joined(player) and not netplay and can_leave():
			if game_options(player).open:
				close_game_options(player)
			set_joined(player, false)
			return
	
	var navigating_players = joined_players().filter(func(player): return not game_options(player).open)
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
				if not $SongWheel.visible or $SongWheel.close_category() or not can_leave():
					return
				leave()
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
		leave()

# Arcade: the game can only be given up before the 1st stage
func can_leave() -> bool:
	return not Arcade.active or Arcade.stages.is_empty()

# Back to the title menu, or to the netplay lobby
func leave() -> void:
	Arcade.stop()
	get_tree().change_scene_to_file("res://scenes/netplay/lobby.tscn" if netplay else "res://scenes/menu/main_menu.tscn")

# The room was closed while choosing, the lobby tells why
func _on_netplay_closed(_reason: String) -> void:
	leave()

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
	var panel = game_options(player)
	panel.open = true
	panel.get_node("OpenAudio").play()
	var tween = options_tween(player)
	# P1: the wheel leaves to the right first
	if player == 1 and $SongWheel.visible:
		if wheel_tween:
			wheel_tween.kill()
		tween.tween_property($SongWheel, "position:x", size.x, OPTIONS_SLIDE_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback($SongWheel.hide)
	if not panel.visible:
		panel.position.x = options_hidden_x(player)
		panel.show()
	tween.tween_property(panel, "position:x", options_x[player], OPTIONS_SLIDE_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# P2: the panel covers the song info
	if player == 2:
		tween.tween_callback($SongInfo.hide)

func close_game_options(player: int) -> void:
	var panel = game_options(player)
	panel.open = false
	panel.get_node("CloseAudio").play()
	var tween = options_tween(player)
	if player == 2:
		$SongInfo.show()
	tween.tween_property(panel, "position:x", options_hidden_x(player), OPTIONS_SLIDE_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(panel.hide)
	# P1: then the wheel comes back
	if player == 1 and not songs_loading:
		tween.tween_callback(func():
			if not $SongWheel.visible:
				$SongWheel.position.x = size.x
				$SongWheel.show()
			$SongWheel.grab_focus())
		tween.tween_property($SongWheel, "position:x", wheel_x, OPTIONS_SLIDE_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# Out of the screen: P1 panel on the right, P2 panel on the left
func options_hidden_x(player: int) -> float:
	return size.x if player == 1 else -game_options(player).size.x

# A new slide replaces the one running, from where it stopped
func options_tween(player: int) -> Tween:
	if options_tweens.has(player):
		options_tweens[player].kill()
	options_tweens[player] = create_tween()
	return options_tweens[player]

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

# Time is up: the song under the cursor, or a random song from a category
func _on_arcade_timeout() -> void:
	var wheel = $SongWheel
	var entry = wheel.entries[wheel.selected_index] if wheel.opened_category != null and wheel.selected_index > 0 else null
	if entry != null and not entry.is_random:
		entry._on_pressed()
		return
	var category = entry.get_parent() if entry != null else $SongWheel/Categories/AllMusic/MusicList
	var songs = category.get_children().filter(func(song): return not song.is_random)
	if songs.is_empty():
		songs = $SongWheel/Categories/AllMusic/MusicList.get_children().filter(func(song): return not song.is_random)
	if songs.is_empty():
		leave()
		return
	songs.pick_random()._on_pressed()

func _on_song_entry_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")
