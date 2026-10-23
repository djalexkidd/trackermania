extends Control

# TRAINING panel of IIDX, between the two playfields of main.gd, everything drawn in _draw():
# the difficulty, the first and last measures of the section, the play speed and the repeat.
# The turntable selects a row, the white keys raise its value, the black keys lower it, START plays the section,
# META goes back to the music select. While a row is chosen, the playfields show the chart still at its measure.

signal play_requested

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")

const PANEL_COLOR = Color(0.16, 0.16, 0.18)
const LABEL_CELL = Color(0, 0, 0)
const VALUE_CELL = Color(0.27, 0.27, 0.29)
const ORANGE = Color(1, 0.55, 0.05)
const YELLOW = Color(1, 0.82, 0.1)
const DIM_TEXT = Color(0.55, 0.55, 0.6)
const PANEL_SIZE = Vector2(396, 488)
const HEADER_HEIGHT = 40.0
const ROW_TOP = 120.0
const ROW_HEIGHT = 34.0
const ROW_GAP = 5.0
const LABEL_WIDTH = 180.0
# Rows from the top, OPTION is a title that cannot be selected
const ROWS = ["MODE", "OPTION", "FIRST", "LAST", "SPEED", "REPEAT", "START"]
const ROW_NAMES = {"MODE": "SELECT MODE", "OPTION": "OPTION", "FIRST": "1ST MEASURE", "LAST": "LAST MEASURE",
	"SPEED": "PLAY SPEED", "REPEAT": "REPEAT", "START": "GAME START"}
const HELP = {
	"MODE": "SINGLE, DOUBLE OR BATTLE. E3: DIFFICULTY.",
	"FIRST": "WHITE: LATER, BLACK: EARLIER.",
	"LAST": "WHITE: LATER, BLACK: EARLIER.",
	"SPEED": "SLOWER, AT THE SAME PITCH.",
	"REPEAT": "ON: AGAIN UNTIL META.",
	"START": "START OR A WHITE KEY: PLAY.",
}
const ANALOG_STEP = 0.08
const REPEAT_DELAY = 0.35
const REPEAT_INTERVAL = 0.06
# The chart of the playfields scrolls to the measure chosen
const PREVIEW_SPEED = 12.0
const SOUND_VOLUME_DB = -10.0

# Playfields of main.gd, the first one has the measures
var fields: Array = []
var song_title := ""
# Input is taken once the DECIDE screen is gone, not while a section is played
var enabled := false
var playing := false
# EX score, maximum and judgements of the last section for each player, empty before
var last_results: Array = []
# Frame when the last section ended: its META press does not leave the panel
var resume_frame := -1
var row := 2
var measure_count := 1
var preview_time := -1.0
var analog_previous := [0.0, 0.0]
var analog_remainder := [0.0, 0.0]
var turn_direction := 0
var turn_time := 0.0
# Value key held: +1 or -1, repeated after a while
var value_direction := 0
var value_time := 0.0

var scroll_sound: AudioStreamPlayer
var decide_sound: AudioStreamPlayer
var cancel_sound: AudioStreamPlayer

func _ready() -> void:
	size = PANEL_SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	measure_count = maxi(fields[0].trainingMeasures.size(), 1)
	# A section of another difficulty stays inside the chart
	if Training.last_measure < 1 or Training.last_measure > measure_count:
		Training.last_measure = measure_count
	Training.first_measure = clampi(Training.first_measure, 1, Training.last_measure)
	scroll_sound = add_sound(preload("res://assets/music_select/scroll.wav"))
	decide_sound = add_sound(preload("res://assets/music_select/decide.wav"))
	cancel_sound = add_sound(preload("res://assets/music_select/cancel.wav"))
	for player in [1, 2]:
		analog_previous[player - 1] = analog_value(player)
	preview_time = target_time()

func add_sound(stream: AudioStream) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SOUND_VOLUME_DB
	player.max_polyphony = 4
	add_child(player)
	return player

