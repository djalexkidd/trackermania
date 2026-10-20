extends Control
class_name ControllerPanel

# One player of the Controller Setup: an IIDX deck that lights up with the inputs,
# and the list of its bindings. Click a button of the deck or a row to assign it.

@export var player := 1

const FONT = preload("res://assets/font/FT2FONT.TTF")
const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")

const P1_COLOR = Color(0, 0.686275, 1)
const P2_COLOR = Color(1, 0.156863, 0)

# [action without the player prefix, label]; "analog_turntable" binds the fwd/rew pair
const ACTIONS = [
	["key1", "KEY 1"], ["key2", "KEY 2"], ["key3", "KEY 3"], ["key4", "KEY 4"],
	["key5", "KEY 5"], ["key6", "KEY 6"], ["key7", "KEY 7"],
	["digital_turntable_fwd", "SCRATCH UP"], ["digital_turntable_rew", "SCRATCH DOWN"],
	["analog_turntable", "ANALOG TT"],
	["start", "E1 START"], ["effect", "E2 EFFECT"], ["vefx", "E3 VEFX"], ["meta", "E4 META"],
]
const ANALOG = 9
const FIRST_E_BUTTON = 10

# Deck layout for 1P, the turntable goes to the right on 2P
const DECK_RECT = Rect2(0, 52, 600, 210)
const TT_CENTER = Vector2(120, 157)
const TT_RADIUS = 88.0
const TT_CENTER_RADIUS = 26.0
const KEY_SIZE = Vector2(40, 64)
const KEY_STEP = 36.0
const KEYS_LEFT = 280.0
const BLACK_KEY_TOP = 100.0
const WHITE_KEY_TOP = 172.0
const E_BUTTON_SIZE = Vector2(34, 16)
const E_BUTTONS_TOP = 78.0
const METER_RECT = Rect2(20, 286, 560, 8)
const LIST_TOP = 306.0

const ROTATION_SPEED = 180.0 # degrees per unit of analog value
const DIGITAL_SPIN = 360.0 # degrees per second while a digital scratch is held
const SCRATCH_LIGHT_MS = 150

# The panel waiting for an input, only one at a time
static var listener: ControllerPanel = null
# Last assignment, the exit combo ignores the buttons held right after
static var last_assign_msec := 0

var accent: Color
var prefix: String
var listening := -1
var assign_all := false
var hover := -1
var rows := []
var status_label: Label

var rotation_angle := 0.0
var previous_value := 0.0
var last_scratch_move := -1000

func _ready() -> void:
	accent = P1_COLOR if player == 1 else P2_COLOR
	prefix = "p%d_" % player
	build_ui()
	update_rows()

func _exit_tree() -> void:
	if listener == self:
		listener = null

# Deck positions are given for 1P, flipped for 2P (turntable on the right)
func flip(rect: Rect2) -> Rect2:
	if player == 2:
		rect.position.x = size.x - rect.position.x - rect.size.x
	return rect

func flip_point(point: Vector2) -> Vector2:
	if player == 2:
		point.x = size.x - point.x
	return point

# The keys move to the left on 2P but stay in the 1~7 order, as on the real deck
func keys_left() -> float:
	return flip(Rect2(KEYS_LEFT, 0, 6 * KEY_STEP + KEY_SIZE.x, 0)).position.x

func key_rect(i: int) -> Rect2:
	var top = BLACK_KEY_TOP if i % 2 == 1 else WHITE_KEY_TOP
	return Rect2(Vector2(keys_left() + i * KEY_STEP, top), KEY_SIZE)

func e_button_rect(i: int) -> Rect2:
	return Rect2(Vector2(keys_left() + 52 + i * (E_BUTTON_SIZE.x + 12), E_BUTTONS_TOP), E_BUTTON_SIZE)

