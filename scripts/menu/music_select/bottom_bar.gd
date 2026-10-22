extends Control

# Bottom bar of the music select, drawn like on IIDX RED: the player plates and the effector on top,
# the strips of game options below on a red band. An absent player's strip shows PRESS START BUTTON.

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const STRIP_FONT = preload("res://assets/font/tallpixelfont.ttf")

const RED = Color(0.9, 0.05, 0.05)
const BAND_TOP = Color(0.42, 0.02, 0.02)
const BAND_BOTTOM = Color(0.12, 0.0, 0.0)
const METAL = Color(0.62, 0.62, 0.68)
const SEGMENT = Color(0.06, 0.06, 0.07)
const SEGMENT_TEXT = Color(0.86, 0.86, 0.9)
const LIT_TOP = Color(1, 0.78, 0.25)
const LIT_BOTTOM = Color(1, 0.36, 0)
const LIT_BORDER = Color(1, 0.92, 0.55)
const EFFECT_BLUE = Color(0.25, 0.75, 1)
const OFF_GRAY = Color(0.32, 0.32, 0.38)
const PLAYER_COLORS = [Color(0.305, 0.305, 0.305), Color(0, 0.686, 1), Color(1, 0.157, 0)]

# Rows: plates and effector, then the option strips
const PLATE_TOP = 8.0
const PLATE_HEIGHT = 26.0
const PLATE_WIDTH = 232.0
const BAND_Y = 38.0
const STRIP_TOP = 44.0
const STRIP_HEIGHT = 26.0
const STRIP_MARGIN = 14.0
const CAP_WIDTH = 5.0
const SEGMENT_GAP = 2.0
const EFFECTOR_WIDTH = 280.0
const BLINK_SEC = 2.0

func _process(_delta: float) -> void:
	# Redrawn every frame: options, players and effector change from everywhere, PRESS START blinks
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	draw_rect(Rect2(0, 0, size.x, 3), RED)
	draw_gradient(Rect2(0, BAND_Y, size.x, size.y - BAND_Y), BAND_TOP, BAND_BOTTOM)
	draw_rect(Rect2(0, BAND_Y, size.x, 1), Color(RED, 0.8))
	for player in [1, 2]:
		draw_plate(player)
		draw_strip(player)
	draw_effector()

# x of the P1 layout, mirrored on the right for P2
func side_x(player: int, x: float) -> float:
	return x if player == 1 else size.x - x

func side_points(player: int, points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2(side_x(player, point.x), point.y))
	return result

func is_joined(player: int) -> bool:
	return Global.get("p%d_joined" % player)

# The side taken by the other player's DOUBLE PLAY
func is_double_side(player: int) -> bool:
	return not is_joined(player) and Global.is_double_play()

func plate_color(player: int) -> Color:
	if is_joined(player):
		return PLAYER_COLORS[player]
	if is_double_side(player):
		return PLAYER_COLORS[3 - player]
	return PLAYER_COLORS[0]

# PLAYER 1 / DJ name in a slanted plate of the player color, two stripes after it
func draw_plate(player: int) -> void:
	var color = plate_color(player)
	var top = PLATE_TOP
	var bottom = PLATE_TOP + PLATE_HEIGHT
	var left = STRIP_MARGIN
	var right = STRIP_MARGIN + PLATE_WIDTH
	draw_colored_polygon(side_points(player, [Vector2(left, top), Vector2(right, top), Vector2(right - 14, bottom), Vector2(left, bottom)]), color)
	draw_line(Vector2(side_x(player, left), top + 1), Vector2(side_x(player, right - 1), top + 1), color.lightened(0.45), 2.0)
	for i in 2:
		var x = right + 6 + i * 12
		draw_colored_polygon(side_points(player, [Vector2(x, top), Vector2(x + 7, top), Vector2(x - 7, bottom), Vector2(x - 14, bottom)]), Color(color, 0.7 - i * 0.3))

	var text_rect = Rect2(minf(side_x(player, left), side_x(player, right - 14)), top, PLATE_WIDTH - 14, PLATE_HEIGHT)
	var dj_name = Global.p1_name if player == 1 else Global.p2_name
	if is_double_side(player):
		draw_text(TITLE_FONT, text_rect, "DOUBLE", 18, Color.BLACK)
	elif dj_name == "":
		draw_text(TITLE_FONT, text_rect, "PLAYER %d" % player, 18, Color.BLACK)
	else:
		draw_text(TITLE_FONT, text_rect, "DJ  " + dj_name, 18, Color.BLACK)

func strip_rect(player: int) -> Rect2:
	var width = size.x / 2 - STRIP_MARGIN - 10
	var x = STRIP_MARGIN if player == 1 else size.x / 2 + 10
	return Rect2(x, STRIP_TOP, width, STRIP_HEIGHT)

# [text, lit, width weight] of each option, in the order of IIDX
func strip_options(player: int) -> Array:
	var hispeed = Global.get_player_var(player, "hispeed")
	var gauge = Global.get_player_var(player, "gauge_level")
	var mirror = Global.get_player_var(player, "mirror")
	return [
		["HI-S %.2f" % hispeed, hispeed != 1.0, 1.5],
		["AUTO", Global.is_auto_play(player), 1.0],
		["BTL", Global.is_battle(), 1.0],
		["HARD" if gauge == 2 else "EASY", gauge != 0, 1.0],
		["MIR" if mirror else "RAN", mirror or Global.get_player_var(player, "random"), 1.0],
		["A-SCR", Global.get_player_var(player, "auto_scratch"), 1.0],
		["5KEY", Global.get_player_var(player, "keys_mode") == 5, 1.0],
		["DP", Global.get_player_var(player, "double_play"), 1.0],
		["SUD+", Global.has_sudden(player), 1.0],
		["LIFT", Global.has_lift(player), 1.0],
	]

