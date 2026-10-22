extends Control

# TIME REMAIN of the arcade mode, over the OK and EXIT tags of the info bar like on IIDX,
# with the stage on the left; the OPTIONS tag is hidden

signal timeout

const TITLE_FONT = preload("res://assets/font/digitalix.ttf")
const LEFT = -380.0
const WIDTH = 380.0
# OPTIONS tag of the info bar, hidden in arcade
const OPTIONS_TAG = Rect2(-205, 0, 210, 98)
# Left end of the stage name on the screen, under MUSIC SELECT, lined up with the song info
const CAPTION_LEFT = 32.0
const DIGIT_SIZE = 44
const HUNDREDTHS_SIZE = 22
const HURRY_TIME = 10.0
const DIGIT_COLOR = Color(1, 1, 1)
const DIGIT_OUTLINE = Color(0.35, 0.02, 0.02)
const HURRY_COLOR = Color(1, 0.15, 0.1)
const STAGE_COLOR = Color(1, 0.82, 0.1)
const STAGE_OUTLINE = Color(0.45, 0.18, 0)

var time_left := 60.0
var running := false
# Stage name, empty for none
var caption := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(get_viewport_rect().size.x + LEFT, 0)
	size = Vector2(WIDTH, 100)

func start(seconds: float) -> void:
	time_left = seconds
	running = true

func _process(delta: float) -> void:
	queue_redraw()
	if not running:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left == 0.0:
		running = false
		timeout.emit()

func _draw() -> void:
	draw_rect(Rect2(0, 8, WIDTH, 88), Color.BLACK)
	draw_rect(OPTIONS_TAG, Color.BLACK)
	var hurry = time_left < HURRY_TIME
	var digit_color = HURRY_COLOR if hurry and Time.get_ticks_msec() % 500 < 250 else DIGIT_COLOR
	var hundredths = "%02d" % mini(int(fmod(time_left, 1.0) * 100.0), 99)
	var seconds = "%02d" % int(time_left)
	# From the right: hundredths, seconds, then the label, in fixed cells so nothing moves
	var right = WIDTH - 8
	right = draw_digits(right, hundredths, HUNDREDTHS_SIZE, digit_color, 6) - 6
	right = draw_digits(right, seconds, DIGIT_SIZE, digit_color, 8) - 14
	var label = Rect2(right - 132, 64, 132, 20)
	draw_rect(label, Color(0.12, 0.12, 0.12))
	draw_rect(label, Color(0.45, 0.45, 0.45), false, 1.0)
	draw_text(Vector2(label.get_center().x, label.end.y - 5), "TIME REMAIN", 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	if caption != "":
		draw_text(Vector2(CAPTION_LEFT - position.x, 88), caption, 28, STAGE_COLOR, HORIZONTAL_ALIGNMENT_LEFT, 8, STAGE_OUTLINE)

# Each digit centered in a cell as wide as the widest digit, returns the left end
func draw_digits(right: float, digits: String, font_size: int, digit_color: Color, outline: int) -> float:
	var cell = 0.0
	for digit in "0123456789":
		cell = maxf(cell, TITLE_FONT.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var left = right - cell * digits.length()
	for i in digits.length():
		draw_text(Vector2(roundf(left + cell * (i + 0.5)), 84), digits[i], font_size, digit_color, HORIZONTAL_ALIGNMENT_CENTER, outline, DIGIT_OUTLINE)
	return left

func draw_text(at: Vector2, text: String, font_size: int, text_color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, outline_color := Color.BLACK) -> void:
	var width = TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Whole pixels for the pixel font
	var x = roundf(at.x - (width if alignment == HORIZONTAL_ALIGNMENT_RIGHT else width / 2 if alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0))
	# The segments of digitalix leave a thin horizontal gap: drawn again 1 px lower to fill it
	if outline > 0:
		for dy in 2:
			draw_string_outline(TITLE_FONT, Vector2(x, at.y + dy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
	for dy in 2:
		draw_string(TITLE_FONT, Vector2(x, at.y + dy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
