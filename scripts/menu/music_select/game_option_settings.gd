extends ColorRect

# OPTION SETTING panel, held open with START, drawn like on IIDX:
# the options of the black keys hang above the keys, those of the white keys below.

signal update(option, status)

# Player owning this panel (1 or 2)
@export var player : int = 1

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const FONT = preload("res://assets/font/FT2FONT.TTF")

const ORANGE = Color(1, 0.45, 0)
const SELECTED_BORDER = Color(1, 0.85, 0.2)
const BOX = Color(0.1, 0.1, 0.12)
const BOX_BORDER = Color(0.55, 0.55, 0.6)
const LINE = Color(0.45, 0.45, 0.5)
const P1_COLOR = Color(0, 0.686275, 1)
const P2_COLOR = Color(1, 0.156863, 0)

const HEADER_HEIGHT = 44.0
# Black key columns: [key, title, choices]
const COLUMNS = [
	[1, "RANDOM", ["OFF", "RANDOM"]],
	[3, "GAUGE", ["NORMAL", "EASY", "HARD"]],
	[5, "STYLE", ["7KEYS", "5KEYS", "A-SCR", "5K A-SCR"]],
]
const COLUMN_WIDTH = 128.0
const COLUMN_STEP = 136.0
const COLUMNS_TOP = 64.0
const CHOICE_HEIGHT = 26.0
const CHOICE_STEP = 30.0
# Keys of the deck, 1~7
const KEY_SIZE = Vector2(48, 76)
const KEY_STEP = 52.0
const BLACK_KEY_TOP = 228.0
const WHITE_KEY_TOP = 318.0
# White key options, under the keys
const WHITE_BOX_TOP = 420.0
const WHITE_BOX_SIZE = Vector2(96, 30)

const FLASH_MSEC = 250.0
const HISPEED_MIN = 0.45
const HISPEED_MAX = 1.0
const HISPEED_STEP = 0.05

# Last change of each key, for the flash of its option
var changed_at := {}
# Held open by START, set by music_select; the panel still shows while sliding out
var open := false

func _ready():
	color = Color(0.02, 0.03, 0.06, 0.94)

func _process(_delta: float) -> void:
	if not visible:
		return
	# Redrawn every frame for the key lights and the flashes
	queue_redraw()
	if not open:
		return
	# No AUTO PLAY in arcade
	if Input.is_action_just_pressed(key("key1")) and not Arcade.active:
		set_opt("auto_play", !get_opt("auto_play"))
		emit_signal("update", "auto", get_opt("auto_play"))
		changed(0)

	if Input.is_action_just_pressed(key("key2")):
		set_opt("random", !get_opt("random"))
		emit_signal("update", "random", get_opt("random"))
		changed(1)

	if Input.is_action_just_pressed(key("key4")):
		set_opt("gauge_level", (get_opt("gauge_level") + 1) % 3)
		emit_signal("update", "difficulty", get_opt("gauge_level"))
		changed(3)

	if Input.is_action_just_pressed(key("key6")):
		# 7 keys -> 5 keys -> auto scratch -> 5 keys with auto scratch
		var style = (style_index() + 1) % 4
		set_opt("keys_mode", 5 if style % 2 == 1 else 7)
		set_opt("auto_scratch", style >= 2)
		emit_signal("update", "five", style % 2 == 1)
		emit_signal("update", "ascratch", style >= 2)
		changed(5)

	if Input.is_action_just_pressed(key("key7")):
		var hispeed = snappedf(get_opt("hispeed") - HISPEED_STEP, 0.01)
		set_opt("hispeed", HISPEED_MAX if hispeed < HISPEED_MIN else hispeed)
		emit_signal("update", "hispeed", get_opt("hispeed"))
		changed(6)

func changed(i: int) -> void:
	changed_at[i] = Time.get_ticks_msec()

func style_index() -> int:
	return (1 if get_opt("keys_mode") == 5 else 0) + (2 if get_opt("auto_scratch") else 0)

