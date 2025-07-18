extends Control

# Audio stream player node to apply effects
@onready var audio_bus = AudioServer.get_bus_index("Master")  # Replace with your bus name

# To track which effect is currently active (0 = off, 1 = chorus, 2 = phaser, 3 = reverb)
var effect_state = 0

var node_focused = ""

func _ready():
	# Ensure all effects are initially disabled
	AudioServer.set_bus_effect_enabled(audio_bus, 0, false)  # Chorus
	AudioServer.set_bus_effect_enabled(audio_bus, 1, false)  # Phaser
	AudioServer.set_bus_effect_enabled(audio_bus, 2, false)  # Reverb
	
	if Global.p1_name != "":
		$BottomBar/P1ColorRect/P1Label.hide()
		$BottomBar/P1ColorRect/P1DJPrefixLabel/P1NameLabel.text = Global.p1_name
		$BottomBar/P1ColorRect/P1DJPrefixLabel.show()
	
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
		var difficulty = int(json_data["Difficulty"])
		var difficulty_name = json_data["DifficultyName"]
		var title = json_data["Title"]
		var artist = json_data["Artist"]

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
	# Check if the effector button is pressed
	if Input.is_action_just_pressed("p1_effect"):
		_cycle_audio_effects()
	
	# Game Option Settings
	if Input.is_action_just_pressed("p1_start"):
		node_focused = get_viewport().gui_get_focus_owner()
		$SongWheel.hide()
		$GameOptionSettings.show()
		$GameOptionSettings/OpenAudio.play()
	
	if Input.is_action_just_released("p1_start"):
		node_focused.grab_focus()
		$SongWheel.show()
		$GameOptionSettings.hide()
		$GameOptionSettings/CloseAudio.play()
	
	for key in ["p1_key1", "p1_key3", "p1_key5", "p1_key7"]:
		if Input.is_action_just_pressed(key) and !$GameOptionSettings.visible:
			get_viewport().gui_get_focus_owner()._on_pressed()
			break
	
	# Exit button
	for key in ["p1_key2", "p1_key4", "p1_key6"]:
		if Input.is_action_just_pressed(key) and !$GameOptionSettings.visible:
			get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")
			break

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
