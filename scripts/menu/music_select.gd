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
	
	# Analyse user folder for charts
	var json_files = get_all_files("user://songs", "json")
	
	# Loop through each JSON file
	for file_path in json_files:
		var json_data = load_json_file(file_path)
		
		var song_entry = preload("res://scenes/menu/music_select/song_entry.tscn").instantiate()
		$SongWheel/VBoxContainer.add_child(song_entry)
		song_entry.name = str(json_data["MapId"])
		song_entry.get_node("Label").text = json_data["Title"]

# Analyse files recursively by extention
func get_all_files(path: String, file_ext := "", files := []):
	var dir = DirAccess.open(path)

	if DirAccess.get_open_error() == OK:
		dir.list_dir_begin()

		var file_name = dir.get_next()

		while file_name != "":
			if dir.current_is_dir():
				files = get_all_files(dir.get_current_dir() +"/"+ file_name, file_ext, files)
			else:
				if file_ext and file_name.get_extension() != file_ext:
					file_name = dir.get_next()
					continue
				
				files.append(dir.get_current_dir() +"/"+ file_name)

			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access %s." % path)

	return files

# Load and parse JSON files
func load_json_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file:
		var file_contents = file.get_as_text()
		file.close()
		
		# Create an instance of JSON to parse the content
		var json_parser = JSON.new()
		var json_result = json_parser.parse(file_contents)
		
		if json_result == OK:
			return json_parser.data  # The parsed data is stored in 'data'
		else:
			print("Error parsing JSON in", file_path, ":", json_result)
	else:
		print("Failed to open file:", file_path)
	
	return {}

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
