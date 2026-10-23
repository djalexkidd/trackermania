extends ColorRect

# OPTION SETTING panel, held open with START, drawn like on IIDX:
# the options of the black keys hang above the keys, those of the white keys below, the PACEMAKER on the turntable.

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
	[1, "RANDOM", ["OFF", "RANDOM", "MIRROR"]],
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
const WHITE_BOX_TOP = 404.0
const WHITE_BOX_SIZE = Vector2(96, 30)
# PACEMAKER row, from the bottom of the panel: the turntable on the side of the player, then the target
const PACEMAKER_BOTTOM = 58.0
const PACEMAKER_HEIGHT = 26.0
const PACEMAKER_TITLE_WIDTH = 96.0
# Turntable move for one PACEMAKER step, like the song wheel
const ANALOG_STEP = 0.08
# The turntable stays lit this long after it moved
const TURN_LIGHT_MSEC = 150

# AUTO PLAY is a cheat code: the 3rd black key (STYLE) held this long, a shorter press changes the STYLE
const AUTO_HOLD_MSEC = 1000

const FLASH_MSEC = 250.0

# Last change of each key, for the flash of its option
var changed_at := {}
# Held open by START, set by music_select; the panel still shows while sliding out
var open := false
# When the 3rd black key was pressed (-1 when released), and whether its hold already switched AUTO PLAY
var style_pressed_at := -1
var auto_switched := false
# Analog turntable position of the last frame and move not turned into a step yet, when it last moved
var analog_previous := 0.0
var analog_remainder := 0.0
var turned_at := -TURN_LIGHT_MSEC

func _ready():
	color = Color(0.02, 0.03, 0.06, 0.94)
	analog_previous = analog_value()

func _process(_delta: float) -> void:
	# The analog turntable is followed even when hidden, it does not jump when the panel opens
	var analog = analog_value()
	var motion = wrapf(analog - analog_previous, -1.0, 1.0)
	analog_previous = analog
	if not visible:
		return
	# Redrawn every frame for the key lights and the flashes
	queue_redraw()
	if not open:
		style_pressed_at = -1
		analog_remainder = 0.0
		return
	# Turntable: PACEMAKER target, forward to the next one
	var steps = int(Input.is_action_just_pressed(key("digital_turntable_fwd"))) - int(Input.is_action_just_pressed(key("digital_turntable_rew")))
	analog_remainder += motion
	var analog_steps = int(analog_remainder / ANALOG_STEP)
	analog_remainder -= analog_steps * ANALOG_STEP
	steps += analog_steps
	if steps != 0 and can_pacemaker():
		set_opt("pacemaker", posmod(get_opt("pacemaker") + steps, Global.PACEMAKERS.size()))
		turned_at = Time.get_ticks_msec()
		changed(7)
	if Input.is_action_just_pressed(key("key1")) and can_battle():
		Global.battle = !Global.battle
		emit_signal("update", "battle", Global.battle)
		changed(0)

	if Input.is_action_just_pressed(key("key3")) and can_double():
		set_opt("double_play", !get_opt("double_play"))
		emit_signal("update", "double", get_opt("double_play"))
		changed(2)

	if Input.is_action_just_pressed(key("key5")):
		# RANGE: OFF -> SUDDEN+ -> LIFT -> LIFT SUD+
		set_opt("lane_cover", (get_opt("lane_cover") + 1) % Global.LANE_COVERS.size())
		changed(4)

	if Input.is_action_just_pressed(key("key2")):
		# OFF -> RANDOM -> MIRROR
		var lane_option = (selected_choice(0) + 1) % 3
		set_opt("random", lane_option == 1)
		set_opt("mirror", lane_option == 2)
		emit_signal("update", "random", lane_option != 0)
		changed(1)

	if Input.is_action_just_pressed(key("key4")):
		set_opt("gauge_level", (get_opt("gauge_level") + 1) % 3)
		emit_signal("update", "difficulty", get_opt("gauge_level"))
		changed(3)

	if Input.is_action_just_pressed(key("key6")):
		style_pressed_at = Time.get_ticks_msec()
		auto_switched = false
	if style_pressed_at >= 0 and Input.is_action_pressed(key("key6")):
		# Held: AUTO PLAY, never in arcade and netplay
		if not auto_switched and Time.get_ticks_msec() - style_pressed_at >= AUTO_HOLD_MSEC and Global.can_auto_play():
			auto_switched = true
			set_opt("auto_play", !get_opt("auto_play"))
			emit_signal("update", "auto", get_opt("auto_play"))
	elif style_pressed_at >= 0:
		# A short press: 7 keys -> 5 keys -> auto scratch -> 5 keys with auto scratch
		if Time.get_ticks_msec() - style_pressed_at < AUTO_HOLD_MSEC:
			var style = (style_index() + 1) % 4
			set_opt("keys_mode", 5 if style % 2 == 1 else 7)
			set_opt("auto_scratch", style >= 2)
			emit_signal("update", "five", style % 2 == 1)
			emit_signal("update", "ascratch", style >= 2)
			changed(5)
		style_pressed_at = -1

	if Input.is_action_just_pressed(key("key7")):
		var hispeed = snappedf(get_opt("hispeed") - Global.HISPEED_STEP, 0.01)
		set_opt("hispeed", Global.HISPEED_MAX if hispeed < Global.HISPEED_MIN else hispeed)
		emit_signal("update", "hispeed", get_opt("hispeed"))
		changed(6)

# DOUBLE PLAY: alone and offline, and in arcade only before the 1st stage (single and double play have their own rankings)
func can_double() -> bool:
	return not (Global.p1_joined and Global.p2_joined) and not Netplay.active and Arcade.can_change_style()

