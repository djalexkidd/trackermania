extends Node

var score = 0
var ex_score = 0
var combo_max = 0
var combo_max_top = 0
var failed = false
var gauge_score = 0
# Details of the last play for the result screen (judgements, FAST/SLOW, gauge graph, previous best)
var result = {}

var gauge_level = 0
var keys_mode = 7
var hispeed = 1.0
var auto_play = false
var auto_scratch = false
var random = false
# MIRROR (keys reversed), never with RANDOM
var mirror = false
# DOUBLE PLAY (14 keys on both decks), only when this player is alone
var double_play = false
# RANGE (lane covers), an index of LANE_COVERS
var lane_cover = 0
# Height of the SUDDEN+ cover and of the LIFT in px, moved with START + turntable while playing
var sudden_height = 150.0
var lift_height = 80.0

# Players in game on this machine (START joins, META leaves in the music select)
var p1_joined = true
var p2_joined = false

var p2_score = 0
var p2_ex_score = 0
var p2_combo_max = 0
var p2_combo_max_top = 0
var p2_failed = false
var p2_gauge_score = 0
var p2_result = {}

var p2_gauge_level = 0
var p2_keys_mode = 7
var p2_hispeed = 1.0
var p2_auto_play = false
var p2_auto_scratch = false
var p2_random = false
var p2_mirror = false
var p2_double_play = false
var p2_lane_cover = 0
var p2_sudden_height = 150.0
var p2_lift_height = 80.0

# Hi-speed is the falling time of a note in seconds, changed by steps in the OPTION SETTING panel and while playing
const HISPEED_MIN = 0.45
const HISPEED_MAX = 1.0
const HISPEED_STEP = 0.05
# RANGE: SUDDEN+ covers the top of the lanes, LIFT raises the judge line
const LANE_COVERS = ["OFF", "SUDDEN+", "LIFT", "LIFT SUD+"]

# BATTLE (two players): the 2P side plays the chart mirrored
var battle = false

# Song of the last play: title, artist, difficulty, level
var song_info = {}

var p1_name = ""
var p2_name = ""

var custom_music_select_bgm = ""
# Show the timing error in ms under the judgement (Customization menu)
var show_timing = false
# Extra audio latency in ms (bluetooth headphones...), positive when the sound comes late
var audio_offset = 0
var fullscreen = false
var vsync = true
# Volume of the Master bus, in percent
var master_volume = 100

const KEY_MAPPING_PATH = "user://mappings.cfg"
# System settings of the OPTIONS menu, saved in SETTINGS_PATH
const SETTINGS_PATH = "user://settings.cfg"
const SETTING_DEFAULTS = {
	"fullscreen": false,
	"vsync": true,
	"show_timing": false,
	"master_volume": 100,
	"audio_offset": 0,
	"custom_music_select_bgm": "",
	# The 1P name is the netplay name, saved by Netplay
	"p2_name": "",
}

func _ready():
	load_key_mappings()
	load_settings()

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for setting in SETTING_DEFAULTS:
			set(setting, config.get_value("settings", setting, SETTING_DEFAULTS[setting]))
	# The custom BGM may have been deleted since
	if custom_music_select_bgm != "" and not FileAccess.file_exists(custom_music_select_bgm):
		custom_music_select_bgm = ""
	apply_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	for setting in SETTING_DEFAULTS:
		config.set_value("settings", setting, get(setting))
	config.save(SETTINGS_PATH)

func apply_settings() -> void:
	# Only a desktop window can leave full screen
	if OS.has_feature("pc"):
		var fullscreen_mode = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if fullscreen != fullscreen_mode:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume / 100.0))

# Apply the remapped keys saved by the Controller Setup menu
func load_key_mappings():
	var config_file = ConfigFile.new()
	if config_file.load(KEY_MAPPING_PATH) != OK or not config_file.has_section("input"):
		return
	for action in config_file.get_section_keys("input"):
		var saved_key = config_file.get_value("input", action, "")
		if saved_key == "" or not InputMap.has_action(action):
			continue
		var input_event = string_to_event(saved_key, 0 if action.begins_with("p1_") else 1)
		if input_event == null:
			continue
		# Erase existing action events and add the loaded event
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, input_event)

# Saved form of an input: key name, "Button:index:device" or "Axis:axis:sign:device"
func event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.keycode if event.keycode != KEY_NONE else event.physical_keycode)
	if event is InputEventJoypadButton:
		return "Button:%d:%d" % [event.button_index, event.device]
	if event is InputEventJoypadMotion:
		return "Axis:%d:%d:%d" % [event.axis, sign(event.axis_value), event.device]
	return ""

# Old saves have no device ("Button:3"), it falls back to the player's pad
func string_to_event(saved_key: String, default_device := 0) -> InputEvent:
	var parts = saved_key.split(":")
	if parts[0] == "Button":
		var button = InputEventJoypadButton.new()
		button.button_index = int(parts[1])
		button.device = int(parts[2]) if parts.size() > 2 else default_device
		return button
	if parts[0] == "Axis" and parts.size() > 3:
		var motion = InputEventJoypadMotion.new()
		motion.axis = int(parts[1])
		motion.axis_value = float(parts[2])
		motion.device = int(parts[3])
		return motion
	var keycode = OS.find_keycode_from_string(saved_key)
	if keycode == KEY_NONE:
		return null
	var key = InputEventKey.new()
	key.keycode = keycode
	return key

# Bind a single input to an action and remember it in the mappings file
func save_key_mapping(action: String, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	var config_file = ConfigFile.new()
	config_file.load(KEY_MAPPING_PATH)
	config_file.set_value("input", action, event_to_string(event))
	config_file.save(KEY_MAPPING_PATH)

# Back to the inputs of project.godot
func reset_key_mapping(action: String) -> void:
	InputMap.action_erase_events(action)
	for event in ProjectSettings.get_setting("input/" + action)["events"]:
		InputMap.action_add_event(action, event)
	var config_file = ConfigFile.new()
	if config_file.load(KEY_MAPPING_PATH) == OK and config_file.has_section_key("input", action):
		config_file.erase_section_key("input", action)
		config_file.save(KEY_MAPPING_PATH)

# Per-player variables: "hispeed" belongs to player 1, "p2_hispeed" to player 2
func get_player_var(player: int, var_name: String):
	return get(var_name if player == 1 else "p2_" + var_name)

func set_player_var(player: int, var_name: String, value) -> void:
	set(var_name if player == 1 else "p2_" + var_name, value)

# DOUBLE PLAY of the player alone in game, never in versus or netplay
func is_double_play() -> bool:
	if p1_joined == p2_joined or Netplay.active:
		return false
	return get_player_var(1 if p1_joined else 2, "double_play")

# BATTLE needs both players
func is_battle() -> bool:
	return battle and p1_joined and p2_joined and not Netplay.active

# No AUTO PLAY in arcade and netplay
func can_auto_play() -> bool:
	return not Arcade.active and not Netplay.active

func is_auto_play(player: int) -> bool:
	return get_player_var(player, "auto_play") and can_auto_play()

func has_sudden(player: int) -> bool:
	return get_player_var(player, "lane_cover") in [1, 3]

func has_lift(player: int) -> bool:
	return get_player_var(player, "lane_cover") >= 2

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
