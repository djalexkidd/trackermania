extends Control

@onready var req := $HTTPRequest

func set_busy(busy: bool) -> void:
	for child in $VBoxContainer.get_children():
		if child is Button:
			child.disabled = busy

func refresh_song_list() -> void:
	set_busy(true)
	$VBoxContainer/StatusLabel.text = "Scanning songs…"
	var songs = await Loader.get_song_catalog(true)
	$VBoxContainer/StatusLabel.text = "%d charts found. Song list refreshed." % songs.size()
	set_busy(false)

func _on_refresh_songs_pressed() -> void:
	await refresh_song_list()

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
	set_busy(true)
	$VBoxContainer/StatusLabel.text = "Downloading…"
	req.download_file = "user://test_music.zip"
	var error = req.request("https://djalexkidd.fr.nf/trackermania/test_music.zip")
	if error != OK:
		$VBoxContainer/StatusLabel.text = "Unable to start the download."
		set_busy(false)

func _on_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		$VBoxContainer/StatusLabel.text = "Download failed."
		set_busy(false)
		return
	unzip("user://test_music.zip")
	await refresh_song_list()

func _on_button_4_pressed() -> void:
	OS.shell_open(OS.get_user_data_dir())

func _on_button_5_pressed() -> void:
	$FileDialogFS.popup()

func _on_file_dialog_user_file_selected(path: String) -> void:
	unzip(path)
	await refresh_song_list()