func _process(delta: float) -> void:
	queue_redraw()
	var steps = poll_turntable(delta)
	if playing:
		return
	update_preview(delta)
	if not enabled or Engine.get_process_frames() == resume_frame:
		return
	if steps != 0:
		move_row(steps)
	for player in [1, 2]:
		var prefix = "p%d_" % player
		if Input.is_action_just_pressed(prefix + "start"):
			start()
			return
		if Input.is_action_just_pressed(prefix + "meta"):
			exit()
			return
		if Input.is_action_just_pressed(prefix + "vefx"):
			change_difficulty(1)
			return
	poll_value_keys(delta)

# The chart of the playfields goes to the measure of the row
func update_preview(delta: float) -> void:
	preview_time = lerpf(preview_time, target_time(), minf(delta * PREVIEW_SPEED, 1.0))
	for field in fields:
		field.previewTime = preview_time
		field.currentSongPos = preview_time
		field.queue_redraw()

func target_time() -> float:
	var measure = Training.last_measure if ROWS[row] == "LAST" else Training.first_measure
	return fields[0].measureTime(measure)

# The previews are gone while the section plays
func hide_preview() -> void:
	for field in fields:
		field.previewTime = -1.0
		field.queue_redraw()

func analog_value(player: int) -> float:
	return Input.get_action_strength("p%d_analog_turntable_fwd" % player) - Input.get_action_strength("p%d_analog_turntable_rew" % player)

# Steps of both turntables: analog motion, or a digital one held with key repeat like the main menu
func poll_turntable(delta: float) -> int:
	var steps = 0
	var direction = 0
	for player in [1, 2]:
		var value = analog_value(player)
		analog_remainder[player - 1] += wrapf(value - analog_previous[player - 1], -1.0, 1.0)
		analog_previous[player - 1] = value
		var player_steps = int(analog_remainder[player - 1] / ANALOG_STEP)
		analog_remainder[player - 1] -= player_steps * ANALOG_STEP
		steps += player_steps
		direction += int(Input.is_action_pressed("p%d_digital_turntable_fwd" % player))
		direction -= int(Input.is_action_pressed("p%d_digital_turntable_rew" % player))
	direction = signi(direction)
	if direction == 0:
		turn_direction = 0
	elif direction != turn_direction:
		turn_direction = direction
		turn_time = 0.3
		steps += direction
	else:
		turn_time -= delta
		if turn_time <= 0.0:
			turn_time += 0.09
			steps += direction
	return steps

# White keys raise the value of the row, black keys lower it, held they repeat
func poll_value_keys(delta: float) -> void:
	var direction = 0
	for player in [1, 2]:
		for key in ["key1", "key3", "key5", "key7"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, key]):
				direction = 1
		for key in ["key2", "key4", "key6"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, key]):
				direction = -1
	if direction != 0:
		value_direction = direction
		value_time = REPEAT_DELAY
		change_value(direction, true)
		return
	if value_direction == 0 or not is_value_key_held(value_direction):
		value_direction = 0
		return
	value_time -= delta
	if value_time <= 0.0:
		value_time += REPEAT_INTERVAL
		change_value(value_direction, false)

func is_value_key_held(direction: int) -> bool:
	var keys = ["key1", "key3", "key5", "key7"] if direction > 0 else ["key2", "key4", "key6"]
	for player in [1, 2]:
		for key in keys:
			if Input.is_action_pressed("p%d_%s" % [player, key]):
				return true
	return false

# Keyboard, for a player without a controller
func _unhandled_input(event: InputEvent) -> void:
	if not enabled or playing or not (event is InputEventKey and event.pressed) or is_player_input(event):
		return
	match event.keycode:
		KEY_UP: move_row(-1)
		KEY_DOWN: move_row(1)
		KEY_RIGHT: change_value(1, not event.echo)
		KEY_LEFT: change_value(-1, not event.echo)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: start()
		KEY_ESCAPE, KEY_BACKSPACE: exit()

