extends Button

class_name RemapButton

@export var action: String

var config_file_path: String = "user://mappings.cfg"

var config_file: ConfigFile

func _init():
	toggle_mode = true
	theme_type_variation = "RemapButton"
	config_file = ConfigFile.new()

func _ready():
	set_process_unhandled_input(false)
	load_key_mapping()
	update_key_text()

func _toggled(button_pressed):
	set_process_unhandled_input(button_pressed)
	if button_pressed:
		text = "... Awaiting Input ..."
		release_focus()
	else:
		update_key_text()
		grab_focus()

func _unhandled_input(event):
	if event.pressed:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)
		save_key_mapping(event)
		button_pressed = false

func update_key_text():
	text = "%s" % InputMap.action_get_events(action)[0].as_text()

# Save the remapped key to the config file
func save_key_mapping(event):
	config_file.load(config_file_path)
	var event_str = ""
	if event is InputEventKey:
		event_str = event.as_text()  # Save key as text
	elif event is InputEventJoypadButton:
		event_str = "Button:%d" % event.button_index  # Save gamepad button index
	config_file.set_value("input", action, event_str)
	config_file.save(config_file_path)

# Load the key mapping from the config file
func load_key_mapping():
	if config_file.load(config_file_path) == OK:
		var saved_key = config_file.get_value("input", action)
		if saved_key != "":
			# Try to load the event either as a key or as a gamepad button
			var input_event
			if saved_key.begins_with("Button"):
				# Handle gamepad button input
				input_event = InputEventJoypadButton.new()
				input_event.button_index = int(saved_key.substr(saved_key.find(":") + 1)) # Parse button index from saved string
			else:
				# Handle keyboard input
				input_event = InputEventKey.new()
				input_event.keycode = OS.find_keycode_from_string(saved_key)
			
			# Erase existing action events and add the loaded event
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, input_event)
