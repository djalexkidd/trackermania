extends TextureButton

@export var category_name :String = ""
@export var category_texture :Texture2D

func _ready() -> void:
	$Label.text = category_name
	texture_normal = category_texture

func _on_pressed() -> void:
	get_node("../MusicList").visible = !get_node("../MusicList").visible
