extends Control

@onready var req := $HTTPRequest

# Unzip the downloaded file
static func unzip(path_to_zip: String) -> void:
	var zr : ZIPReader = ZIPReader.new()
	
	if zr.open(path_to_zip) == OK:
		for filepath in zr.get_files():
			var zip_directory : String = path_to_zip.get_base_dir()
			var trimmed_path : String = "user://songs"
			
			var da : DirAccess = DirAccess.open(zip_directory)
			
			# Create the base directory for the unzipped content
			da.make_dir(trimmed_path)
			
			# Make sure we are working within the newly created directory
			da = DirAccess.open(trimmed_path)
			
			# Create subdirectories recursively based on the filepath
			da.make_dir_recursive(filepath.get_base_dir())
			
			print("Extracting: " + trimmed_path + "/" + filepath)
			# Open the file for writing in the correct subdirectory
			var fa : FileAccess = FileAccess.open("%s/%s" % [trimmed_path, filepath], FileAccess.WRITE)
			
			if fa != null:
				fa.store_buffer(zr.read_file(filepath))
				fa.close()
		
		zr.close()
	else:
		print("Failed to open ZIP archive.")

func _on_button_pressed() -> void:
	req.download_file = "user://test_music.zip"
	req.request("https://djalexkidd.fr.nf/trackermania/test_music.zip")

func _on_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	unzip("user://test_music.zip")
