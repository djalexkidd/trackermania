extends Node

var file_path = ""
# Difficulty of the chart generated from an Amiga module
var chart_difficulty = ""

const SONG_CACHE_PATH = "user://song_catalog.json"
# Bump when selection metadata or module chart generation changes.
const SONG_CACHE_VERSION = 2

# Cache only selection metadata, never chart notes or module audio.
func get_song_catalog(force_refresh: bool = false) -> Array:
	if not force_refresh and FileAccess.file_exists(SONG_CACHE_PATH):
		var cache = load_json_file(SONG_CACHE_PATH)
		if cache.get("version") == SONG_CACHE_VERSION and cache.get("songs") is Array:
			var songs: Array = cache["songs"]
			if not songs.is_empty() and songs.all(is_song_metadata):
				return songs

	var songs: Array = []
	DirAccess.make_dir_recursive_absolute("user://songs")
	await get_tree().process_frame
	var batch_start = Time.get_ticks_msec()
	for song_path in get_all_files("user://songs"):
		var extension = song_path.get_extension().to_lower()
		if extension not in ["qua", "mod"]:
			continue
		# Let the loading message render and keep the menu responsive.
		if Time.get_ticks_msec() - batch_start >= 8:
			await get_tree().process_frame
			batch_start = Time.get_ticks_msec()
		if extension == "qua":
			var chart = QuaChart.load_file(song_path)
			if chart == null:
				continue
			var entry = {
				"path": song_path,
				"Title": chart.title if chart.title != "" else song_path.get_file().get_basename(),
				"Artist": chart.artist,
				"Difficulty": chart.level,
				"DifficultyName": chart.difficultyName,
			}
			if is_song_metadata(entry):
				songs.append(entry)
		else:
			var module = ModModule.load_file(song_path)
			if module == null:
				continue
			var title = module.title if module.title != "" else song_path.get_file().get_basename()
			for difficulty_name in ModChart.DIFFICULTIES:
				var chart = ModChart.new(module, difficulty_name)
				songs.append({
					"path": song_path, "Title": title, "Artist": "Amiga module",
					"Difficulty": chart.level, "DifficultyName": difficulty_name,
				})

	var file = FileAccess.open(SONG_CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": SONG_CACHE_VERSION, "songs": songs}))
		file.close()
	else:
		push_warning("Could not save song catalog: %s" % FileAccess.get_open_error())
	return songs

func is_song_metadata(entry: Variant) -> bool:
	if not entry is Dictionary:
		return false
	for field in ["path", "Title", "Artist", "DifficultyName"]:
		if not entry.get(field) is String:
			return false
	var difficulty = entry.get("Difficulty")
	if not (difficulty is float or difficulty is int):
		return false
	return difficulty >= 1 and difficulty <= 8 and difficulty == int(difficulty) \
		and entry["path"].begins_with("user://songs/") \
		and entry["path"].get_extension().to_lower() in ["qua", "mod"]

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
		
		if json_result == OK and json_parser.data is Dictionary:
			return json_parser.data  # The parsed data is stored in 'data'
		else:
			print("Error parsing JSON in", file_path, ":", json_result)
	else:
		print("Failed to open file:", file_path)
	
	return {}
