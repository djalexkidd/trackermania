extends Control

# Difficulties of the song under the cursor, like the DIFFICULTY boxes of IIDX: E3 (VEFX) picks the next one

const FONT = preload("res://assets/font/04B_20__.TTF")
# Square digits of the levels, like IIDX
const LEVEL_FONT = preload("res://assets/font/digitalix.ttf")
# More difficulties scroll with the chosen one (Quaver songs often have many)
const MAX_BOXES = 5
const BOX_WIDTH = 120.0
const GAP = 6.0
const CAPTION_HEIGHT = 20.0
# The chosen box stands out above the others
const RAISE = 6.0
const LEVEL_SIZE = 32
const NAME_SIZE = 16
const MIN_NAME_SIZE = 8
const POP_TIME = 0.15

var charts: Array = []
var colors: Array = []
var lamps: Array = []
var selected = 0
var first = 0
# Grows the chosen box for a moment when E3 changes it
var pop = 0.0:
	set(value):
		pop = value
		queue_redraw()
var pop_tween: Tween

func show_entry(entry: Control) -> void:
	var changed = entry.charts == charts and entry.chart_index != selected
	charts = entry.charts
	selected = entry.chart_index
	colors.assign(range(charts.size()).map(entry.chart_color))
	lamps.assign(range(charts.size()).map(entry.chart_lamp))
	var count = mini(charts.size(), MAX_BOXES)
	first = clampi(selected - count / 2, 0, charts.size() - count)
	if changed:
		if pop_tween:
			pop_tween.kill()
		pop_tween = create_tween()
		pop_tween.tween_property(self, "pop", 0.0, POP_TIME).from(1.0)
	queue_redraw()

func _draw() -> void:
	var count = mini(charts.size(), MAX_BOXES)
	if count == 0:
		return
	var box_width = minf(BOX_WIDTH, (size.x - GAP * (count - 1)) / count)
	var total = box_width * count + GAP * (count - 1)
	# Right aligned like the song info labels
	var left = size.x - total
	draw_string(FONT, Vector2(left, 14), "DIFFICULTY", HORIZONTAL_ALIGNMENT_LEFT, total, 14, Color(0.7, 0.7, 0.7))
	if charts.size() > count:
		draw_string(FONT, Vector2(left, 14), "%d/%d" % [selected + 1, charts.size()], HORIZONTAL_ALIGNMENT_RIGHT, total, 14, Color(0.7, 0.7, 0.7))
	var top = CAPTION_HEIGHT + RAISE
	for k in count:
		var index = first + k
		var rect = Rect2(left + k * (box_width + GAP), top, box_width, size.y - top)
		var color: Color = colors[index]
		var level_color = color.darkened(0.35)
		var name_color = color.darkened(0.45)
		if index == selected:
			rect.position.y -= RAISE
			rect = rect.grow(pop * 4.0)
			draw_rect(rect, Color(color.darkened(0.6), 0.95))
			draw_rect(rect, color, false, 3.0)
			level_color = color
			name_color = Color.WHITE
		else:
			draw_rect(rect, Color(0.05, 0.05, 0.08, 0.85))
			draw_rect(rect, color.darkened(0.5), false, 2.0)
		var level_position = Vector2(rect.position.x, rect.position.y + 38)
		# The segments of digitalix leave a thin horizontal gap: drawn again 1 px lower to fill it
		for dy in 2:
			if index == selected:
				draw_string_outline(LEVEL_FONT, level_position + Vector2(0, dy), str(charts[index]["level"]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, LEVEL_SIZE, 6, Color(0, 0, 0, 0.8))
		for dy in 2:
			draw_string(LEVEL_FONT, level_position + Vector2(0, dy), str(charts[index]["level"]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, LEVEL_SIZE, level_color)
		draw_name(charts[index]["difficulty_name"].to_upper(), rect, name_color)
		# Clear lamp of the difficulty
		if lamps[index] >= 0:
			draw_rect(Rect2(rect.position.x + 6, rect.end.y - 9, rect.size.x - 12, 4), Scores.LAMP_COLORS[lamps[index]])

# The name shrinks to fit its box, then is cut
func draw_name(text: String, rect: Rect2, color: Color) -> void:
	var width = rect.size.x - 8
	var font_size = NAME_SIZE
	while font_size > MIN_NAME_SIZE and FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	while text.length() > 1 and FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		text = text.left(-1)
	draw_string(FONT, Vector2(rect.position.x, rect.end.y - 18), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)
