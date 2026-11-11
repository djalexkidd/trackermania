extends TextureButton

@export var category_name :String = ""
@export var category_texture :Texture2D

# Font size of the names, smaller for a long name so it fits the label
const FONT_SIZE = 31
const MIN_FONT_SIZE = 16
# Vertical center of the coloured band of the category textures (67 px high)
const BAND_CENTER_Y = 37.0
# digitalix capitals: top and height of the glyphs, in font sizes, from the top of the label
const GLYPH_TOP = 0.32
const GLYPH_HEIGHT = 0.925

func _ready() -> void:
	$Label.text = category_name
	texture_normal = category_texture
	fit_label()

# Shrink a long name to the width of the label, and center the capitals on the band
func fit_label() -> void:
	var label: Label = $Label
	var font = label.get_theme_font("font")
	var width = label.size.x - label.get_theme_constant("outline_size")
	var font_size = FONT_SIZE
	var text_width = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	if text_width > width:
		font_size = maxi(MIN_FONT_SIZE, floori(FONT_SIZE * width / text_width))
	label.add_theme_font_size_override("font_size", font_size)
	# Still too long at the smallest size: cut with an ellipsis
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var height = label.size.y
	label.position.y = roundf(BAND_CENTER_Y - font_size * (GLYPH_TOP + GLYPH_HEIGHT / 2.0))
	label.size.y = height

func _on_pressed() -> void:
	get_node("../../..").toggle_category(get_parent())

func _on_focus_entered() -> void:
	$AnimationPlayer.play("open")

func _on_focus_exited() -> void:
	$AnimationPlayer.play("RESET")
