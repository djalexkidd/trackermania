extends Control

# Audio stream player node to apply effects
@onready var audio_bus = AudioServer.get_bus_index("Master")  # Replace with your bus name

# To track which effect is currently active (0 = off, 1 = chorus, 2 = phaser, 3 = reverb)
var effect_state = 0

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

# Function to load and add song entries
func load_and_add_songs(folder_path: String):
	var json_files = Loader.get_all_files(folder_path, "json")
	for file_path in json_files:
		var json_data = Loader.load_json_file(file_path)
		
		var song_entry = preload("res://scenes/menu/music_select/song_entry.tscn").instantiate()
		$SongWheel/Categories/AllMusic/MusicList.add_child(song_entry)
		song_entry.path = file_path
		song_entry.get_node("Label").text = json_data["Title"]
		song_entry.get_node("Label2").text = str(json_data["Difficulty"])
		if json_data["DifficultyName"] == "Beginner":
			song_entry.get_node("Label2").add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		if json_data["DifficultyName"] == "Normal":
			song_entry.get_node("Label2").add_theme_color_override("font_color", Color(0.5, 0.5, 1))
		if json_data["DifficultyName"] == "Hyper":
			song_entry.get_node("Label2").add_theme_color_override("font_color", Color(1, 1, 0))
		if json_data["DifficultyName"] == "Another":
			song_entry.get_node("Label2").add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		
		var copied_node=song_entry.duplicate()
		
		if file_path.contains("official"):
			$SongWheel/Categories/Official/MusicList.add_child(copied_node)
			copied_node.path = file_path
		else:
			$SongWheel/Categories/Downloaded/MusicList.add_child(copied_node)
			copied_node.path = file_path
		
		copied_node=song_entry.duplicate()
		get_node("SongWheel/Categories/Level"+str(json_data["Difficulty"])).show()
		get_node("SongWheel/Categories/Level"+str(json_data["Difficulty"])+"/MusicList").add_child(copied_node)
		copied_node.path = file_path

func _process(delta):
	# Check if the effector button is pressed
	if Input.is_action_just_pressed("p1_effect"):
		_cycle_audio_effects()
	
	# Game Option Settings
	if Input.is_action_just_pressed("p1_start"):
		$SongWheel.hide()
		$GameOptionSettings.show()
		$GameOptionSettings/OpenAudio.play()
	
	if Input.is_action_just_released("p1_start"):
		$SongWheel.show()
		$GameOptionSettings.hide()
		$GameOptionSettings/CloseAudio.play()
	
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