# A key bound to a player action is already handled in _process
func is_player_input(event: InputEvent) -> bool:
	for action in InputMap.get_actions():
		if (action.begins_with("p1_") or action.begins_with("p2_")) and event.is_action(action):
			return true
	return false

# The cursor skips the OPTION title
func move_row(steps: int) -> void:
	var index = row
	for _i in absi(steps):
		index = clampi(index + signi(steps), 0, ROWS.size() - 1)
		if ROWS[index] == "OPTION":
			index = clampi(index + signi(steps), 0, ROWS.size() - 1)
	if index == row or ROWS[index] == "OPTION":
		return
	row = index
	scroll_sound.play()

# first is false for a held key: the difficulty and the switches only change on a new press
func change_value(direction: int, first: bool) -> void:
	match ROWS[row]:
		"MODE":
			if first:
				change_mode(direction)
		"FIRST":
			set_measures(Training.first_measure + direction, Training.last_measure, true)
		"LAST":
			set_measures(Training.first_measure, Training.last_measure + direction, false)
		"SPEED":
			var index = clampi(Training.speed_index + direction, 0, Training.SPEEDS.size() - 1)
			if index != Training.speed_index:
				Training.speed_index = index
				scroll_sound.play()
		"REPEAT":
			if first:
				Training.repeat = not Training.repeat
				scroll_sound.play()
		"START":
			if first and direction > 0:
				start()

# The first measure pushes the last one and the other way round
func set_measures(first: int, last: int, moving_first: bool) -> void:
	first = clampi(first, 1, measure_count)
	last = clampi(last, 1, measure_count)
	if moving_first:
		last = maxi(last, first)
	else:
		first = mini(first, last)
	if first == Training.first_measure and last == Training.last_measure:
		return
	Training.first_measure = first
	Training.last_measure = last
	scroll_sound.play()

# Another mode, skipping those without a chart in their style (DOUBLE PLAY needs a DP chart)
func change_mode(direction: int) -> void:
	var mode = Training.current_mode()
	for _i in Training.MODES.size() - 1:
		mode = posmod(mode + direction, Training.MODES.size())
		if Training.mode_chart(mode) != null:
			Training.set_mode(mode)
			reload()
			return

# E3: another difficulty of the song, in the style played
func change_difficulty(direction: int) -> void:
	var charts = Training.style_charts(Global.is_double_play())
	if charts.size() < 2:
		return
	var index = 0
	for i in charts.size():
		if charts[i]["path"] == Loader.file_path and charts[i]["difficulty_name"] == Loader.chart_difficulty:
			index = i
	index = posmod(index + direction, charts.size())
	Loader.file_path = charts[index]["path"]
	Loader.chart_difficulty = charts[index]["difficulty_name"]
	Loader.difficulty_slot = index
	reload()

# The game scene is opened again for the new players or chart, without the DECIDE screen
func reload() -> void:
	Training.reload = true
	enabled = false
	scroll_sound.play()
	get_tree().change_scene_to_file.call_deferred("res://scenes/game/main.tscn")

# The section is over or stopped, the panel takes the input again from the next frame
func section_over(results: Array) -> void:
	last_results = results
	playing = false
	resume_frame = Engine.get_process_frames()

func start() -> void:
	decide_sound.play()
	value_direction = 0
	hide_preview()
	play_requested.emit()

