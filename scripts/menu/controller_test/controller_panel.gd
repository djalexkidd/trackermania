extends Node
class_name ControllerPanel

# CONTROLLER SET UP of the OPTIONS menu, drawn by options_menu.gd in its panel, which forwards the controls:
# the IIDX deck of one side, lit by the inputs, and the list of its bindings.
# A white key on a row waits for the input to assign to it (ESC or right click cancels).

signal assigned

const FONT = preload("res://assets/font/FT2FONT.TTF")
const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")

const P1_COLOR = Color(0, 0.686275, 1)
const P2_COLOR = Color(1, 0.156863, 0)
# Colors of the options menu
const ROW = Color(0.1, 0.1, 0.1, 0.95)
const TAG_BORDER = Color(0.45, 0.45, 0.45)
const ORANGE = Color(1, 0.55, 0.05)
const YELLOW = Color(1, 0.82, 0.1)
const CYAN = Color(0.3, 0.9, 1)
const CONFLICT = Color(1, 0.3, 0.3)

# [action without the player prefix, label]; "analog_turntable" binds the fwd/rew pair
const ACTIONS = [
	["key1", "KEY 1"], ["key2", "KEY 2"], ["key3", "KEY 3"], ["key4", "KEY 4"],
	["key5", "KEY 5"], ["key6", "KEY 6"], ["key7", "KEY 7"],
	["digital_turntable_fwd", "TT UP"], ["digital_turntable_rew", "TT DOWN"],
	["analog_turntable", "ANALOG TT"],
	["start", "E1 START"], ["effect", "E2 EFFECT"], ["vefx", "E3 VEFX"], ["meta", "E4 META"],
]
const ANALOG = 9
const FIRST_E_BUTTON = 10
# Rows after the bindings, and the order of all the rows (two columns)
const ASSIGN_ALL = 14
const SIDE = 15
const SLOTS = [0, 1, 2, 3, 4, 5, 6, ASSIGN_ALL, 7, 8, 9, 10, 11, 12, 13, SIDE]
const ROWS_PER_COLUMN = 8

# Layout from the top left of the area given by the options menu
const TABS_TOP = 50.0
const TAB_WIDTH = 84.0
const DECK_TOP = 92.0
const ROWS_TOP = 288.0
const ROW_STEP = 30.0
const ROW_FONT_SIZE = 14

# Deck layout for 1P, the turntable goes to the right on 2P
const DECK_SIZE = Vector2(600, 184)
const TT_CENTER = Vector2(104, 92)
const TT_RADIUS = 76.0
const TT_CENTER_RADIUS = 22.0
const KEY_SIZE = Vector2(38, 56)
const KEY_STEP = 34.0
const KEYS_LEFT = 314.0
const BLACK_KEY_TOP = 44.0
const WHITE_KEY_TOP = 108.0
const E_BUTTON_SIZE = Vector2(34, 16)
const E_BUTTONS_TOP = 14.0
const METER_RECT = Rect2(20, 172, 560, 5)

const ROTATION_SPEED = 180.0 # degrees per unit of analog value
const DIGITAL_SPIN = 360.0 # degrees per second while a digital scratch is held
const SCRATCH_LIGHT_MS = 150
# The input that ends an assignment must not also drive the menu
const ASSIGN_GUARD_MS = 300

var player := 1
# Row under the cursor, in SLOTS
var cursor := 0
# Action waiting for an input, -1 if none
var listening := -1
var assign_all := false
var last_assign_msec := -ASSIGN_GUARD_MS

var rotation_angle := 0.0
var previous_value := 0.0
var last_scratch_move := -1000

# Where the last frame was drawn, for the mouse
var area := Rect2()

func accent() -> Color:
	return P1_COLOR if player == 1 else P2_COLOR

func prefix() -> String:
	return "p%d_" % player

func blink() -> bool:
	return Time.get_ticks_msec() % 500 < 300

# Waiting for an input, or just got one: the menu ignores the controllers
func busy() -> bool:
	return listening >= 0 or Time.get_ticks_msec() - last_assign_msec < ASSIGN_GUARD_MS

func set_player(value: int) -> void:
	if value == player or value not in [1, 2]:
		return
	stop_listening()
	player = value
	previous_value = analog_value()

func move(steps: int) -> bool:
	var index = clampi(cursor + steps, 0, SLOTS.size() - 1)
	if index == cursor:
		return false
	cursor = index
	return true

func decide() -> void:
	match SLOTS[cursor]:
		ASSIGN_ALL:
			start_listening(0)
			assign_all = true
		SIDE:
			set_player(3 - player)
		var action:
			start_listening(action)