func flat_style(color: Color, border := Color(0, 0, 0, 0), width := 0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

func make_label(text: String, font_size := 16, color := Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func make_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	# No focus: the controller buttons would also drive the GUI while being tested
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", flat_style(Color(1, 1, 1, 0.06), accent.darkened(0.4), 1))
	button.add_theme_stylebox_override("hover", flat_style(Color(accent, 0.3), accent, 1))
	button.add_theme_stylebox_override("pressed", flat_style(Color(accent, 0.6), accent, 1))
	return button

func build_ui() -> void:
	# Header: player side, name, connected pad
	var header = HBoxContainer.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(size.x, 40)
	header.add_theme_constant_override("separation", 14)
	if player == 2:
		header.alignment = BoxContainer.ALIGNMENT_END
	add_child(header)

	var side = Label.new()
	side.text = "%dP" % player
	side.add_theme_font_override("font", TITLE_FONT)
	side.add_theme_font_size_override("font_size", 32)
	side.add_theme_color_override("font_color", accent)

	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "NAME"
	name_edit.max_length = 6
	name_edit.custom_minimum_size = Vector2(130, 0)
	name_edit.text = Global.p1_name if player == 1 else Global.p2_name
	name_edit.add_theme_font_override("font", FONT)
	name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.add_theme_stylebox_override("normal", flat_style(Color(1, 1, 1, 0.06), accent.darkened(0.4), 1))
	name_edit.add_theme_stylebox_override("focus", flat_style(Color(1, 1, 1, 0.06), accent, 2))
	name_edit.text_changed.connect(func(text): Global.set(("p1" if player == 1 else "p2") + "_name", text))
	name_edit.text_submitted.connect(func(_text): name_edit.release_focus())

	var pad = make_label(pad_name(), 16, Color(0.6, 0.6, 0.6))
	pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pad.clip_text = true
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if player == 1 else HORIZONTAL_ALIGNMENT_LEFT
	for child in ([side, name_edit, pad] if player == 1 else [pad, name_edit, side]):
		header.add_child(child)

	# Bindings, two columns
	var grid = GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(0, LIST_TOP)
	grid.size = Vector2(size.x, 0)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	for i in ACTIONS.size():
		var row = Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2((size.x - 12) / 2, 28)
		row.pressed.connect(start_listening.bind(i))
		row.mouse_entered.connect(func(): hover = i)
		row.mouse_exited.connect(func(): if hover == i: hover = -1)
		var name_label = make_label(ACTIONS[i][1], 16, Color(0.75, 0.75, 0.75))
		name_label.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_KEEP_SIZE, 10)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var input_label = make_label("", 16)
		input_label.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_KEEP_SIZE, 10)
		input_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		input_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		row.add_child(input_label)
		grid.add_child(row)
		rows.append({"button": row, "input": input_label})

	# Actions on the whole panel
	var actions = HBoxContainer.new()
	actions.position = Vector2(0, LIST_TOP + 7 * 32 + 10)
	actions.size = Vector2(size.x, 30)
	actions.add_theme_constant_override("separation", 12)
	add_child(actions)
	var all_button = make_button("ASSIGN ALL")
	all_button.custom_minimum_size = Vector2(150, 30)
	all_button.pressed.connect(start_assign_all)
	var reset_button = make_button("DEFAULT")
	reset_button.custom_minimum_size = Vector2(110, 30)
	reset_button.pressed.connect(reset_all)
	status_label = make_label("", 16, accent)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if player == 1 else HORIZONTAL_ALIGNMENT_LEFT
	for child in ([all_button, reset_button, status_label] if player == 1 else [status_label, reset_button, all_button]):
		actions.add_child(child)

# Name of the pad used by this player's keys, if any
func pad_name() -> String:
	for event in InputMap.action_get_events(prefix + "key1"):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			if event.device in Input.get_connected_joypads():
				return Input.get_joy_name(event.device).to_upper()
			return "PAD %d NOT CONNECTED" % (event.device + 1)
	return "KEYBOARD"

func full_action(i: int) -> String:
	return prefix + ACTIONS[i][0] + ("_fwd" if i == ANALOG else "")

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
			var other = "p%d_" % p + ACTIONS[j][0] + ("_fwd" if j == ANALOG else "")
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

func update_rows() -> void:
	for i in rows.size():
		var conflict = has_conflict(i)
		rows[i]["input"].text = binding_text(i)
		rows[i]["input"].add_theme_color_override("font_color", Color(1, 0.3, 0.3) if conflict else Color.WHITE)
	# The other panel may share an input with this one
	for panel in get_tree().get_nodes_in_group("controller_panels"):
		if panel != self:
			panel.refresh_conflicts()

func refresh_conflicts() -> void:
	for i in rows.size():
		rows[i]["input"].add_theme_color_override("font_color", Color(1, 0.3, 0.3) if has_conflict(i) else Color.WHITE)

func _enter_tree() -> void:
	add_to_group("controller_panels")

func start_listening(i: int) -> void:
	if listener != null and listener != self:
		listener.stop_listening()
	listener = self
	listening = i