func exit() -> void:
	cancel_sound.play()
	enabled = false
	Training.set_bus_rate(1.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu/music_select.tscn")

# Drawing

func draw_text(at: Vector2, text: String, font_size: int, text_color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(TITLE_FONT, at, text, alignment, width, font_size, text_color)

# Text made smaller until it fits the width
func fit_size(text: String, font_size: int, width: float) -> int:
	while font_size > 8 and TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	return font_size

func draw_centered(rect: Rect2, text: String, font_size: int, text_color: Color) -> void:
	var fitted = fit_size(text, font_size, rect.size.x - 16)
	var baseline = rect.get_center().y + (TITLE_FONT.get_ascent(fitted) - TITLE_FONT.get_descent(fitted)) / 2.0
	draw_text(Vector2(rect.position.x, baseline), text, fitted, text_color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)

func draw_corners(rect: Rect2, length: float, line_color: Color) -> void:
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var dx = length if corner.x == rect.position.x else -length
		var dy = length if corner.y == rect.position.y else -length
		draw_polyline([corner + Vector2(dx, 0), corner, corner + Vector2(0, dy)], line_color, 2.0)

func row_rect(index: int) -> Rect2:
	return Rect2(8, ROW_TOP + index * (ROW_HEIGHT + ROW_GAP), size.x - 16, ROW_HEIGHT)

func row_value(name: String) -> String:
	match name:
		"MODE": return Training.MODES[Training.current_mode()]
		"FIRST": return str(Training.first_measure)
		"LAST": return str(Training.last_measure)
		"SPEED": return Training.speed_name()
		"REPEAT": return "ON" if Training.repeat else "OFF"
	return ""

func _draw() -> void:
	var dim = 0.55 if playing else 1.0
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, false, 2.0)

	# White title plate, like the console menus
	var header = Rect2(6, 6, size.x - 12, HEADER_HEIGHT)
	draw_rect(header, Color.WHITE)
	draw_rect(header, Color(0.6, 0.6, 0.65), false, 2.0)
	draw_text(Vector2(18, header.end.y - 9), "TRAINING", 28, Color(0.25, 0.25, 0.25))
	draw_text(Vector2(16, header.end.y - 11), "TRAINING", 28, Color.BLACK)
	draw_rect(Rect2(16, header.end.y - 6, 250, 2), Color.BLACK)

	# Guide line: what START does now
	var guide = Rect2(14, 52, size.x - 28, 24)
	draw_corners(guide, 8.0, Color.WHITE)
	var parts = [["PRESS ", Color.WHITE], ["START", YELLOW], [" TO PLAY THE SECTION", Color.WHITE]]
	if playing:
		parts = [["PRESS ", Color.WHITE], ["META", YELLOW], [" TO STOP", Color.WHITE]]
	var x = guide.position.x + 14
	draw_rect(Rect2(x, guide.position.y + 7, 10, 10), Color.WHITE, false, 2.0)
	x += 18
	var guide_size = fit_size("".join(parts.map(func(part): return part[0])), 11, guide.end.x - x - 10)
	for part in parts:
		draw_text(Vector2(x, guide.position.y + 17), part[0], guide_size, part[1])
		x += TITLE_FONT.get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, guide_size).x

	# Song title in an orange frame
	var title_rect = Rect2(8, 82, size.x - 16, 30)
	draw_rect(title_rect, Color.BLACK)
	draw_rect(title_rect, ORANGE, false, 3.0)
	draw_centered(title_rect.grow_individual(-14, 0, -14, 0), song_title, 18, Color.WHITE)
	draw_text(Vector2(title_rect.end.x - 16, title_rect.end.y - 7), "]", 20, ORANGE)
	draw_text(Vector2(title_rect.position.x + 6, title_rect.end.y - 7), "[", 20, ORANGE)

	for i in ROWS.size():
		draw_row(i, dim)
	draw_result()
	draw_help()