func start_listening(i: int) -> void:
	listening = i
	assign_all = false
	cursor = SLOTS.find(i)

func stop_listening() -> void:
	if assign_all:
		cursor = SLOTS.find(ASSIGN_ALL)
	listening = -1
	assign_all = false

# EFFECT: the binding under the cursor, the whole side on the other rows, or both sides
func restore_default(both_sides: bool) -> void:
	stop_listening()
	var action = SLOTS[cursor]
	for p in ([1, 2] if both_sides else [player]):
		for i in ACTIONS.size():
			if both_sides or action >= ACTIONS.size() or i == action:
				Global.reset_key_mapping(action_name(p, i))
				if i == ANALOG:
					Global.reset_key_mapping("p%d_analog_turntable_rew" % p)

func action_name(p: int, i: int) -> String:
	return "p%d_" % p + ACTIONS[i][0] + ("_fwd" if i == ANALOG else "")

func full_action(i: int) -> String:
	return action_name(player, i)

# Name of the pad used by this side's keys, if any
func pad_name() -> String:
	for event in InputMap.action_get_events(prefix() + "key1"):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			if event.device in Input.get_connected_joypads():
				return Input.get_joy_name(event.device).to_upper()
			return "PAD %d NOT CONNECTED" % (event.device + 1)
	return "KEYBOARD"

# Short text of an input for the list
func input_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.keycode if event.keycode != KEY_NONE else event.physical_keycode).to_upper()
	if event is InputEventJoypadButton:
		return "BUTTON %d" % event.button_index
	if event is InputEventJoypadMotion:
		return "AXIS %d %s" % [event.axis, "+" if event.axis_value > 0 else "-"]
	return "?"

func binding_text(i: int) -> String:
	var events = InputMap.action_get_events(full_action(i))
	if events.is_empty():
		return "---"
	return input_text(events[0])

# The same input on two actions (of any player) shows in red
func has_conflict(i: int) -> bool:
	var events = InputMap.action_get_events(full_action(i))
	if events.is_empty():
		return false
	for p in [1, 2]:
		for j in ACTIONS.size():
			var other = action_name(p, j)
			if other == full_action(i):
				continue
			for event in InputMap.action_get_events(other):
				if same_input(event, events[0]):
					return true
	return false

func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a.get_class() != b.get_class():
		return false
	if a is InputEventKey:
		return input_text(a) == input_text(b)
	if a.device != b.device:
		return false
	if a is InputEventJoypadButton:
		return a.button_index == b.button_index
	return a is InputEventJoypadMotion and a.axis == b.axis and sign(a.axis_value) == sign(b.axis_value)

func assign(event: InputEvent) -> void:
	if listening == ANALOG:
		var reverse = event.duplicate()
		reverse.axis_value = -event.axis_value
		Global.save_key_mapping(prefix() + "analog_turntable_fwd", event)
		Global.save_key_mapping(prefix() + "analog_turntable_rew", reverse)
	else:
		Global.save_key_mapping(full_action(listening), event)
	assigned.emit()
	next_assignment()

func next_assignment() -> void:
	last_assign_msec = Time.get_ticks_msec()
	if assign_all and listening < ACTIONS.size() - 1:
		listening += 1
		cursor = SLOTS.find(listening)
	else:
		stop_listening()

# Clean copy of the input, the same as the one loaded from the mappings file at startup
func clean_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key = InputEventKey.new()
		key.keycode = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		return key
	if event is InputEventJoypadButton:
		var button = InputEventJoypadButton.new()
		button.button_index = event.button_index
		button.device = event.device
		return button
	var motion = InputEventJoypadMotion.new()
	motion.axis = event.axis
	motion.axis_value = sign(event.axis_value)
	motion.device = event.device
	return motion

