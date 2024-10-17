extends Node

var file_path = ""

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
