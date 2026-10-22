class_name Arcade

# ARCADE mode like IIDX: 3 stages, a failed stage is the GAME OVER, a song is played once
# whatever its difficulty, then the NAME ENTRY and the ranking of the total EX score.

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
# Index in the ranking of the last name entry, -1 when none
static var last_rank := -1

static func start() -> void:
	active = true
	stages.clear()
	last_rank = -1
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
	return path if path.get_extension().to_lower() == "mod" else path.get_base_dir()

static func is_played(path: String) -> bool:
	return stages.any(func(stage): return song_key(stage["path"]) == song_key(path))

# Called at the end of a solo play, a lamp of FAILED ends the game
static func add_stage(player: int) -> void:
	var lamp = Scores.lamp(player)
	stages.append({
		"path": Loader.file_path, "difficulty": Loader.chart_difficulty,
		"title": Global.song_info.get("title", ""), "level": Global.song_info.get("level", 0),
		"ex_score": Global.get_player_var(player, "ex_score"),
		"max_ex": Global.get_player_var(player, "result").get("note_count", 0) * 2,
		"lamp": lamp, "failed": lamp == 0,
	})

static func game_over() -> bool:
	return not stages.is_empty() and stages[-1]["failed"]

static func finished() -> bool:
	return stages.size() >= STAGES

static func total_ex() -> int:
	var total = 0
	for stage in stages:
		total += stage["ex_score"]
	return total

static func total_max_ex() -> int:
	var total = 0
	for stage in stages:
		total += stage["max_ex"]
	return total

# Rate of the total EX score, for the DJ LEVEL of the ranking
static func total_rate() -> float:
	return total_ex() * 100.0 / maxi(total_max_ex(), 1)

# Best totals first
static func load_ranking() -> Array:
	var config = ConfigFile.new()
	config.load(RANKING_PATH)
	return config.get_value("ranking", "entries", [])

# Add the game to the ranking, after the name entry
static func save_ranking(dj_name: String) -> void:
	var entries = load_ranking()
	var entry = {
		"name": dj_name, "ex_score": total_ex(), "rate": total_rate(),
		"songs": stages.map(func(stage): return stage["title"]),
		"date": Time.get_date_string_from_system(),
	}
	# A tie goes under the older games
	last_rank = entries.size()
	for i in entries.size():
		if entry["ex_score"] > entries[i]["ex_score"]:
			last_rank = i
			break
	entries.insert(last_rank, entry)
	entries.resize(mini(entries.size(), RANKING_SIZE))
	if last_rank >= RANKING_SIZE:
		last_rank = -1
	var config = ConfigFile.new()
	config.set_value("ranking", "entries", entries)
	config.save(RANKING_PATH)
