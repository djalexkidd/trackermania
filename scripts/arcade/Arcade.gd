class_name Arcade

# ARCADE mode like IIDX: 3 stages, alone or in versus, a stage failed by every player is the GAME OVER
# (in versus, one CLEAR keeps both players), a song is played once whatever its difficulty, then the NAME ENTRY
# and the ranking of the total EX score of each player. The players join before the 1st stage.
# The DOUBLE PLAY is chosen before the 1st stage, the single play and double play games have their own rankings.

const STAGES = 3
const STAGE_NAMES = ["1ST STAGE", "2ND STAGE", "FINAL STAGE"]
# Time to choose a song, then to enter the name
const SELECT_TIME = 60.0
const NAME_ENTRY_TIME = 30.0
const RANKING_PATH = "user://arcade_ranking.cfg"
const RANKING_SIZE = 100

static var active := false
# One entry per stage played: song, difficulty, EX score, lamp...
static var stages: Array = []
# Index in the ranking of the games of the last name entry, by player (none when out of the ranking)
static var last_ranks := {}

static func start() -> void:
	active = true
	stages.clear()
	last_ranks.clear()
	# No AUTO PLAY in arcade
	Global.auto_play = false
	Global.p2_auto_play = false

static func stop() -> void:
	active = false

static func stage_name(index: int) -> String:
	return STAGE_NAMES[clampi(index, 0, STAGES - 1)]

# Name of the stage being chosen or played
static func current_stage_name() -> String:
	return stage_name(stages.size())

# The difficulties of a song share its folder (.qua, BMS), a module gives all its difficulties itself
static func song_key(path: String) -> String:
	return path if ModModule.is_module(path) else path.get_base_dir()

static func is_played(path: String) -> bool:
	return stages.any(func(stage): return song_key(stage["path"]) == song_key(path))

# Called at the end of a play for each player: both players of a versus share the stage of their song.
# A lamp of FAILED ends the game only when every player of the stage failed.
static func add_stage(player: int) -> void:
	var lamp = Scores.lamp(player)
	var result = {
		"ex_score": Global.get_player_var(player, "ex_score"),
		"max_ex": Global.get_player_var(player, "result").get("note_count", 0) * 2,
		"lamp": lamp, "failed": lamp == 0,
	}
	# The other player of the versus already added the stage
	if not stages.is_empty() and not stages[-1]["players"].has(player) and stages[-1]["path"] == Loader.file_path:
		stages[-1]["players"][player] = result
		return
	stages.append({
		"path": Loader.file_path, "difficulty": Loader.chart_difficulty,
		"title": Global.song_info.get("title", ""), "level": Global.song_info.get("level", 0),
		"double": Global.is_double_play(), "players": {player: result},
	})

# The players of the game are the ones of its 1st stage, before it the ones who joined
static func players() -> Array:
	if stages.is_empty():
		return [1, 2].filter(func(player): return Global.get("p%d_joined" % player))
	var result = stages[0]["players"].keys()
	result.sort()
	return result

# Every player of the stage failed: a player who failed goes on while the other one cleared
static func stage_failed(stage: Dictionary) -> bool:
	return stage["players"].values().all(func(result): return result["failed"])

# The style of the game is the one of its 1st stage, it cannot be changed after it
static func is_double() -> bool:
	return stages[0].get("double", false) if not stages.is_empty() else Global.is_double_play()

static func can_change_style() -> bool:
	return not active or stages.is_empty()

# A player can join (or leave) the game only before the 1st stage
static func can_join() -> bool:
	return not active or stages.is_empty()

static func ranking_key(double: bool) -> String:
	return "entries_dp" if double else "entries"

# Every player failed the last stage
static func game_over() -> bool:
	return not stages.is_empty() and stage_failed(stages[-1])

static func finished() -> bool:
	return stages.size() >= STAGES

static func player_stages(player: int) -> Array:
	return stages.filter(func(stage): return stage["players"].has(player)).map(func(stage): return stage["players"][player])

static func total_ex(player: int) -> int:
	var total = 0
	for result in player_stages(player):
		total += result["ex_score"]
	return total

static func total_max_ex(player: int) -> int:
	var total = 0
	for result in player_stages(player):
		total += result["max_ex"]
	return total

# Rate of the total EX score, for the DJ LEVEL of the ranking
static func total_rate(player: int) -> float:
	return total_ex(player) * 100.0 / maxi(total_max_ex(player), 1)

# Best totals first, of the single play or the double play games
static func load_ranking(double: bool) -> Array:
	var config = ConfigFile.new()
	config.load(RANKING_PATH)
	return config.get_value("ranking", ranking_key(double), [])

# Add the game of each player to the ranking ({player: name}), after the name entry
static func save_ranking(names: Dictionary) -> void:
	var double = is_double()
	var entries = load_ranking(double)
	last_ranks.clear()
	for player in names:
		var entry = {
			"name": names[player], "ex_score": total_ex(player), "rate": total_rate(player),
			"songs": stages.filter(func(stage): return stage["players"].has(player)).map(func(stage): return stage["title"]),
			"date": Time.get_date_string_from_system(),
		}
		# A tie goes under the older games
		var rank = entries.size()
		for i in entries.size():
			if entry["ex_score"] > entries[i]["ex_score"]:
				rank = i
				break
		entries.insert(rank, entry)
		# The game entered before goes down under this one
		for other in last_ranks:
			if last_ranks[other] >= rank:
				last_ranks[other] += 1
		last_ranks[player] = rank
	entries.resize(mini(entries.size(), RANKING_SIZE))
	for player in last_ranks.keys():
		if last_ranks[player] >= RANKING_SIZE:
			last_ranks.erase(player)
	# The other ranking is kept
	var config = ConfigFile.new()
	config.load(RANKING_PATH)
	config.set_value("ranking", ranking_key(double), entries)
	config.save(RANKING_PATH)