func selected_choice(column: int) -> int:
	match column:
		0: return 1 if get_opt("random") else 0
		1: return get_opt("gauge_level")
		_: return style_index()

# Flash of a key's option, 1 right after a change down to 0
func flash(i: int) -> float:
	if not changed_at.has(i):
		return 0.0
	return clamp(1.0 - (Time.get_ticks_msec() - changed_at[i]) / FLASH_MSEC, 0.0, 1.0)

func keys_left() -> float:
	return (size.x - (6 * KEY_STEP + KEY_SIZE.x)) / 2

func key_rect(i: int) -> Rect2:
	var top = BLACK_KEY_TOP if i % 2 == 1 else WHITE_KEY_TOP
	return Rect2(Vector2(keys_left() + i * KEY_STEP, top), KEY_SIZE)

func column_rect(column: int) -> Rect2:
	var left = (size.x - (2 * COLUMN_STEP + COLUMN_WIDTH)) / 2 + column * COLUMN_STEP
	var choices = COLUMNS[column][2].size()
	return Rect2(left, COLUMNS_TOP + 22, COLUMN_WIDTH, (choices - 1) * CHOICE_STEP + CHOICE_HEIGHT)

func white_box_rect(i: int) -> Rect2:
	var center = key_rect(i).get_center().x
	return Rect2(Vector2(center - WHITE_BOX_SIZE.x / 2, WHITE_BOX_TOP), WHITE_BOX_SIZE)