func _input(event: InputEvent) -> void:
	if listening < 0:
		return
	if event is InputEventMouse:
		# Right click cancels, other clicks are left to the menu
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			stop_listening()
			get_viewport().set_input_as_handled()
		return
	var press = (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and not event.is_echo()
	var motion = event is InputEventJoypadMotion and abs(event.axis_value) > 0.5
	if press and event is InputEventKey and event.keycode == KEY_ESCAPE:
		stop_listening()
	elif listening == ANALOG:
		# Only an axis drives the analog turntable, any button skips it
		if motion:
			assign(clean_event(event))
		elif press:
			next_assignment()
		else:
			return
	elif press or (motion and listening in [7, 8]):
		# A digital turntable may also be an axis
		assign(clean_event(event))
	else:
		return
	get_viewport().set_input_as_handled()

func is_lit(i: int) -> bool:
	if i == ANALOG:
		return Time.get_ticks_msec() - last_scratch_move < SCRATCH_LIGHT_MS
	return Input.is_action_pressed(full_action(i))

func analog_value() -> float:
	return Input.get_action_strength(prefix() + "analog_turntable_fwd") - Input.get_action_strength(prefix() + "analog_turntable_rew")

func _process(delta: float) -> void:
	var value = analog_value()
	if value != previous_value:
		rotation_angle += (value - previous_value) * ROTATION_SPEED
		previous_value = value
		last_scratch_move = Time.get_ticks_msec()
	if Input.is_action_pressed(prefix() + "digital_turntable_fwd"):
		rotation_angle -= DIGITAL_SPIN * delta
	if Input.is_action_pressed(prefix() + "digital_turntable_rew"):
		rotation_angle += DIGITAL_SPIN * delta

# Text of the footer
func description() -> String:
	if listening == ANALOG:
		return "Turn the turntable, or press a key to skip it. ESC or right click: cancel."
	if listening >= 0:
		return "Press the input for %s. ESC or right click: cancel." % ACTIONS[listening][1]
	match SLOTS[cursor]:
		ASSIGN_ALL:
			return "Assign every input of the %dP side, one after the other." % player
		SIDE:
			return "Switch between the 1P and 2P controllers."
		ANALOG:
			return "Assign the axis of an analog turntable."
		var action:
			return "Assign an input to %s. EFFECT: back to the default." % ACTIONS[action][1]

# Mouse

func tab_rect(p: int) -> Rect2:
	return Rect2(area.position + Vector2((p - 1) * TAB_WIDTH, TABS_TOP), Vector2(TAB_WIDTH - 4, 30))

func deck_origin() -> Vector2:
	return area.position + Vector2((area.size.x - DECK_SIZE.x) / 2, DECK_TOP)

func row_rect(slot: int) -> Rect2:
	var width = (area.size.x - 12) / 2
	var column = slot / ROWS_PER_COLUMN
	return Rect2(area.position.x + column * (width + 12), area.position.y + ROWS_TOP + slot % ROWS_PER_COLUMN * ROW_STEP, width, ROW_STEP - 4)

# Deck positions are given for 1P, flipped for 2P (turntable on the right)
func flip(rect: Rect2) -> Rect2:
	if player == 2:
		rect.position.x = DECK_SIZE.x - rect.position.x - rect.size.x
	rect.position += deck_origin()
	return rect

func flip_point(point: Vector2) -> Vector2:
	if player == 2:
		point.x = DECK_SIZE.x - point.x
	return point + deck_origin()

# The keys move to the left on 2P but stay in the 1~7 order, as on the real deck
func key_rect(i: int) -> Rect2:
	var keys = flip(Rect2(KEYS_LEFT, 0, 6 * KEY_STEP + KEY_SIZE.x, 0))
	var top = BLACK_KEY_TOP if i % 2 == 1 else WHITE_KEY_TOP
	return Rect2(Vector2(keys.position.x + i * KEY_STEP, deck_origin().y + top), KEY_SIZE)

func e_button_rect(i: int) -> Rect2:
	var keys = flip(Rect2(KEYS_LEFT, 0, 6 * KEY_STEP + KEY_SIZE.x, 0))
	return Rect2(Vector2(keys.position.x + 52 + i * (E_BUTTON_SIZE.x + 12), deck_origin().y + E_BUTTONS_TOP), E_BUTTON_SIZE)

# Action of the deck under a point, -1 if none
func deck_element_at(point: Vector2) -> int:
	for i in 7:
		if key_rect(i).grow(2).has_point(point):
			return i
	for i in 4:
		if e_button_rect(i).grow(4).has_point(point):
			return FIRST_E_BUTTON + i
	var offset = point - flip_point(TT_CENTER)
	if offset.length() <= TT_CENTER_RADIUS:
		return ANALOG
	if offset.length() <= TT_RADIUS:
		return 7 if offset.y < 0 else 8
	return -1

# A click on a tab, the deck or a row, false if it hit nothing
func click(at: Vector2) -> bool:
	if area.size == Vector2.ZERO:
		return false
	for p in [1, 2]:
		if tab_rect(p).has_point(at):
			set_player(p)
			return true
	var element = deck_element_at(at)
	if element >= 0:
		start_listening(element)
		return true
	for slot in SLOTS.size():
		if row_rect(slot).has_point(at):
			cursor = slot
			decide()
			return true
	return false

# Drawing, on the canvas of the options menu

func element_colors(i: int, base: Color, active: bool) -> Array:
	var fill = base
	var border = Color(0.55, 0.55, 0.6)
	if is_lit(i):
		fill = Color.WHITE if base.v > 0.3 else accent().lightened(0.3)
		border = Color.WHITE
	if i == listening:
		border = YELLOW if blink() else ORANGE
		if not is_lit(i):
			fill = Color(ORANGE, 0.6 if blink() else 0.2)
	elif active and listening < 0 and SLOTS[cursor] == i:
		border = ORANGE
	return [fill, border]

func draw(canvas, rect: Rect2, active: bool, notice: String) -> void:
	area = rect
	draw_tabs(canvas, notice)
	draw_deck(canvas, active)
	for slot in SLOTS.size():
		draw_row(canvas, slot, active)

# 1P / 2P tabs, the pad of the side, and the status on the right
func draw_tabs(canvas, notice: String) -> void:
	for p in [1, 2]:
		var tab = tab_rect(p)
		var shape = PackedVector2Array([tab.position + Vector2(12, 0), Vector2(tab.end.x, tab.position.y), tab.end - Vector2(12, 0), Vector2(tab.position.x, tab.end.y)])
		if p == player:
			canvas.draw_colored_polygon(shape, P1_COLOR if p == 1 else P2_COLOR)
		else:
			shape.append(shape[0])
			canvas.draw_polyline(shape, TAG_BORDER, 2.0)
		canvas.draw_text(TITLE_FONT, Vector2(tab.get_center().x, tab.end.y - 7), "%dP" % p, 20, Color.BLACK if p == player else TAG_BORDER, HORIZONTAL_ALIGNMENT_CENTER)
	var baseline = area.position.y + TABS_TOP + 23
	var pad_left = area.position.x + 2 * TAB_WIDTH + 16
	var pad = pad_name()
	canvas.draw_text(FONT, Vector2(pad_left, baseline), pad, canvas.fit_size(FONT, pad, 24, 200), Color(0.6, 0.6, 0.6))

	var status = ""
	var status_color = YELLOW
	if notice != "":
		status = notice
	elif listening >= 0:
		status = "MOVE THE TURNTABLE" if listening == ANALOG else "PRESS %s" % ACTIONS[listening][1]
		if not blink():
			status_color = Color.WHITE
	elif range(ACTIONS.size()).any(has_conflict):
		status = "SAME INPUT ON TWO ACTIONS"
		status_color = CONFLICT
	if status != "":
		var right = area.end.x
		canvas.draw_text(TITLE_FONT, Vector2(right, baseline - 2), status, canvas.fit_size(TITLE_FONT, status, 14, right - pad_left - 216), status_color, HORIZONTAL_ALIGNMENT_RIGHT, 4)

func draw_deck(canvas, active: bool) -> void:
	var deck = Rect2(deck_origin(), DECK_SIZE)
	canvas.draw_rect(deck, Color(0.03, 0.03, 0.04, 0.95))
	canvas.draw_rect(deck, TAG_BORDER, false, 2.0)
	# Side stripe in the player color, on the turntable side
	canvas.draw_rect(flip(Rect2(0, 0, 6, DECK_SIZE.y)), accent())

	# Turntable: upper half is TT UP, lower half TT DOWN
	var center = flip_point(TT_CENTER)
	var scratching = is_lit(ANALOG) or is_lit(7) or is_lit(8)
	if scratching:
		canvas.draw_circle(center, TT_RADIUS + 6, Color(accent(), 0.35))
	canvas.draw_circle(center, TT_RADIUS, Color(0.1, 0.1, 0.12))
	for half in [7, 8]:
		var from = PI if half == 7 else 0.0
		var colors = element_colors(half, Color(0, 0, 0, 0), active)
		if colors[1] != Color(0.55, 0.55, 0.6):
			canvas.draw_arc(center, TT_RADIUS - 4, from, from + PI, 48, colors[1], 4.0, true)
	canvas.draw_arc(center, TT_RADIUS, 0, TAU, 96, Color(0.7, 0.7, 0.75), 2.0, true)
	for r in [TT_RADIUS * 0.82, TT_RADIUS * 0.66]:
		canvas.draw_arc(center, r, 0, TAU, 72, Color(0.3, 0.3, 0.35), 1.0, true)
	# Marker rotating with the turntable
	var direction = Vector2.UP.rotated(deg_to_rad(rotation_angle))
	canvas.draw_line(center + direction * TT_CENTER_RADIUS, center + direction * (TT_RADIUS - 8), Color.WHITE if scratching else accent(), 4.0, true)
	var analog_colors = element_colors(ANALOG, Color(0.18, 0.18, 0.2), active)
	canvas.draw_circle(center, TT_CENTER_RADIUS, analog_colors[0])
	canvas.draw_arc(center, TT_CENTER_RADIUS, 0, TAU, 48, analog_colors[1], 2.0, true)
	canvas.draw_text(TITLE_FONT, center + Vector2(0, 5), "TT", 12, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER)

	# E1~E4
	for i in 4:
		var rect = e_button_rect(i)
		var colors = element_colors(FIRST_E_BUTTON + i, Color(0.12, 0.12, 0.14), active)
		canvas.draw_rect(rect, colors[0])
		canvas.draw_rect(rect, colors[1], false, 1.0)
		var text_color = Color(0.1, 0.1, 0.1) if colors[0].v > 0.5 else Color(0.7, 0.7, 0.7)
		canvas.draw_text(TITLE_FONT, Vector2(rect.get_center().x, rect.end.y - 3), "E%d" % (i + 1), 10, text_color, HORIZONTAL_ALIGNMENT_CENTER)

	# Keys: white keys 1 3 5 7 on the bottom row, black keys 2 4 6 on the top row
	for i in 7:
		var rect = key_rect(i)
		var black = i % 2 == 1
		var colors = element_colors(i, Color(0.08, 0.08, 0.1) if black else Color(0.78, 0.78, 0.8), active)
		if is_lit(i):
			canvas.draw_rect(rect.grow(4), Color(accent(), 0.4))
		canvas.draw_rect(rect, colors[0])
		canvas.draw_rect(rect, colors[1], false, 2.0)
		var text_color = Color(0.1, 0.1, 0.1) if colors[0].v > 0.5 else Color(0.85, 0.85, 0.85)
		canvas.draw_text(TITLE_FONT, Vector2(rect.get_center().x, rect.end.y - 8), str(i + 1), 14, text_color, HORIZONTAL_ALIGNMENT_CENTER)

	# Analog turntable value, centered at 0
	var meter = flip(METER_RECT)
	canvas.draw_rect(meter, Color(1, 1, 1, 0.08))
	var value = clamp(analog_value(), -1.0, 1.0)
	var middle = meter.position.x + meter.size.x / 2
	var width = value * meter.size.x / 2 * (-1 if player == 2 else 1)
	canvas.draw_rect(Rect2(min(middle, middle + width), meter.position.y, abs(width), meter.size.y), accent())
	canvas.draw_line(Vector2(middle, meter.position.y - 3), Vector2(middle, meter.end.y + 3), Color(1, 1, 1, 0.5), 1.0)

func draw_row(canvas, slot: int, active: bool) -> void:
	var rect = row_rect(slot)
	var action = SLOTS[slot]
	var selected = active and slot == cursor
	var waiting = action == listening
	canvas.draw_rect(rect, ROW)
	if action < ACTIONS.size() and is_lit(action):
		canvas.draw_rect(rect, Color(accent(), 0.35))
	if waiting:
		canvas.draw_rect(rect, Color(ORANGE, 0.45 if blink() else 0.2))
	elif selected:
		canvas.draw_rect(rect, Color(ORANGE, 0.15))
	if selected or waiting:
		canvas.draw_rect(Rect2(rect.position, Vector2(6, rect.size.y)), ORANGE)
	canvas.draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(1, 1, 1, 0.3), 1.0)

	var baseline = rect.position.y + 19
	var label = "ASSIGN ALL" if action == ASSIGN_ALL else "PLAYER SIDE" if action == SIDE else ACTIONS[action][1]
	canvas.draw_text(TITLE_FONT, Vector2(rect.position.x + 16, baseline), label, ROW_FONT_SIZE, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4)

	var text: String
	var value_color = Color.WHITE
	if waiting:
		text = "TURN" if action == ANALOG else "PRESS"
		value_color = YELLOW if blink() else Color.WHITE
	elif action == ASSIGN_ALL:
		text = "START"
		value_color = CYAN
	elif action == SIDE:
		text = "%dP" % player
		value_color = accent()
	else:
		text = binding_text(action)
		if has_conflict(action):
			value_color = CONFLICT
	# The value gets the room left by the label
	var value_right = rect.end.x - 12
	var label_width = TITLE_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FONT_SIZE).x
	var font_size = canvas.fit_size(TITLE_FONT, text, ROW_FONT_SIZE, value_right - rect.position.x - 16 - label_width - 16)
	canvas.draw_text(TITLE_FONT, Vector2(value_right, baseline), text, font_size, value_color, HORIZONTAL_ALIGNMENT_RIGHT, 4)
