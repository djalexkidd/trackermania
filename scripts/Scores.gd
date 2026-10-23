class_name Scores

# Best scores of the solo plays: one section per chart file, one key per difficulty (prefixed by DP_ in double play)
const PATH = "user://scores.cfg"
# Clear lamps from the worst to the best
const LAMPS = ["FAILED", "ASSIST CLEAR", "EASY CLEAR", "CLEAR", "HARD CLEAR", "FULL COMBO", "PERFECT"]
const LAMP_COLORS = [Color(1, 0.1, 0), Color(0.7, 0.4, 1), Color(0.3, 1, 0.3), Color(0, 0.735801, 1), Color(1, 0.3, 0), Color(1, 1, 0), Color(1, 1, 1)]
const RANKS = ["F", "F", "E", "D", "C", "B", "A", "AA", "AAA", "AAA"]

static var config: ConfigFile

static func load_config() -> ConfigFile:
	if config == null:
		config = ConfigFile.new()
		config.load(PATH)
	return config

# Rank letter of an EX rate, one rank every 1/9 of the maximum EX score like in IIDX
static func rank(rate: float) -> String:
	return RANKS[rank_index(rate)]

# Index of an EX rate in RANKS, the ninths of the maximum EX score reached
static func rank_index(rate: float) -> int:
	# The small margin keeps exactly 8/9 in AAA despite the float rounding
	return clampi(int(rate * 9.0 / 100.0 + 0.000001), 0, 9)

# Clear lamp of the last play of a player, index in LAMPS
static func lamp(player: int) -> int:
	var gauge_level = Global.get_player_var(player, "gauge_level")
	if Global.get_player_var(player, "gauge_score") < 80 and gauge_level < 2 or Global.get_player_var(player, "failed"):
		return 0
	# Assist options (auto-scratch, 5 keys) give the assist lamp whatever the score, like in IIDX
	if Global.get_player_var(player, "auto_scratch") or Global.get_player_var(player, "keys_mode") == 5:
		return 1
	if Global.get_player_var(player, "score") == 100:
		return 6
	if Global.get_player_var(player, "combo_max") == Global.get_player_var(player, "combo_max_top"):
		return 5
	return [3, 2, 4][gauge_level]

# Target of a PACEMAKER (Global.PACEMAKERS) as [name, EX score]: a DJ LEVEL, the best score, a rate of the maximum,
# NEXT (the DJ LEVEL above the best score) or NEXT+ (the next half DJ LEVEL above it, "AA+" is half way to AAA)
static func pacemaker_target(pacemaker: String, max_ex: int, best_ex: int) -> Array:
	match pacemaker:
		"MY BEST":
			return ["MY BEST", best_ex]
		"MAX":
			return ["MAX", max_ex]
		"NEXT", "NEXT+":
			# Ninths of the maximum for NEXT, eighteenths for NEXT+
			var steps = 9 if pacemaker == "NEXT" else 18
			for step in range(1, steps):
				var ex = ceili(max_ex * step / float(steps) - 0.000001)
				if ex > best_ex:
					var rank_name = RANKS[floori(step * 9.0 / steps)]
					return [rank_name + "+" if step * 9 % steps != 0 else rank_name, ex]
			return ["MAX", max_ex]
	if pacemaker.ends_with("%"):
		return [pacemaker, ceili(max_ex * int(pacemaker.trim_suffix("%")) / 100.0 - 0.000001)]
	return [pacemaker, ceili(max_ex * RANKS.find(pacemaker) / 9.0 - 0.000001)]

# The single play and double play scores of a chart are kept apart, a module has both
static func key(difficulty_name: String, double: bool) -> String:
	return "DP_" + difficulty_name if double else difficulty_name

# Best play of a chart, empty when it was never played
static func get_best(path: String, difficulty_name: String, double := false) -> Dictionary:
	return load_config().get_value(path, key(difficulty_name, double), {})

# Keep the best of each value separately like in IIDX
static func save_play(player: int, path: String, difficulty_name: String, double := false) -> void:
	var best: Dictionary = load_config().get_value(path, key(difficulty_name, double), {})
	best["ex_score"] = maxi(best.get("ex_score", 0), Global.get_player_var(player, "ex_score"))
	best["rate"] = maxf(best.get("rate", 0.0), Global.get_player_var(player, "score"))
	best["lamp"] = maxi(best.get("lamp", 0), lamp(player))
	best["combo_max"] = maxi(best.get("combo_max", 0), Global.get_player_var(player, "combo_max"))
	# The miss count of a failed play is not kept, the end of the chart was not played
	var miss_count = Global.get_player_var(player, "result").get("miss_count", -1)
	if miss_count >= 0 and not Global.get_player_var(player, "failed"):
		best["miss_count"] = mini(best.get("miss_count", miss_count), miss_count)
	best["play_count"] = best.get("play_count", 0) + 1
	config.set_value(path, key(difficulty_name, double), best)
	config.save(PATH)
