extends Control

@export var font: Font
@export var font_size = 31
@export var font_color = Color.WHITE
@export var outline_color = Color.BLACK
@export var outline_size = 4

var scroll_offset = 0.0
var repeat_width = 0.0

func _ready() -> void:
	repeat_width = font.get_string_size("? ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func scroll_title(distance: float) -> void:
	scroll_offset = fmod(distance, repeat_width)
	queue_redraw()

# Draw one short pattern repeatedly instead of reshaping a long label for every row.
func _draw() -> void:
	if repeat_width <= 0.0:
		return
	var baseline = Vector2(-scroll_offset, font.get_ascent(font_size))
	while baseline.x < size.x:
		draw_string_outline(font, baseline, "? ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
		draw_string(font, baseline, "? ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_color)
		baseline.x += repeat_width