func draw_row(index: int, dim: float) -> void:
	var name = ROWS[index]
	var rect = row_rect(index)
	if name == "OPTION" or name == "START":
		draw_rect(rect, LABEL_CELL)
		var text_color = YELLOW if name == "START" and index == row and not playing and blink() else Color.WHITE
		if name == "START" and playing:
			text_color = ORANGE if blink() else Color.WHITE
			draw_centered(rect, "NOW PLAYING", 22, text_color)
		else:
			draw_centered(rect, ROW_NAMES[name], 22, Color(text_color, dim if name == "OPTION" else 1.0))
	else:
		var label = Rect2(rect.position, Vector2(LABEL_WIDTH, rect.size.y))
		var value = Rect2(rect.position.x + LABEL_WIDTH + 6, rect.position.y, rect.size.x - LABEL_WIDTH - 6, rect.size.y)
		draw_rect(label, LABEL_CELL)
		draw_rect(value, VALUE_CELL)
		draw_centered(label, ROW_NAMES[name], 18, Color(Color.WHITE, dim))
		draw_centered(value, row_value(name), 22, Color(Color.WHITE, dim))
		# Arrows when the value can change
		if index == row and not playing:
			draw_arrow(Vector2(value.position.x + 14, value.get_center().y), -1)
			draw_arrow(Vector2(value.end.x - 14, value.get_center().y), 1)
	if index == row and not playing:
		draw_rect(rect.grow(3), ORANGE, false, 4.0)

func draw_arrow(at: Vector2, direction: int) -> void:
	draw_colored_polygon([at + Vector2(-5 * direction, -8), at + Vector2(5 * direction, 0), at + Vector2(-5 * direction, 8)], ORANGE)

# EX score and judgements of the last section
func draw_result() -> void:
	var top = row_rect(ROWS.size() - 1).end.y + 8
	var box = Rect2(8, top, size.x - 16, 40)
	draw_rect(box, Color.BLACK)
	if last_results.is_empty():
		draw_centered(box, "NO PLAY YET", 13, DIM_TEXT)
		return
	# BATTLE: one line per player
	if last_results.size() > 1:
		for i in last_results.size():
			var result = last_results[i]
			var line = "%dP  EX %d / %d  (%.2f%%)  COMBO %d" % [result["player"], result["ex"], result["max_ex"], rate(result), result["combo"]]
			draw_text(Vector2(box.position.x + 10, box.position.y + 16 + i * 17), line, fit_size(line, 12, box.size.x - 20), YELLOW if i == 0 else Color.WHITE)
		return
	var last_result = last_results[0]
	var line = "LAST PLAY  EX %d / %d  (%.2f%%)" % [last_result["ex"], last_result["max_ex"], rate(last_result)]
	if last_result["gave_up"]:
		line += "  STOPPED"
	draw_text(Vector2(box.position.x + 10, box.position.y + 16), line, fit_size(line, 12, box.size.x - 20), YELLOW)
	var counts = last_result["counts"]
	var judgements = "PG %d  GR %d  GD %d  BD %d  PR %d  COMBO %d" % [counts["PGreat"], counts["Great"], counts["Good"], counts["Bad"], counts["Poor"], last_result["combo"]]
	draw_text(Vector2(box.position.x + 10, box.position.y + 33), judgements, fit_size(judgements, 12, box.size.x - 20), Color.WHITE)

func rate(result: Dictionary) -> float:
	return result["ex"] * 100.0 / maxi(result["max_ex"], 1)

# EXPLANATION of the row under the cursor
func draw_help() -> void:
	var box = Rect2(8, size.y - 30, size.x - 16, 22)
	draw_rect(box, Color.BLACK)
	var tag_width = TITLE_FONT.get_string_size("EXPLANATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8
	draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(tag_width, box.size.y - 4)), Color.WHITE)
	draw_text(Vector2(box.position.x + 6, box.position.y + 15), "EXPLANATION", 8, Color.BLACK)
	var text = "META: STOP." if playing else HELP.get(ROWS[row], "")
	var left = tag_width + 8
	draw_text(Vector2(box.position.x + left, box.position.y + 15), text, fit_size(text, 10, box.size.x - left - 4), Color.WHITE)

func blink() -> bool:
	return Time.get_ticks_msec() % 500 < 300
