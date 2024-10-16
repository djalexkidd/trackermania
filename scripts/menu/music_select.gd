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
