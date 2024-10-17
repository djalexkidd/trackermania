extends TextureButton

var song_name = ""
var difficulty = ""
var creator = ""

func _on_pressed() -> void:
	print($Label.text)