func stop_listening() -> void:
	listening = -1
	assign_all = false
	if listener == self:
		listener = null

func start_assign_all() -> void:
	start_listening(0)
	assign_all = true

func reset_all() -> void:
	stop_listening()
	for i in ACTIONS.size():
		Global.reset_key_mapping(full_action(i))
		if i == ANALOG:
			Global.reset_key_mapping(prefix + "analog_turntable_rew")
	update_rows()

func assign(event: InputEvent) -> void:
	if listening == ANALOG:
		var reverse = event.duplicate()
		reverse.axis_value = -event.axis_value
		Global.save_key_mapping(prefix + "analog_turntable_fwd", event)
		Global.save_key_mapping(prefix + "analog_turntable_rew", reverse)
	else:
		Global.save_key_mapping(full_action(listening), event)
	last_assign_msec = Time.get_ticks_msec()
	next_assignment()

func next_assignment() -> void:
	update_rows()
	if assign_all and listening < ACTIONS.size() - 1:
		listening += 1
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
	if listener != self or listening < 0:
		return
	if event is InputEventMouse:
		# Right click cancels, other clicks are left to the GUI
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			stop_listening()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		stop_listening()
	elif listening == ANALOG:
		# Only an axis drives the analog turntable, any button skips it
		if event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
			assign(clean_event(event))
		elif (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and not event.echo:
			next_assignment()
		else:
			return
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and not event.is_echo():
		assign(clean_event(event))
	else:
		return
	get_viewport().set_input_as_handled()

# Index of the deck element under a point, -1 if none
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

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = deck_element_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var element = deck_element_at(event.position)
		if element >= 0:
			start_listening(element)
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover >= 0 and not rows[hover]["button"].is_hovered():
		hover = -1

func is_lit(i: int) -> bool:
	if i == ANALOG:
		return Time.get_ticks_msec() - last_scratch_move < SCRATCH_LIGHT_MS
	return Input.is_action_pressed(full_action(i))

func analog_value() -> float:
	return Input.get_action_strength(prefix + "analog_turntable_fwd") - Input.get_action_strength(prefix + "analog_turntable_rew")

func _process(delta: float) -> void:
	var value = analog_value()
	if value != previous_value:
		rotation_angle += (value - previous_value) * ROTATION_SPEED
		previous_value = value
		last_scratch_move = Time.get_ticks_msec()
	if Input.is_action_pressed(prefix + "digital_turntable_fwd"):
		rotation_angle -= DIGITAL_SPIN * delta
	if Input.is_action_pressed(prefix + "digital_turntable_rew"):
		rotation_angle += DIGITAL_SPIN * delta

	# START + VEFX: assign all without a mouse
	if listener == null and Time.get_ticks_msec() - last_assign_msec > 500 and Input.is_action_pressed(prefix + "start") and Input.is_action_just_pressed(prefix + "vefx"):
		start_assign_all()

	var blink = Time.get_ticks_msec() % 500 < 250
	for i in rows.size():
		var row: Button = rows[i]["button"]
		var color = Color(1, 1, 1, 0.05)
		var border = Color(1, 1, 1, 0.12)
		if i == listening:
			color = Color(accent, 0.55 if blink else 0.25)
			border = accent
		elif is_lit(i):
			color = Color(1, 1, 1, 0.35)
		elif i == hover:
			color = Color(accent, 0.2)
			border = accent.darkened(0.2)
		var style = flat_style(color, border, 1)
		for state in ["normal", "hover", "pressed"]:
			row.add_theme_stylebox_override(state, style)

	if listening >= 0:
		var what = ACTIONS[listening][1]
		if listening == ANALOG:
			status_label.text = "MOVE THE TURNTABLE (KEY: SKIP)"
		else:
			status_label.text = "PRESS %s" % what
		status_label.visible = blink or listening == ANALOG
	else:
		status_label.text = "START+VEFX: ASSIGN ALL"
		status_label.visible = true
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if listening >= 0:
		status_label.add_theme_color_override("font_color", accent)
	queue_redraw()

func element_colors(i: int, base: Color) -> Array:
	var blink = Time.get_ticks_msec() % 500 < 250
	var fill = base
	var border = Color(0.55, 0.55, 0.6)
	if is_lit(i):
		fill = Color(1, 1, 1) if base.v > 0.3 else accent.lightened(0.3)
		border = Color.WHITE
	if i == listening:
		border = accent if blink else Color.WHITE
		if not is_lit(i):
			fill = Color(accent, 0.6 if blink else 0.2)
	elif i == hover:
		border = accent
	return [fill, border]

func _draw() -> void:
	var deck = flip(DECK_RECT)
	draw_rect(deck, Color(0.05, 0.06, 0.09))
	draw_rect(deck, accent.darkened(0.5), false, 2.0)
	# Side stripe in the player color, on the turntable side
	draw_rect(flip(Rect2(DECK_RECT.position, Vector2(6, DECK_RECT.size.y))), accent)

	# Turntable
	var center = flip_point(TT_CENTER)
	var scratching = is_lit(ANALOG) or is_lit(7) or is_lit(8)
	if scratching:
		draw_circle(center, TT_RADIUS + 6, Color(accent, 0.35))
	draw_circle(center, TT_RADIUS, Color(0.1, 0.1, 0.12))
	for half in [7, 8]:
		# Upper half is SCRATCH UP, lower half SCRATCH DOWN
		var from = PI if half == 7 else 0.0
		var colors = element_colors(half, Color(0, 0, 0, 0))
		if is_lit(half) or half == listening or half == hover:
			draw_arc(center, TT_RADIUS - 4, from, from + PI, 48, colors[1], 4.0, true)
	draw_arc(center, TT_RADIUS, 0, TAU, 96, Color(0.7, 0.7, 0.75), 2.0, true)
	for r in [TT_RADIUS * 0.82, TT_RADIUS * 0.66]:
		draw_arc(center, r, 0, TAU, 72, Color(0.3, 0.3, 0.35), 1.0, true)
	# Marker rotating with the turntable
	var direction = Vector2.UP.rotated(deg_to_rad(rotation_angle))
	draw_line(center + direction * TT_CENTER_RADIUS, center + direction * (TT_RADIUS - 8), Color.WHITE if scratching else accent, 4.0, true)
	var analog_colors = element_colors(ANALOG, Color(0.18, 0.18, 0.2))
	draw_circle(center, TT_CENTER_RADIUS, analog_colors[0])
	draw_arc(center, TT_CENTER_RADIUS, 0, TAU, 48, analog_colors[1], 2.0, true)
	draw_string(FONT, center + Vector2(-TT_CENTER_RADIUS, 6), "TT", HORIZONTAL_ALIGNMENT_CENTER, TT_CENTER_RADIUS * 2, 16, Color(0.8, 0.8, 0.8))

	# E1~E4
	for i in 4:
		var rect = e_button_rect(i)
		var colors = element_colors(FIRST_E_BUTTON + i, Color(0.12, 0.12, 0.14))
		draw_rect(rect, colors[0])
		draw_rect(rect, colors[1], false, 1.0)
		draw_string(FONT, rect.position + Vector2(0, -4), "E%d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, Color(0.6, 0.6, 0.6))

	# Keys: white keys 1 3 5 7 on the bottom row, black keys 2 4 6 on the top row
	for i in 7:
		var rect = key_rect(i)
		var black = i % 2 == 1
		var colors = element_colors(i, Color(0.08, 0.08, 0.1) if black else Color(0.78, 0.78, 0.8))
		if is_lit(i):
			draw_rect(rect.grow(4), Color(accent, 0.4))
		draw_rect(rect, colors[0])
		draw_rect(rect, colors[1], false, 2.0)
		var text_color = Color(0.1, 0.1, 0.1) if colors[0].v > 0.5 else Color(0.85, 0.85, 0.85)
		draw_string(FONT, rect.position + Vector2(0, rect.size.y - 8), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, text_color)

	# Analog turntable value, centered at 0
	var meter = flip(METER_RECT)
	draw_rect(meter, Color(1, 1, 1, 0.08))
	var value = clamp(analog_value(), -1.0, 1.0)
	var middle = meter.position.x + meter.size.x / 2
	var width = value * meter.size.x / 2 * (-1 if player == 2 else 1)
	draw_rect(Rect2(min(middle, middle + width), meter.position.y, abs(width), meter.size.y), accent)
	draw_line(Vector2(middle, meter.position.y - 3), Vector2(middle, meter.end.y + 3), Color(1, 1, 1, 0.5), 1.0)
	draw_string(FONT, Vector2(meter.position.x, meter.position.y - 3), "ANALOG %+.2f" % analog_value(), HORIZONTAL_ALIGNMENT_RIGHT if player == 2 else HORIZONTAL_ALIGNMENT_LEFT, meter.size.x, 16, Color(0.6, 0.6, 0.6))
