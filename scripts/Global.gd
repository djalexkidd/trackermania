extends Node

var score = 0
var combo_max = 0
var combo_max_top = 0
var failed = false
var gauge_score = 0

var gauge_level = 0
var keys_mode = 7
var hispeed = 1.0
var auto_play = false
var auto_scratch = false
var random = false

# Players in game on this machine (START joins, META leaves in the music select)
var p1_joined = true
var p2_joined = false

var p2_score = 0
var p2_combo_max = 0
var p2_combo_max_top = 0
var p2_failed = false
var p2_gauge_score = 0

var p2_gauge_level = 0
var p2_keys_mode = 7
var p2_hispeed = 1.0
var p2_auto_play = false
var p2_auto_scratch = false
var p2_random = false

var p1_name = ""
var p2_name = ""

var custom_music_select_bgm = ""
# Show the timing error in ms under the judgement (Customization menu)
var show_timing = false
# Extra audio latency in ms (bluetooth headphones...), positive when the sound comes late
var audio_offset = 0

const KEY_MAPPING_PATH = "user://mappings.cfg"

func _ready():
	load_key_mappings()

# Apply the remapped keys saved by the Controller Setup menu
func load_key_mappings():
	var config_file = ConfigFile.new()
	if config_file.load(KEY_MAPPING_PATH) != OK or not config_file.has_section("input"):
		return
	for action in config_file.get_section_keys("input"):
		var saved_key = config_file.get_value("input", action, "")
		if saved_key == "" or not InputMap.has_action(action):
			continue
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

# Per-player variables: "hispeed" belongs to player 1, "p2_hispeed" to player 2
func get_player_var(player: int, var_name: String):
	return get(var_name if player == 1 else "p2_" + var_name)

func set_player_var(player: int, var_name: String, value) -> void:
	set(var_name if player == 1 else "p2_" + var_name, value)

# Versus outcome for a player, decided by the highest score
func get_versus_result(player: int) -> String:
	var own_score = get_player_var(player, "score")
	var opponent_score = get_player_var(3 - player, "score")
	if own_score > opponent_score:
		return "WIN"
	elif own_score < opponent_score:
		return "LOSE"
	return "DRAW"

const VERSUS_RESULT_COLORS = {
	"WIN": Color(1, 0.85, 0),
	"LOSE": Color(0.3, 0.5, 1),
	"DRAW": Color(1, 1, 1),
}