# Metal frame with caps of the player color, a lit segment per option chosen
func draw_strip(player: int) -> void:
	var rect = strip_rect(player)
	var color = plate_color(player)
	draw_rect(rect.grow(3), Color(0.14, 0.14, 0.16))
	draw_rect(rect.grow(3), METAL, false, 2.0)
	draw_rect(rect, Color.BLACK)
	draw_rect(Rect2(rect.position, Vector2(CAP_WIDTH, rect.size.y)), color)
	draw_rect(Rect2(rect.end.x - CAP_WIDTH, rect.position.y, CAP_WIDTH, rect.size.y), color)
	var inner = Rect2(rect.position.x + CAP_WIDTH + SEGMENT_GAP, rect.position.y, rect.size.x - 2 * (CAP_WIDTH + SEGMENT_GAP), rect.size.y)

	if not is_joined(player):
		# PRESS START BUTTON hides the options of an absent player, nothing on the side of a DOUBLE PLAY
		if not is_double_side(player):
			var alpha = 0.6 + 0.4 * cos(Time.get_ticks_msec() / 1000.0 * TAU / BLINK_SEC)
			draw_text(STRIP_FONT, inner, "PRESS START BUTTON", 26, Color(1, 1, 1, alpha), Color(0, 0, 0, alpha))
		return

	var options = strip_options(player)
	var weights = options.reduce(func(total, option): return total + option[2], 0.0)
	var unit = (inner.size.x - SEGMENT_GAP * (options.size() - 1)) / weights
	var x = inner.position.x
	for option in options:
		var segment = Rect2(x, inner.position.y + 2, unit * option[2], inner.size.y - 4)
		draw_segment(segment, option[0], option[1], option[0] == "AUTO")
		x += segment.size.x + SEGMENT_GAP

# An option: orange when chosen like on IIDX, AUTO pulses
func draw_segment(rect: Rect2, text: String, lit: bool, pulse: bool) -> void:
	if not lit:
		draw_rect(rect, SEGMENT)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1)), Color(1, 1, 1, 0.08))
		draw_text(STRIP_FONT, rect, text, 22, SEGMENT_TEXT, Color.BLACK)
		return
	var top = LIT_TOP
	if pulse:
		top = LIT_BOTTOM.lerp(LIT_TOP, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU))
	draw_gradient(rect, top, LIT_BOTTOM)
	draw_rect(rect, LIT_BORDER, false, 1.0)
	draw_text(STRIP_FONT, rect, text, 22, Color.WHITE, Color(0.45, 0.12, 0))

# Plaque in the middle, lit in blue while an effector is on
func draw_effector() -> void:
	var on = Effector.index != 0
	var center = size.x / 2
	var half = EFFECTOR_WIDTH / 2
	var top = PLATE_TOP
	var middle = PLATE_TOP + PLATE_HEIGHT / 2
	var bottom = PLATE_TOP + PLATE_HEIGHT
	var points = PackedVector2Array([
		Vector2(center - half + 12, top), Vector2(center + half - 12, top), Vector2(center + half, middle),
		Vector2(center + half - 12, bottom), Vector2(center - half + 12, bottom), Vector2(center - half, middle),
	])
	if on:
		var glow = PackedVector2Array()
		for point in points:
			glow.append(Vector2(center + (point.x - center) * 1.03, middle + (point.y - middle) * 1.35))
		draw_colored_polygon(glow, Color(EFFECT_BLUE, 0.35))
		draw_polygon(points, PackedColorArray([Color(0, 0.35, 0.7), Color(0, 0.35, 0.7), Color(0, 0.2, 0.5),
			Color(0, 0.1, 0.3), Color(0, 0.1, 0.3), Color(0, 0.2, 0.5)]))
	else:
		draw_colored_polygon(points, Color(0.07, 0.07, 0.09))
	var closed = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, EFFECT_BLUE.lightened(0.3) if on else OFF_GRAY, 2.0)

	# Three dots on each side
	var dot_color = EFFECT_BLUE if on else OFF_GRAY
	for direction in [-1, 1]:
		for dot in [Vector2(10, -5), Vector2(10, 5), Vector2(18, 0)]:
			var at = Vector2(center + direction * (half + dot.x), middle + dot.y)
			draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), dot_color)

	var text_rect = Rect2(center - half + 14, top, EFFECTOR_WIDTH - 28, PLATE_HEIGHT)
	if on:
		draw_text(TITLE_FONT, text_rect, Effector.current_name(), 16, Color.WHITE, Color(0, 0.25, 0.6))
	else:
		draw_text(TITLE_FONT, text_rect, Effector.current_name(), 16, OFF_GRAY.lightened(0.15))

# Vertical gradient
func draw_gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

# Text centered in a rect, made smaller until it fits, with an optional outline
func draw_text(font: Font, rect: Rect2, text: String, font_size: int, text_color: Color, outline := Color.TRANSPARENT) -> void:
	while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x - 6:
		font_size -= 1
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline = rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2
	var at = Vector2(rect.get_center().x - width / 2, baseline)
	if outline.a > 0:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, outline)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