# Text centered in a rect, made smaller until it fits
func draw_text(font: Font, rect: Rect2, text: String, font_size: int, text_color: Color) -> void:
	while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x - 8:
		font_size -= 1
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline = rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2
	draw_string(font, Vector2(rect.get_center().x - width / 2, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

# An option box, orange with a yellow border when chosen
func draw_box(rect: Rect2, text: String, selected: bool, flash_amount := 0.0, dim := false) -> void:
	if selected:
		draw_rect(rect.grow(3), Color(ORANGE, 0.25))
		draw_rect(rect, ORANGE)
		draw_rect(rect, SELECTED_BORDER, false, 2.0)
	else:
		draw_rect(rect, BOX)
		draw_rect(rect, Color(BOX_BORDER, 0.35 if dim else 1.0), false, 1.0)
	if flash_amount > 0:
		draw_rect(rect, Color(1, 1, 1, 0.6 * flash_amount))
	var text_color = Color(1, 1, 1, 0.3) if dim else Color.WHITE
	draw_text(TITLE_FONT, rect, text, 14, text_color)

# Elbow line between an option and its key
func draw_link(from: Vector2, to: Vector2, link_color: Color) -> void:
	var middle = (from.y + to.y) / 2
	draw_polyline([from, Vector2(from.x, middle), Vector2(to.x, middle), to], link_color, 2.0)

func _draw() -> void:
	var accent = P1_COLOR if player == 1 else P2_COLOR

	# Background stripes and frame
	for x in range(-int(size.y), int(size.x), 36):
		draw_line(Vector2(x, size.y), Vector2(x + size.y * 0.6, HEADER_HEIGHT), Color(ORANGE, 0.05), 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), ORANGE, false, 2.0)
	draw_rect(Rect2(0, size.y - 6, size.x, 6), ORANGE)

	# Header: OPTION in a black tag, SETTING on the orange bar, side of the player
	draw_rect(Rect2(0, 0, size.x, HEADER_HEIGHT), ORANGE)
	var tag = Rect2(10, 7, 128, HEADER_HEIGHT - 14)
	draw_rect(tag, Color.BLACK)
	draw_text(TITLE_FONT, tag, "OPTION", 18, Color.WHITE)
	draw_text(TITLE_FONT, Rect2(tag.end.x, tag.position.y, 140, tag.size.y), "SETTING", 18, Color.WHITE)
	var side = Rect2(size.x - 62, 7, 52, HEADER_HEIGHT - 14)
	draw_rect(side, Color(0.05, 0.05, 0.08))
	draw_text(TITLE_FONT, side, "%dP" % player, 18, accent)

	# Black keys: a column of choices above each one
	for column in COLUMNS.size():
		var i = COLUMNS[column][0]
		var rect = column_rect(column)
		var lit = Input.is_action_pressed(key("key%d" % (i + 1)))
		draw_text(TITLE_FONT, Rect2(rect.position.x, COLUMNS_TOP, rect.size.x, 18), COLUMNS[column][1], 14, ORANGE)
		var selected = selected_choice(column)
		for choice in COLUMNS[column][2].size():
			var box = Rect2(rect.position + Vector2(0, choice * CHOICE_STEP), Vector2(rect.size.x, CHOICE_HEIGHT))
			draw_box(box, COLUMNS[column][2][choice], choice == selected, flash(i) if choice == selected else 0.0)
		draw_link(Vector2(rect.get_center().x, rect.end.y + 4), Vector2(key_rect(i).get_center().x, BLACK_KEY_TOP - 4), accent if lit else LINE)

	# White keys: one option under each, keys 3 and 5 have none
	var hispeed = get_opt("hispeed")
	var white_options = {
		0: ["AUTO PLAY", "ON" if get_opt("auto_play") else "OFF", get_opt("auto_play")],
		6: ["HI-SPEED", "%.2f" % hispeed, hispeed != HISPEED_MAX],
	}
	for i in [0, 2, 4, 6]:
		var box = white_box_rect(i)
		var lit = Input.is_action_pressed(key("key%d" % (i + 1)))
		draw_link(Vector2(box.get_center().x, WHITE_KEY_TOP + KEY_SIZE.y + 4), Vector2(box.get_center().x, box.position.y - 4), accent if lit else LINE)
		if i == 0 and Arcade.active:
			draw_box(box, "---", false, 0.0, true)
			draw_text(TITLE_FONT, Rect2(box.position.x - 6, box.end.y + 4, box.size.x + 12, 18), white_options[i][0], 12, LINE)
		elif white_options.has(i):
			draw_box(box, white_options[i][1], white_options[i][2], flash(i))
			draw_text(TITLE_FONT, Rect2(box.position.x - 6, box.end.y + 4, box.size.x + 12, 18), white_options[i][0], 12, ORANGE)
		else:
			draw_box(box, "---", false, 0.0, true)

	# Keys, lit in the player color while pressed
	for i in 7:
		var rect = key_rect(i)
		var black = i % 2 == 1
		var lit = Input.is_action_pressed(key("key%d" % (i + 1)))
		draw_rect(rect.grow(3), Color(0.2, 0.2, 0.24))
		if lit:
			draw_rect(rect.grow(6), Color(accent, 0.35))
			draw_rect(rect, accent.lightened(0.3))
		elif black:
			draw_rect(rect, Color(0.06, 0.06, 0.08))
			draw_rect(rect.grow(-6), Color(0.14, 0.14, 0.17))
		else:
			draw_rect(rect, Color(0.85, 0.85, 0.88))
			draw_rect(Rect2(rect.position + Vector2(6, 6), Vector2(rect.size.x - 12, rect.size.y * 0.4)), Color.WHITE)
		draw_rect(rect, Color.BLACK, false, 2.0)

	# Help line
	var help = Rect2(0, size.y - 40, size.x, 30)
	draw_text(FONT, help, "HOLD START  -  PRESS A KEY TO CHANGE", 16, Color(0.6, 0.62, 0.7))

func get_opt(option : String):
	return Global.get_player_var(player, option)

func set_opt(option : String, value) -> void:
	Global.set_player_var(player, option, value)

# Input action of this player, "key1" -> "p1_key1"
func key(action : String) -> String:
	return "p%d_%s" % [player, action]
