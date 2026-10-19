extends Control

const ROW_HEIGHT = 72.0
const ANALOG_STEP = 0.08

var categories: Array[Control] = []
var entries: Array[Control] = []
var opened_category: Control
var selected_index = 0
var rows: Array[TextureButton] = []
var updating_scrollbar = false
var analog_previous = [0.0, 0.0]
var analog_remainder = [0.0, 0.0]
var repeat_direction = 0
var repeat_time = 0.0

@onready var scrollbar: VScrollBar = $PositionBar

func setup() -> void:
	for category in $Categories.get_children():
		if category.visible:
			categories.append(category)
	$Categories.hide()
	entries.assign(categories.map(func(category): return category.get_node("Category")))
	scrollbar.value_changed.connect(_on_scrollbar_changed)
	resized.connect(_render)
	for player in [1, 2]:
		analog_previous[player - 1] = _analog_value(player)
	_render()
	grab_focus()

func toggle_category(category: Control) -> void:
	if opened_category == category:
		close_category()
		return
	opened_category = category
	entries.assign([category.get_node("Category")])
	entries.append_array(category.get_node("MusicList").get_children())
	selected_index = 0
	_render()
	grab_focus()

func close_category() -> bool:
	if opened_category == null:
		return false
	selected_index = categories.find(opened_category)
	opened_category = null
	entries.assign(categories.map(func(category): return category.get_node("Category")))
	_render()
	grab_focus()
	return true

func move_selection(direction: int) -> void:
	if entries.is_empty():
		return
	selected_index = posmod(selected_index + direction, entries.size())
	_render()

func _on_pressed() -> void:
	if not entries.is_empty():
		entries[selected_index]._on_pressed()

func _gui_input(event: InputEvent) -> void:
	# Pad actions are polled by music select; avoid also triggering Godot's UI actions.
	for player in get_parent().joined_players():
		for action in ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "start", "digital_turntable_fwd", "digital_turntable_rew"]:
			if event.is_action("p%d_%s" % [player, action]):
				accept_event()
				return
	if event.is_action_pressed("ui_down", true):
		move_selection(1)
		accept_event()
	elif event.is_action_pressed("ui_up", true):
		move_selection(-1)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		_on_pressed()
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move_selection(1)
			grab_focus()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_selection(-1)
			grab_focus()
			accept_event()

# The turntable reports an absolute, wrapping position, not a held direction.
func _analog_value(player: int) -> float:
	return Input.get_action_strength("p%d_analog_turntable_fwd" % player) - Input.get_action_strength("p%d_analog_turntable_rew" % player)

func poll_navigation(delta: float, players: Array) -> void:
	var direction = 0
	for player in [1, 2]:
		var value = _analog_value(player)
		var motion = wrapf(value - analog_previous[player - 1], -1.0, 1.0)
		analog_previous[player - 1] = value
		if player not in players:
			analog_remainder[player - 1] = 0.0
			continue
		analog_remainder[player - 1] += motion
		var steps = int(analog_remainder[player - 1] / ANALOG_STEP)
		if steps != 0:
			analog_remainder[player - 1] -= steps * ANALOG_STEP
			move_selection(steps)
		direction += int(Input.is_action_pressed("p%d_digital_turntable_fwd" % player))
		direction -= int(Input.is_action_pressed("p%d_digital_turntable_rew" % player))
	direction = signi(direction)
	if direction == 0:
		repeat_direction = 0
	elif direction != repeat_direction:
		repeat_direction = direction
		repeat_time = 0.3
		move_selection(direction)
	else:
		repeat_time -= delta
		if repeat_time <= 0.0:
			repeat_time += 0.09
			move_selection(direction)

func _render() -> void:
	if entries.is_empty():
		return
	if opened_category != null and selected_index > 0:
		entries[selected_index].update_song_info()
	var half_count = int(ceil(size.y / ROW_HEIGHT / 2.0))
	var row_count = half_count * 2 + 1
	while rows.size() < row_count:
		var row = TextureButton.new()
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.pressed.connect(_on_row_pressed.bind(row))
		add_child(row)
		rows.append(row)
	for slot in rows.size():
		var row = rows[slot]
		row.visible = slot < row_count
		if not row.visible:
			continue
		var offset = slot - half_count
		var index = posmod(selected_index + offset, entries.size())
		var source = entries[index]
		row.set_meta("entry_index", index)
		row.texture_normal = source.texture_normal
		row.position = Vector2(0.0 if offset == 0 else 32.0, (size.y - ROW_HEIGHT) / 2.0 + offset * ROW_HEIGHT)
		row.size = source.texture_normal.get_size()
		row.modulate = Color.WHITE if offset == 0 else Color(0.8, 0.8, 0.8)
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
		for child in source.get_children():
			if child is Label:
				row.add_child(child.duplicate())
	updating_scrollbar = true
	scrollbar.max_value = entries.size()
	scrollbar.page = 1
	scrollbar.value = selected_index
	updating_scrollbar = false
	# Keep the position indicator above the wheel rows.
	move_child(scrollbar, -1)

func _on_row_pressed(row: TextureButton) -> void:
	selected_index = row.get_meta("entry_index")
	_render()
	grab_focus()
	_on_pressed()

func _on_scrollbar_changed(value: float) -> void:
	if updating_scrollbar:
		return
	selected_index = int(value)
	_render()
	grab_focus()
