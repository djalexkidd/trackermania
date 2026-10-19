extends Control

const ANALOG_STEP = 0.08
const SCROLL_DURATION = 0.16
const CATEGORY_DURATION = 0.22

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
var scroll_offset = 0.0
var scroll_tween: Tween
var category_tween: Tween
var rows_layer: Control

@onready var scrollbar: VScrollBar = $PositionBar

func setup() -> void:
	rows_layer = Control.new()
	rows_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows_layer)
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
	_animate_category_change()
	opened_category = category
	entries.assign([category.get_node("Category")])
	entries.append_array(category.get_node("MusicList").get_children())
	selected_index = 0
	_render()
	grab_focus()

func close_category() -> bool:
	if opened_category == null:
		return false
	_animate_category_change()
	selected_index = categories.find(opened_category)
	opened_category = null
	entries.assign(categories.map(func(category): return category.get_node("Category")))
	_render()
	grab_focus()
	return true

func move_selection(direction: int) -> void:
	if entries.is_empty() or direction == 0:
		return
	var old_index = selected_index
	selected_index = posmod(selected_index + direction, entries.size())
	# Limit large jumps to one screen of motion; ordinary steps retain their exact position.
	var steps = mini(absi(direction), maxi(1, int(ceil(size.y / entries[0].texture_normal.get_height()))))
	var distance = 0.0
	var index = old_index if direction > 0 else selected_index
	for step in steps:
		distance += entries[index].texture_normal.get_height()
		index = posmod(index + 1, entries.size())
	var old_center = floorf((size.y - entries[old_index].texture_normal.get_height()) / 2.0)
	var new_center = floorf((size.y - entries[selected_index].texture_normal.get_height()) / 2.0)
	scroll_offset += distance * signi(direction) + old_center - new_center
	scroll_offset = clampf(scroll_offset, -size.y, size.y)
	if scroll_tween:
		scroll_tween.kill()
	scroll_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	scroll_tween.tween_method(_set_scroll_offset, scroll_offset, 0.0, SCROLL_DURATION)
	_render()

func _set_scroll_offset(value: float) -> void:
	scroll_offset = value
	_render()

func _animate_category_change() -> void:
	if scroll_tween:
		scroll_tween.kill()
	if category_tween:
		category_tween.kill()
	# Preserve the currently displayed rows while the replacement slides into view.
	var outgoing = rows_layer.duplicate(0) as Control
	add_child(outgoing)
	for row in outgoing.get_children():
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade = outgoing.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fade.tween_property(outgoing, "position:x", outgoing.position.x + 48.0, CATEGORY_DURATION)
	fade.tween_property(outgoing, "modulate:a", 0.0, CATEGORY_DURATION)
	fade.chain().tween_callback(outgoing.queue_free)
	move_child(rows_layer, -1)
	rows_layer.position.x = -32.0
	rows_layer.modulate.a = 0.0
	scroll_offset = 0.0
	category_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	category_tween.tween_property(rows_layer, "position:x", 0.0, CATEGORY_DURATION)
	category_tween.tween_property(rows_layer, "modulate:a", 1.0, CATEGORY_DURATION)

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
	var category_height = entries[0].texture_normal.get_height()
	var half_count = int(ceil(size.y / category_height / 2.0)) + int(ceil(absf(scroll_offset) / category_height)) + 1
	var row_count = half_count * 2 + 1
	# Pack the original texture heights edge to edge, including across the loop boundary.
	var row_y = floorf((size.y - entries[selected_index].texture_normal.get_height()) / 2.0) + scroll_offset
	for offset in range(-half_count, 0):
		row_y -= entries[posmod(selected_index + offset, entries.size())].texture_normal.get_height()
	while rows.size() < row_count:
		var row = TextureButton.new()
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.pressed.connect(_on_row_pressed.bind(row))
		rows_layer.add_child(row)
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
		var centered_y = floorf((size.y - source.texture_normal.get_height()) / 2.0)
		var emphasis = clampf(1.0 - absf(row_y - centered_y) / source.texture_normal.get_height(), 0.0, 1.0)
		row.position = Vector2(32.0 * (1.0 - emphasis), row_y)
		row.size = source.texture_normal.get_size()
		row_y += row.size.y
		var brightness = lerpf(0.8, 1.0, emphasis)
		row.modulate = Color(brightness, brightness, brightness)
		# Animation frames only move rows; rebuild labels when their source changes.
		if not row.has_meta("source") or row.get_meta("source") != source:
			row.set_meta("source", source)
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
	var distance = posmod(int(row.get_meta("entry_index")) - selected_index, entries.size())
	if distance > entries.size() / 2:
		distance -= entries.size()
	move_selection(distance)
	grab_focus()
	_on_pressed()

func _on_scrollbar_changed(value: float) -> void:
	if updating_scrollbar:
		return
	move_selection(int(value) - selected_index)
	grab_focus()
