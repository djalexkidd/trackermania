extends Control

const player_colors = [Color(0.305, 0.305, 0.305, 1.0), Color(0.0, 0.686, 1.0), Color(1.0, 0.157, 0.0)]
const ALPHABET_CATEGORIES = ["ABCD", "EFGH", "IJKL", "MNOP", "QRST", "UVWXYZ", "OTHERS"]

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
	# The effector stays as it was chosen, also from the game
	show_effector()
	
	for player in [1, 2]:
		var dj_name = Global.p1_name if player == 1 else Global.p2_name
		if dj_name != "":
			var box = get_node("BottomBar/P%dColorRect" % player)
			box.get_node("P%dLabel" % player).hide()
			box.get_node("P%dDJPrefixLabel/P%dNameLabel" % [player, player]).text = dj_name
			box.get_node("P%dDJPrefixLabel" % player).show()
	
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
	update_category_lamps()

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

# Function to load and add song entries, one per song with all its difficulties
func load_and_add_songs():
	var songs = await Loader.get_song_catalog()
	var groups := {}
	for song in songs:
		# Arcade: a song is played once, whatever its difficulty
		if Arcade.active and Arcade.is_played(song["path"]):
			continue
		# The charts of a folder are the difficulties of one song, a module makes its own
		var key = Arcade.song_key(song["path"])
		if not groups.has(key):
			groups[key] = []
		groups[key].append(song)
	var batch_start = Time.get_ticks_msec()
	for key in groups:
		# Small batches keep the loading screen animated
		if Time.get_ticks_msec() - batch_start >= 8:
			await get_tree().process_frame
			batch_start = Time.get_ticks_msec()
		add_song_entry(groups[key])

func add_song_entry(group: Array):
	var charts = group.map(func(song): return {
		"path": song["path"], "difficulty_name": song["DifficultyName"],
		"level": int(song["Difficulty"]), "notes": int(song["Notes"]),
	})
	sort_charts(charts)
	var title = group_title(group.map(func(song): return song["Title"]))
	var artist: String = group[0]["Artist"]
	for song in group:
		if song["Artist"].length() < artist.length():
			artist = song["Artist"]
	var file_path: String = charts[0]["path"]

	var file_type = "QUAVER"
	if file_path.get_extension().to_lower() == "mod":
		file_type = "MODULE"
	elif BmsChart.is_bms(file_path):
		file_type = "BMS"
	$SongWheel.get_node("Categories/" + file_type).show()
	var lists = ["AllMusic", "Official" if file_path.contains("official") else "Downloaded", alphabet_category(title), file_type]
	for category in lists:
		$SongWheel.get_node("Categories/" + category + "/MusicList").add_child(new_song_entry(title, artist, charts))

	# A level category only has the difficulties of its level
	var levels = []
	for chart in charts:
		if chart["level"] not in levels:
			levels.append(chart["level"])
	for level in levels:
		var level_path = "SongWheel/Categories/Level" + str(level)
		get_node(level_path).show()
		get_node(level_path + "/MusicList").add_child(new_song_entry(title, artist, charts.filter(func(chart): return chart["level"] == level)))

func new_song_entry(title: String, artist: String, charts: Array) -> Control:
	var song_entry = preload("res://scenes/menu/music_select/song_entry.tscn").instantiate()
	song_entry.setup(title, artist, charts)
	return song_entry

# IIDX order when every difficulty has an IIDX name, else by level then by number of notes
func sort_charts(charts: Array) -> void:
	var order = ["Beginner", "Normal", "Hyper", "Another", "Leggendaria"]
	var by_name = charts.all(func(chart): return chart["difficulty_name"] in order)
	charts.sort_custom(func(a, b):
		if by_name and a["difficulty_name"] != b["difficulty_name"]:
			return order.find(a["difficulty_name"]) < order.find(b["difficulty_name"])
		if a["level"] != b["level"]:
			return a["level"] < b["level"]
		if a["notes"] != b["notes"]:
			return a["notes"] < b["notes"]
		return a["difficulty_name"].naturalnocasecmp_to(b["difficulty_name"]) < 0)

# The charts of a BMS often add their difficulty to the title ("Song [SP ANOTHER]"): keep the common part
func group_title(titles: Array) -> String:
	var title: String = titles[0]
	if titles.size() == 1:
		return title
	for other in titles:
		var length = 0
		while length < mini(title.length(), other.length()) and title[length] == other[length]:
			length += 1
		title = title.left(length)
	for brackets in [["[", "]"], ["(", ")"]]:
		var open = title.rfind(brackets[0])
		if open >= 0 and title.find(brackets[1], open) < 0:
			title = title.left(open)
	title = title.strip_edges().trim_suffix("\u3000").strip_edges()
	return title if title != "" else titles[0]

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

# A category shows the worst lamp of its songs at their chosen difficulty like in IIDX, none while one is not played
func update_category_lamps() -> void:
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
		var category_lamp = category.get_node("Category").get_node_or_null("ClearLamp")
		if category_lamp != null:
			category_lamp.set_lamp(lamp)
		else:
			ClearLamp.attach(category.get_node("Category"), lamp)

func _process(delta):
	if songs_loading:
		return
	# Check if the effector button is pressed (shared by both players), held it turns the effector off
	if Effector.update_button(joined_players().map(func(player): return "p%d_effect" % player)):
		show_effector()
	
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
		if Input.is_action_just_pressed("p%d_vefx" % player) and $SongWheel.visible:
			change_difficulty()
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

# E3 (VEFX) like the SELECT button of IIDX: next difficulty of the song, kept for the other songs
func change_difficulty() -> void:
	var entry = $SongWheel.selected_song()
	if entry == null or not entry.next_difficulty():
		return
	for category in $SongWheel/Categories.get_children():
		for song in category.get_node("MusicList").get_children():
			if not song.is_random and song != entry:
				song.select_preferred()
	update_category_lamps()
	$SongWheel.refresh()

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

func show_effector():
	$BottomBar/Label.text = Effector.current_name().to_lower()

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