# The analog turntable reports an absolute, wrapping position
func analog_value() -> float:
	return Input.get_action_strength(key("analog_turntable_fwd")) - Input.get_action_strength(key("analog_turntable_rew"))

# The PACEMAKER graph is not shown when two players play, like on IIDX
func can_pacemaker() -> bool:
	return not (Global.p1_joined and Global.p2_joined)

# BATTLE replaces it when both players are in game
func can_battle() -> bool:
	return Global.p1_joined and Global.p2_joined and not Netplay.active

func changed(i: int) -> void:
	changed_at[i] = Time.get_ticks_msec()

func style_index() -> int:
	return (1 if get_opt("keys_mode") == 5 else 0) + (2 if get_opt("auto_scratch") else 0)

func selected_choice(column: int) -> int:
	match column:
		0: return 1 if get_opt("random") else (2 if get_opt("mirror") else 0)
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

# A rect of the 1P layout, mirrored for 2P whose turntable is on the right
func side_rect(rect: Rect2) -> Rect2:
	if player == 2:
		rect.position.x = size.x - rect.end.x
	return rect

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
	# The AUTO PLAY of the cheat code is only shown here
	if Global.is_auto_play(player):
		draw_text(TITLE_FONT, Rect2(tag.end.x + 136, tag.position.y, size.x - 72 - tag.end.x - 136, tag.size.y), "AUTO", 14, Color.BLACK)
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

	# White keys: one option under each, [title, value, chosen, available, value shown when not available]
	var hispeed = get_opt("hispeed")
	var double = get_opt("double_play")
	var cover = get_opt("lane_cover")
	var white_options = {
		0: ["BATTLE", "ON" if Global.battle else "OFF", Global.battle, can_battle(), "---"],
		# The DOUBLE PLAY of an arcade game is kept after the 1st stage
		2: ["DOUBLE", "ON" if double else "OFF", double, can_double(), ("ON" if double else "OFF") if Arcade.active else "---"],
		4: ["RANGE", Global.LANE_COVERS[cover], cover != 0, true, "---"],
		6: ["HI-SPEED", "%.2f" % hispeed, hispeed != Global.HISPEED_MAX, true, "---"],
	}
	for i in [0, 2, 4, 6]:
		var box = white_box_rect(i)
		var lit = Input.is_action_pressed(key("key%d" % (i + 1)))
		draw_link(Vector2(box.get_center().x, WHITE_KEY_TOP + KEY_SIZE.y + 4), Vector2(box.get_center().x, box.position.y - 4), accent if lit else LINE)
		var option = white_options[i]
		var title_rect = Rect2(box.position.x - 6, box.end.y + 4, box.size.x + 12, 18)
		if option[3]:
			draw_box(box, option[1], option[2], flash(i))
			draw_text(TITLE_FONT, title_rect, option[0], 12, ORANGE)
		else:
			draw_box(box, option[4], false, 0.0, true)
			draw_text(TITLE_FONT, title_rect, option[0], 12, LINE)

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

	# Turntable: the PACEMAKER, with arrows on the sides of its box
	var top = size.y - PACEMAKER_BOTTOM
	var left = keys_left()
	var right = left + 6 * KEY_STEP + KEY_SIZE.x
	var turntable = side_rect(Rect2(left, top, PACEMAKER_HEIGHT, PACEMAKER_HEIGHT))
	var turning = Time.get_ticks_msec() - turned_at < TURN_LIGHT_MSEC
	draw_circle(turntable.get_center(), PACEMAKER_HEIGHT / 2 + 2, Color(0.2, 0.2, 0.24))
	draw_circle(turntable.get_center(), PACEMAKER_HEIGHT / 2, accent.lightened(0.3) if turning else Color(0.06, 0.06, 0.08))
	draw_circle(turntable.get_center(), 3, Color(0.85, 0.85, 0.88))
	var title = side_rect(Rect2(left + PACEMAKER_HEIGHT + 4, top, PACEMAKER_TITLE_WIDTH, PACEMAKER_HEIGHT))
	var box = side_rect(Rect2(left + PACEMAKER_HEIGHT + PACEMAKER_TITLE_WIDTH + 8, top, right - left - PACEMAKER_HEIGHT - PACEMAKER_TITLE_WIDTH - 8, PACEMAKER_HEIGHT))
	if not can_pacemaker():
		draw_text(TITLE_FONT, title, "PACEMAKER", 12, LINE)
		draw_box(box, "---", false, 0.0, true)
	else:
		draw_text(TITLE_FONT, title, "PACEMAKER", 12, ORANGE)
		var pacemaker = get_opt("pacemaker")
		draw_box(box, Global.PACEMAKERS[pacemaker], pacemaker != 0, flash(7))
	for direction in [-1, 1] if can_pacemaker() else []:
		var tip = Vector2(box.get_center().x + direction * (box.size.x / 2 - 6), box.get_center().y)
		var back = tip.x - direction * 7
		draw_colored_polygon(PackedVector2Array([tip, Vector2(back, tip.y - 6), Vector2(back, tip.y + 6)]), accent if turning else LINE)

	# Help line
	var help = Rect2(0, size.y - 30, size.x, 22)
	draw_text(FONT, help, "HOLD START  -  PRESS A KEY TO CHANGE", 14, Color(0.6, 0.62, 0.7))

func get_opt(option : String):
	return Global.get_player_var(player, option)

func set_opt(option : String, value) -> void:
	Global.set_player_var(player, option, value)

# Input action of this player, "key1" -> "p1_key1"
func key(action : String) -> String:
	return "p%d_%s" % [player, action]
