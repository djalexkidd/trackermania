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
