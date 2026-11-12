extends Control

# CUSTOMIZE menu, like on the console versions of IIDX, everything drawn in _draw():
# a row of choices for the FRAME of the playfield, the TURNTABLE disc, the BACKGROUND of the menus
# and the MUSIC SELECT BGM, with a preview on the left. The turntable moves the cursor through
# all the choices, the white keys set the one under the cursor, the black keys go back to the
# main menu, EFFECT sets the default of the row. Choices are saved in Global (settings.cfg).

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const FONT = preload("res://assets/font/FT2FONT.TTF")
const DEFAULT_BGM = preload("res://assets/bgm/music_select.ogg")
const KEY_FRAME = preload("res://assets/play/p1_frame.png")
const SCRATCH_FRAME = preload("res://assets/play/p1_frame_scratch.png")
const GAUGE = preload("res://assets/play/groove_gauge.png")
const GAUGE_PROGRESS = preload("res://assets/play/progress.png")
# Top bar of the music select, drawn the same way: right aligned, 32 px out of the screen
const INFO_BAR = preload("res://assets/music_select/music_select_info.png")
const INFO_BAR_LEFT = -1888.0
# Tags of the info bar, in its pixels: OPTIONS (replaced by DEFAULT), OK, EXIT
const INFO_TAGS = [Rect2(1313, 14, 189, 79), Rect2(1577, 14, 105, 79), Rect2(1755, 14, 103, 79)]
const BGM_FOLDER = "user://music_select_bgm"

# Dark theme over the background, like the options
const PANEL = Color(0, 0, 0, 0.7)
const PANEL_DARK = Color(0, 0, 0, 0.85)
const ROW = Color(0.1, 0.1, 0.1, 0.95)
const TAG_BORDER = Color(0.45, 0.45, 0.45)
const ORANGE = Color(1, 0.55, 0.05)
const YELLOW = Color(1, 0.82, 0.1)
const CYAN = Color(0.3, 0.9, 1)

const HEADER_HEIGHT = 113.0
const FOOTER_HEIGHT = 64.0
# Preview on the left, rows on the right
const PREVIEW_LEFT = 28.0
const PREVIEW_WIDTH = 330.0
const ROWS_LEFT = 390.0
const ROWS_TOP = 56.0
const TAB_HEIGHT = 22.0
const ROW_GAP = 6.0
const CELL_SIZE = Vector2(130, 66)
const CELL_GAP = 10.0
const SECTION_HEIGHT = 112.0
# MUSIC SELECT BGM: names in a grid, scrolled by rows
const BGM_COLUMNS = 4
const BGM_ROWS = 2
const BGM_CELL_HEIGHT = 34.0
const BGM_CELL_GAP = 6.0

const ANALOG_STEP = 0.08
const NOTICE_TIME = 3.0
const LEAVE_TIME = 0.25
const SOUND_VOLUME_DB = -10.0
const BGM_VOLUME_DB = -6.0
# The BGM under the cursor starts playing after this delay, not while the turntable spins
const BGM_DELAY = 0.3
const BGM_BUS = "Customize"
const SPECTRUM_BARS = 24
const SPECTRUM_MIN_HZ = 50.0
const SPECTRUM_MAX_HZ = 12000.0
const SPECTRUM_MIN_DB = -60.0

# Playfield preview: the part of the 1P playfield shown (from this y to the bottom), notes falling in a loop
const PREVIEW_FIELD_TOP = 120.0
const DEMO_FALL_TIME = 0.8
const DEMO_PERIOD = 2.4
const DEMO_LIGHT_TIME = 0.12
# Time in the loop and lane (0~6 keys, 7 scratch) of each demo note
const DEMO_NOTES = [[0.0, 7], [0.3, 0], [0.6, 2], [0.6, 4], [0.9, 1], [1.2, 3], [1.5, 5], [1.8, 6], [1.8, 0], [2.1, 7], [2.1, 2]]

var sections = [
	{"title": "FRAME", "var": "frame_skin", "kind": "frame", "items": Skins.FRAMES,
		"desc": "COLORS OF THE LANES, THE RAILS AND THE PLATE OF THE PLAYFIELD."},
	{"title": "TURNTABLE", "var": "turntable_skin", "kind": "turntable", "items": Skins.TURNTABLES,
		"desc": "DISC OF THE TURNTABLE, UNDER THE SCRATCH LANE."},
	{"title": "BACKGROUND", "var": "menu_background", "kind": "background", "items": Skins.BACKGROUNDS,
		"desc": "ANIMATED BACKGROUND OF THE MENUS."},
	{"title": "MUSIC SELECT BGM", "var": "custom_music_select_bgm", "kind": "bgm", "items": [{"id": "", "name": "DEFAULT"}],
		"desc": "BGM OF THE MUSIC SELECT. ADD OGG FILES IN THE MUSIC_SELECT_BGM FOLDER."},
]

var section_index = 0
var item_index = 0
# First row of the BGM grid shown
var bgm_scroll = 0
var analog_previous = [0.0, 0.0]
var analog_remainder = [0.0, 0.0]
var repeat_direction = 0
var repeat_time = 0.0
var notice = ""
var notice_until = 0
var leaving = false

var scroll_sound: AudioStreamPlayer
var decide_sound: AudioStreamPlayer
var cancel_sound: AudioStreamPlayer
var bgm: AudioStreamPlayer
# BGM playing, and the one to start when bgm_wait runs out
var bgm_path = null
var bgm_wanted = null
var bgm_wait = 0.0
var spectrum_levels: Array[float] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(BGM_FOLDER)
	for file in Loader.get_all_files(BGM_FOLDER, "ogg"):
		sections[3]["items"].append({"id": file, "name": file.get_file().get_basename().to_upper()})
	scroll_sound = add_sound(preload("res://assets/music_select/scroll.wav"))
	decide_sound = add_sound(preload("res://assets/music_select/decide.wav"))
	cancel_sound = add_sound(preload("res://assets/music_select/cancel.wav"))
	make_bus()
	bgm = add_sound(null)
	bgm.volume_db = BGM_VOLUME_DB
	bgm.bus = BGM_BUS
	spectrum_levels.resize(SPECTRUM_BARS)
	spectrum_levels.fill(0.0)
	# The cursor starts on the frame in use
	item_index = maxi(0, item_ids(0).find(Global.frame_skin))
	for player in [1, 2]:
		analog_previous[player - 1] = analog_value(player)

func add_sound(stream: AudioStream) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SOUND_VOLUME_DB
	player.max_polyphony = 4
	add_child(player)
	return player

# Bus of the BGM preview with a spectrum analyzer, sent to Master (the effector applies)
func make_bus() -> void:
	if AudioServer.get_bus_index(BGM_BUS) != -1:
		return
	AudioServer.add_bus()
	var index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BGM_BUS)
	AudioServer.set_bus_send(index, "Master")
	AudioServer.add_bus_effect(index, AudioEffectSpectrumAnalyzer.new())

func analyzer() -> AudioEffectSpectrumAnalyzerInstance:
	var bus = AudioServer.get_bus_index(BGM_BUS)
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectSpectrumAnalyzer:
			return AudioServer.get_bus_effect_instance(bus, i)
	return null

func _process(delta: float) -> void:
	queue_redraw()
	update_bgm(delta)
	update_spectrum(delta)
	var steps = poll_turntable(delta)
	if leaving:
		return
	if steps != 0:
		turn(steps)
	for player in [1, 2]:
		for key in ["key1", "key3", "key5", "key7"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, key]):
				decide()
				return
		for key in ["key2", "key4", "key6"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, key]):
				back()
				return
		if Input.is_action_just_pressed("p%d_effect" % player):
			restore_default()
			return

func analog_value(player: int) -> float:
	return Input.get_action_strength("p%d_analog_turntable_fwd" % player) - Input.get_action_strength("p%d_analog_turntable_rew" % player)

# Steps of both turntables: analog motion, or a digital one held with key repeat like the song wheel
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
		repeat_direction = 0
	elif direction != repeat_direction:
		repeat_direction = direction
		repeat_time = 0.3
		steps += direction
	else:
		repeat_time -= delta
		if repeat_time <= 0.0:
			repeat_time += 0.09
			steps += direction
	return steps

# Keyboard and mouse, for a player without a controller
func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: turn(-1)
			MOUSE_BUTTON_WHEEL_DOWN: turn(1)
			MOUSE_BUTTON_LEFT: click(event.position)
		return
	if not (event is InputEventKey and event.pressed) or is_player_input(event):
		return
	match event.keycode:
		KEY_LEFT: turn(-1)
		KEY_RIGHT: turn(1)
		KEY_UP: move_vertically(-1)
		KEY_DOWN: move_vertically(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: decide()
		KEY_ESCAPE, KEY_BACKSPACE: back()
		KEY_DELETE: restore_default()

# A key bound to a player action is already handled in _process
func is_player_input(event: InputEvent) -> bool:
	for action in InputMap.get_actions():
		if (action.begins_with("p1_") or action.begins_with("p2_")) and event.is_action(action):
			return true
	return false

func click(at: Vector2) -> void:
	if header_tag_rect(0).has_point(at):
		restore_default()
		return
	if header_tag_rect(1).has_point(at):
		decide()
		return
	if header_tag_rect(2).has_point(at):
		back()
		return
	for s in sections.size():
		for i in sections[s]["items"].size():
			var rect = cell_rect(s, i)
			if rect.size.x > 0 and rect.has_point(at):
				if s == section_index and i == item_index:
					decide()
				else:
					move_to(s, i)
				return

# Items

func items() -> Array:
	return sections[section_index]["items"]

func item_ids(s: int) -> Array:
	return sections[s]["items"].map(func(item): return item["id"])

func hovered_id(s: int) -> String:
	return sections[s]["items"][item_index]["id"] if s == section_index else Global.get(sections[s]["var"])

func equipped_index(s: int) -> int:
	return maxi(0, item_ids(s).find(Global.get(sections[s]["var"])))

# Moves through all the choices, from one row to the next, in a loop
func turn(steps: int) -> void:
	var s = section_index
	var i = item_index + steps
	while i < 0:
		s = posmod(s - 1, sections.size())
		i += sections[s]["items"].size()
	while i >= sections[s]["items"].size():
		i -= sections[s]["items"].size()
		s = posmod(s + 1, sections.size())
	move_to(s, i)

# Up and down: the row above or below, at the same place (the rows of the BGM grid first)
func move_vertically(direction: int) -> void:
	if sections[section_index]["kind"] == "bgm":
		var i = item_index + direction * BGM_COLUMNS
		if i >= 0 and i < items().size():
			move_to(section_index, i)
			return
	var s = section_index + direction
	if s < 0 or s >= sections.size():
		return
	var column = item_index % BGM_COLUMNS if sections[section_index]["kind"] == "bgm" else item_index
	move_to(s, mini(column, sections[s]["items"].size() - 1))

func move_to(s: int, i: int) -> void:
	if s == section_index and i == item_index:
		return
	section_index = s
	item_index = i
	scroll_sound.play()
	if sections[s]["kind"] == "bgm":
		var row = i / BGM_COLUMNS
		bgm_scroll = clampi(bgm_scroll, row - BGM_ROWS + 1, row)

# Sets the choice under the cursor
func decide() -> void:
	var section = sections[section_index]
	var item = items()[item_index]
	decide_sound.play()
	if Global.get(section["var"]) == item["id"]:
		return
	Global.set(section["var"], item["id"])
	Global.save_settings()
	show_notice("%s: %s" % [section["title"], item["name"]])

func back() -> void:
	cancel_sound.play()
	leaving = true
	bgm.stop()
	await get_tree().create_timer(LEAVE_TIME).timeout
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

# EFFECT: the default of the row under the cursor
func restore_default() -> void:
	var section = sections[section_index]
	decide_sound.play()
	Global.set(section["var"], Global.SETTING_DEFAULTS[section["var"]])
	Global.save_settings()
	show_notice("%s: DEFAULT" % section["title"])

func show_notice(text: String) -> void:
	notice = text
	notice_until = Time.get_ticks_msec() + int(NOTICE_TIME * 1000)

# The BGM under the cursor plays while the cursor is on the MUSIC SELECT BGM row
func update_bgm(delta: float) -> void:
	var wanted = null
	if sections[section_index]["kind"] == "bgm" and not leaving:
		wanted = items()[item_index]["id"]
	if wanted != bgm_wanted:
		bgm_wanted = wanted
		bgm_wait = BGM_DELAY
		if wanted != bgm_path:
			bgm.stop()
			bgm_path = null
	if bgm_wanted == null or bgm_wanted == bgm_path:
		return
	bgm_wait -= delta
	if bgm_wait > 0.0:
		return
	var stream: AudioStream = DEFAULT_BGM
	if bgm_wanted != "":
		var custom = AudioStreamOggVorbis.load_from_file(bgm_wanted)
		if custom != null:
			custom.loop = true
			stream = custom
	bgm_path = bgm_wanted
	bgm.stream = stream
	# The default BGM is imported without loop, the music select loops it with its player
	bgm.set("parameters/looping", true)
	bgm.play()

func update_spectrum(delta: float) -> void:
	var instance = analyzer()
	var previous = SPECTRUM_MIN_HZ
	for i in SPECTRUM_BARS:
		var hz = SPECTRUM_MIN_HZ * pow(SPECTRUM_MAX_HZ / SPECTRUM_MIN_HZ, (i + 1.0) / SPECTRUM_BARS)
		var level = 0.0
		if instance != null and bgm.playing:
			var magnitude = instance.get_magnitude_for_frequency_range(previous, hz).length()
			level = clampf((linear_to_db(maxf(magnitude, 1e-6)) - SPECTRUM_MIN_DB) / -SPECTRUM_MIN_DB, 0.0, 1.0)
		previous = hz
		var speed = 18.0 if level > spectrum_levels[i] else 6.0
		spectrum_levels[i] = lerpf(spectrum_levels[i], level, minf(1.0, speed * delta))

# Layout

func body_top() -> float:
	return HEADER_HEIGHT

func body_bottom() -> float:
	return size.y - FOOTER_HEIGHT - 8

func preview_rect() -> Rect2:
	return Rect2(PREVIEW_LEFT, body_top() + 16, PREVIEW_WIDTH, body_bottom() - body_top() - 32)

func section_top(s: int) -> float:
	return body_top() + ROWS_TOP + s * SECTION_HEIGHT

# A choice of a row, empty when it is scrolled out of the BGM grid
func cell_rect(s: int, i: int) -> Rect2:
	var top = section_top(s) + TAB_HEIGHT + ROW_GAP
	if sections[s]["kind"] == "bgm":
		var row = i / BGM_COLUMNS - bgm_scroll
		if row < 0 or row >= BGM_ROWS:
			return Rect2()
		var width = (size.x - ROWS_LEFT - 34 - (BGM_COLUMNS - 1) * CELL_GAP) / BGM_COLUMNS
		return Rect2(ROWS_LEFT + 10 + (i % BGM_COLUMNS) * (width + CELL_GAP), top + 4 + row * (BGM_CELL_HEIGHT + BGM_CELL_GAP), width, BGM_CELL_HEIGHT)
	return Rect2(ROWS_LEFT + 10 + i * (CELL_SIZE.x + CELL_GAP), top + 4, CELL_SIZE.x, CELL_SIZE.y)

# DEFAULT, OK and EXIT in the header
func header_tag_rect(i: int) -> Rect2:
	var tag: Rect2 = INFO_TAGS[i]
	return Rect2(tag.position + Vector2(size.x + INFO_BAR_LEFT, 0), tag.size)

# Drawing

func draw_text(font: Font, position_: Vector2, text: String, font_size: int, text_color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, outline := 0) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x = position_.x - (width if alignment == HORIZONTAL_ALIGNMENT_RIGHT else width / 2 if alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
	if outline > 0:
		draw_string_outline(font, Vector2(x, position_.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color.BLACK)
	draw_string(font, Vector2(x, position_.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

# Text made smaller until it fits the width
func fit_size(font: Font, text: String, font_size: int, width: float) -> int:
	while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	return font_size

func blink() -> bool:
	return Time.get_ticks_msec() % 500 < 300

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _draw() -> void:
	draw_body()
	for s in sections.size():
		draw_section(s)
	draw_preview()
	draw_header()
	draw_footer()

func draw_body() -> void:
	var top = body_top()
	var right = size.x - 20
	draw_rect(Rect2(0, top, size.x, body_bottom() - top), PANEL)
	draw_rect(Rect2(0, top + 4, size.x, 3), ORANGE)
	draw_rect(Rect2(0, body_bottom() - 7, size.x, 3), ORANGE)

	# Help banner, top right
	var help = "TURNTABLE: SELECT    WHITE: SET    BLACK: EXIT    EFFECT: DEFAULT"
	var banner_left = right - 640
	draw_colored_polygon([Vector2(banner_left - 40, top + 12), Vector2(right, top + 12), Vector2(right, top + 46), Vector2(banner_left, top + 46)], YELLOW)
	draw_colored_polygon([Vector2(banner_left - 70, top + 12), Vector2(banner_left - 52, top + 12), Vector2(banner_left - 16, top + 46), Vector2(banner_left - 34, top + 46)], ORANGE)
	draw_rect(Rect2(right - 6, top + 12, 6, 34), Color.BLACK)
	draw_text(TITLE_FONT, Vector2((banner_left + right) / 2, top + 36), help, fit_size(TITLE_FONT, help, 14, right - banner_left - 30), Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)

	# Corner brackets around the rows
	var area = Rect2(ROWS_LEFT - 12, section_top(0) - 6, size.x - ROWS_LEFT - 8, sections.size() * SECTION_HEIGHT + 4)
	for corner in [area.position, Vector2(area.end.x, area.position.y), Vector2(area.position.x, area.end.y), area.end]:
		var dx = 10.0 if corner.x == area.position.x else -10.0
		var dy = 10.0 if corner.y == area.position.y else -10.0
		draw_polyline([corner + Vector2(dx, 0), corner, corner + Vector2(0, dy)], Color.WHITE, 2.0)

# A row: its slanted tab and line, then its choices on a dark band
func draw_section(s: int) -> void:
	var section = sections[s]
	var top = section_top(s)
	var right = size.x - 24
	var current = s == section_index
	var tab_color = ORANGE if current else Color.WHITE
	var title_size = 16
	var tab_width = TITLE_FONT.get_string_size(section["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x + 40
	var band_top = top + TAB_HEIGHT
	var band_bottom = top + SECTION_HEIGHT - 8
	draw_rect(Rect2(ROWS_LEFT, band_top, right - ROWS_LEFT, band_bottom - band_top), PANEL_DARK)
	draw_colored_polygon([Vector2(ROWS_LEFT, top), Vector2(ROWS_LEFT + tab_width, top), Vector2(ROWS_LEFT + tab_width + 18, band_top),
		Vector2(ROWS_LEFT, band_top)], tab_color)
	draw_rect(Rect2(ROWS_LEFT, band_top - 3, right - ROWS_LEFT, 3), tab_color)
	draw_rect(Rect2(ROWS_LEFT + 4, top + 4, 4, TAB_HEIGHT - 8), Color.BLACK)
	draw_text(TITLE_FONT, Vector2(ROWS_LEFT + 16, top + 18), section["title"], title_size, Color.BLACK)

	var equipped = equipped_index(s)
	for i in section["items"].size():
		var rect = cell_rect(s, i)
		if rect.size.x <= 0:
			continue
		draw_cell(s, i, rect, current and i == item_index, i == equipped)
	# More BGM above or below
	if section["kind"] == "bgm":
		var rows = ceili(section["items"].size() / float(BGM_COLUMNS))
		var x = right - 12
		if bgm_scroll > 0:
			draw_colored_polygon([Vector2(x - 6, band_top + 14), Vector2(x + 6, band_top + 14), Vector2(x, band_top + 6)], ORANGE)
		if bgm_scroll + BGM_ROWS < rows:
			draw_colored_polygon([Vector2(x - 6, band_bottom - 14), Vector2(x + 6, band_bottom - 14), Vector2(x, band_bottom - 6)], ORANGE)

func draw_cell(s: int, i: int, rect: Rect2, hovered: bool, equipped: bool) -> void:
	var section = sections[s]
	var item = section["items"][i]
	draw_rect(rect, ROW)
	if section["kind"] == "bgm":
		var name_size = fit_size(FONT, item["name"], 22, rect.size.x - 20)
		draw_text(FONT, Vector2(rect.position.x + 10, rect.get_center().y + name_size * 0.35), item["name"], name_size, YELLOW if hovered else Color.WHITE)
	else:
		draw_thumbnail(section["kind"], item["id"], rect.grow(-3), hovered)
		# Name on a dark strip at the bottom
		var strip = Rect2(rect.position.x, rect.end.y - 16, rect.size.x, 16)
		draw_rect(strip, Color(0, 0, 0, 0.75))
		draw_text(TITLE_FONT, Vector2(strip.get_center().x, strip.end.y - 4), item["name"], 10, YELLOW if hovered else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(rect, TAG_BORDER, false, 1.0)
	# The choice in use: a white tab under it with an arrow, like the console menu
	if equipped:
		var tab = Rect2(rect.get_center().x - 16, rect.end.y, 32, 9)
		if section["kind"] == "bgm":
			tab = Rect2(rect.end.x - 22, rect.position.y + 4, 16, rect.size.y - 8)
			draw_rect(tab, Color.WHITE)
			draw_colored_polygon([Vector2(tab.position.x + 4, tab.get_center().y), Vector2(tab.end.x - 4, tab.get_center().y - 5), Vector2(tab.end.x - 4, tab.get_center().y + 5)], Color.BLACK)
		else:
			draw_rect(tab, Color.WHITE)
			draw_colored_polygon([Vector2(tab.get_center().x, tab.position.y + 1), Vector2(tab.get_center().x + 6, tab.end.y - 1), Vector2(tab.get_center().x - 6, tab.end.y - 1)], Color.BLACK)
	if hovered:
		var cursor_color = YELLOW if leaving or blink() else ORANGE
		draw_rect(rect.grow(2), cursor_color, false, 3.0)

func draw_thumbnail(kind: String, id: String, rect: Rect2, hovered: bool) -> void:
	match kind:
		"frame":
			draw_frame_thumbnail(Skins.find(Skins.FRAMES, id), rect)
		"turntable":
			draw_rect(rect, Color(0.04, 0.04, 0.05))
			var texture = Skins.disc_texture(id)
			var disc_size = rect.size.y - 22
			var angle = now() * TAU * (0.5 if hovered else 0.1)
			draw_set_transform(Vector2(rect.get_center().x, rect.position.y + 4 + disc_size / 2), angle, Vector2.ONE * disc_size / texture.get_width())
			draw_texture(texture, -texture.get_size() / 2)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		"background":
			MenuBackground.draw_background(self, id, rect, now())

# A small playfield in the colors of a frame: lanes, rails, a beam and the plate
func draw_frame_thumbnail(skin: Dictionary, rect: Rect2) -> void:
	var plate_top = rect.end.y - 34
	var lanes = Rect2(rect.position.x + 8, rect.position.y, rect.size.x - 16, plate_top - rect.position.y)
	draw_rect(lanes, skin["lane"])
	var lane_width = lanes.size.x / 8.5
	for i in 8:
		var left = lanes.position.x + (0.0 if i == 0 else (i + 0.5) * lane_width)
		var width = lane_width * (1.5 if i == 0 else 1.0)
		if i > 0 and i % 2 == 0:
			draw_rect(Rect2(left, lanes.position.y, width, lanes.size.y), skin["lane_black"])
		if i == 3:
			draw_polygon(PackedVector2Array([Vector2(left, lanes.position.y + 10), Vector2(left + width, lanes.position.y + 10), Vector2(left + width, lanes.end.y), Vector2(left, lanes.end.y)]),
				PackedColorArray([Color(skin["beam"], 0.0), Color(skin["beam"], 0.0), Color(skin["beam"], 0.7), Color(skin["beam"], 0.7)]))
		draw_line(Vector2(left, lanes.position.y), Vector2(left, lanes.end.y), skin["separator"], 1.0)
	draw_rect(Rect2(lanes.position.x + 1.5 * lane_width, lanes.position.y, 2, lanes.size.y), skin["lane_gap"])
	for x in [rect.position.x, lanes.end.x]:
		draw_polygon(PackedVector2Array([Vector2(x, rect.position.y), Vector2(x + 8, rect.position.y), Vector2(x + 8, plate_top), Vector2(x, plate_top)]),
			PackedColorArray([skin["metal_dark"], skin["metal_light"], skin["metal_light"], skin["metal_dark"]]))
	Playfield.drawMetal(self, PackedVector2Array([Vector2(rect.position.x, plate_top), Vector2(rect.end.x, plate_top), rect.end, Vector2(rect.position.x, rect.end.y)]), skin)
	Playfield.drawScreen(self, Rect2(rect.end.x - 42, plate_top + 3, 36, 12), skin)

# Preview

func draw_preview() -> void:
	var rect = preview_rect()
	draw_rect(rect, Color.BLACK)
	var inner = Rect2(rect.position + Vector2(8, 34), rect.size - Vector2(16, 64))
	var section = sections[section_index]
	match section["kind"]:
		"background":
			MenuBackground.draw_background(self, hovered_id(section_index), inner, now())
		"bgm":
			draw_bgm_preview(inner)
		_:
			draw_field_preview(inner, Skins.find(Skins.FRAMES, hovered_id(0)), Skins.disc_texture(hovered_id(1)))
	draw_rect(inner, TAG_BORDER, false, 1.0)

	# Title tab, and the name of the choice under the cursor
	draw_colored_polygon([rect.position, rect.position + Vector2(150, 0), rect.position + Vector2(168, 24), rect.position + Vector2(0, 24)], ORANGE)
	draw_text(TITLE_FONT, rect.position + Vector2(12, 18), "PREVIEW", 16, Color.BLACK)
	var caption = "%s: %s" % [section["title"], items()[item_index]["name"]]
	var color = Color.WHITE
	if Time.get_ticks_msec() < notice_until:
		caption = "SET  " + notice
		color = YELLOW
	draw_text(TITLE_FONT, Vector2(rect.get_center().x, rect.end.y - 10), caption, fit_size(TITLE_FONT, caption, 14, rect.size.x - 20), color, HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(rect, Color.WHITE, false, 2.0)

# The bottom of the 1P playfield with a frame and a disc, notes falling in a loop
func draw_field_preview(inner: Rect2, skin: Dictionary, disc: Texture2D) -> void:
	# From the outer rail to the right of the plate
	var field_width = Playfield.PLATE_RIGHT + Playfield.RAIL_WIDTH
	var scale_ = minf(inner.size.x / field_width, inner.size.y / (720.0 - PREVIEW_FIELD_TOP))
	var origin = Vector2(inner.get_center().x - field_width * scale_ / 2 + Playfield.RAIL_WIDTH * scale_, inner.end.y - 720.0 * scale_)
	var base = Transform2D(0.0, Vector2.ONE * scale_, 0.0, origin)
	draw_set_transform_matrix(base)

	# The lanes go up to the top of the preview
	var top = maxf(0.0, (inner.position.y - origin.y) / scale_)
	var judge = Playfield.PERFECT_YPOS
	var width = Playfield.PLAYFIELD_WIDTH
	var lane_left = func(lane: int) -> float:
		return 0.0 if lane == 7 else Playfield.SCRATCH_WIDTH + Playfield.SCRATCH_GAP + lane * Playfield.KEY_WIDTH
	var lane_width = func(lane: int) -> float:
		return Playfield.SCRATCH_WIDTH if lane == 7 else Playfield.KEY_WIDTH

	# Lanes lit when a demo note reaches the line
	var time = now()
	var lit = {}
	var falling = []
	for note in DEMO_NOTES:
		var loop = floorf((time - note[0]) / DEMO_PERIOD)
		for k in [loop, loop + 1]:
			var hit = note[0] + k * DEMO_PERIOD
			if time >= hit and time - hit < DEMO_LIGHT_TIME:
				lit[note[1]] = 1.0 - (time - hit) / DEMO_LIGHT_TIME
			elif hit > time and hit - time < DEMO_FALL_TIME:
				falling.append([note[1], judge - (hit - time) / DEMO_FALL_TIME * (judge - top)])

	draw_rect(Rect2(0, top, width, judge - top), skin["lane"])
	draw_rect(Rect2(Playfield.SCRATCH_WIDTH, top, Playfield.SCRATCH_GAP, judge - top), skin["lane_gap"])
	for lane in 8:
		var left = lane_left.call(lane)
		var right = left + lane_width.call(lane)
		if lane < 7 and lane % 2 == 1:
			draw_rect(Rect2(left, top, lane_width.call(lane), judge - top), skin["lane_black"])
		if lit.has(lane):
			var beam: Color = skin["beam"]
			var beam_top = maxf(top, judge - Playfield.LANE_LIGHT_HEIGHT)
			draw_polygon(PackedVector2Array([Vector2(left, beam_top), Vector2(right, beam_top), Vector2(right, judge), Vector2(left, judge)]),
				PackedColorArray([Color(beam, 0.0), Color(beam, 0.0), Color(beam, 0.65), Color(beam, 0.65)]))
		draw_line(Vector2(left, top), Vector2(left, judge), skin["separator"], 1.0)
		draw_line(Vector2(right, top), Vector2(right, judge), skin["separator"], 1.0)
	for note in falling:
		var lane = note[0]
		var color = Note.SCRATCH_NOTE if lane == 7 else Note.BLUE_NOTE if lane % 2 == 1 else Note.WHITE_NOTE
		draw_rect(Rect2(lane_left.call(lane) + Playfield.NOTE_MARGIN, note[1] - 3, lane_width.call(lane) - 2 * Playfield.NOTE_MARGIN, 6), color)
	for x in [-Playfield.RAIL_WIDTH, width]:
		draw_rail(skin, x, top)

	Playfield.drawMetal(self, PackedVector2Array([Vector2(-Playfield.RAIL_WIDTH, Playfield.PLATE_TOP), Vector2(392, Playfield.PLATE_TOP), Vector2(404, 512),
		Vector2(Playfield.PLATE_RIGHT, 512), Vector2(Playfield.PLATE_RIGHT, 708), Vector2(476, 720), Vector2(-Playfield.RAIL_WIDTH, 720)]), skin)
	for screen in [Playfield.PERCENT_SCREEN, Playfield.GAUGE_SCREEN, Playfield.SCORE_SCREEN, Playfield.DIFFICULTY_SCREEN]:
		Playfield.drawScreen(self, screen, skin)
	for screw in [Vector2(Playfield.PLATE_RIGHT - 7, 519), Vector2(Playfield.PLATE_RIGHT - 7, 627), Vector2(284, 627), Vector2(-6, 627)]:
		Playfield.drawScrew(self, screw, skin)
	# Gauge at 80 %, score and max combo
	var gauge = Playfield.GAUGE_RECT
	draw_texture_rect(GAUGE, gauge, false)
	draw_texture_rect_region(GAUGE_PROGRESS, Rect2(gauge.position, Vector2(gauge.size.x * 0.8, gauge.size.y)), Rect2(0, 0, GAUGE_PROGRESS.get_width() * 0.8, GAUGE_PROGRESS.get_height()))
	draw_string(Playfield.FONT, Vector2(Playfield.GAUGE_SCREEN.position.x + 4, Playfield.GAUGE_LABEL_Y), "P1 GROOVE GAUGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Playfield.GAUGE_LABEL_COLOR)
	var percent = Playfield.PERCENT_SCREEN
	Playfield.drawNumber(self, Vector2(percent.end.x - 22, percent.position.y + 32), 80, 3, 19)
	var score = Playfield.SCORE_SCREEN
	var demo_score = int(time * 40.0) % 10000
	for row in 2:
		var baseline = score.position.y + 33 + row * 37
		draw_string(Playfield.FONT, Vector2(score.position.x + 10, baseline - 6), ["SCORE", "MAXCOMBO"][row], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Playfield.LABEL_COLOR)
		Playfield.drawNumber(self, Vector2(score.end.x - 10, baseline), demo_score if row == 0 else demo_score / 2, [5, 4][row], 24)

	# Keys and scratch frames, the lit keys in red like in the game
	var key_origin = Vector2(lane_left.call(0) + Playfield.KEY_WIDTH / 2 - Playfield.FRAME_FIRST_KEY_X * Playfield.KEY_SCALE, Playfield.KEYS_TOP)
	var key_scale = Vector2(Playfield.KEY_SCALE, Playfield.KEY_SCALE_Y)
	draw_texture_rect(KEY_FRAME, Rect2(key_origin, KEY_FRAME.get_size() * key_scale), false, skin["keys"])
	for lane in 7:
		if not lit.has(lane):
			continue
		var white = lane % 2 == 0
		var region: Rect2 = Playfield.KEY_WHITE_RECT if white else Playfield.KEY_BLACK_RECT
		region.position.x += Playfield.KEY_SPACING * floorf(lane / 2.0)
		draw_texture_rect_region(KEY_FRAME, Rect2(key_origin + region.position * key_scale, region.size * key_scale), region,
			Playfield.KEY_LIGHT_WHITE if white else Playfield.KEY_LIGHT_BLACK)
	draw_texture_rect(SCRATCH_FRAME, Rect2(0, Playfield.KEYS_TOP, Playfield.SCRATCH_WIDTH, Playfield.SCRATCH_HEIGHT), false,
		Playfield.KEY_LIGHT_WHITE if lit.has(7) else skin["keys"])
	# The disc turns faster for a moment on each scratch note
	var frame_scale = Vector2(Playfield.SCRATCH_WIDTH, Playfield.SCRATCH_HEIGHT) / Playfield.SCRATCH_ART_SIZE
	var angle = time * TAU * Playfield.DISC_SPEED + lit.get(7, 0.0) * 0.8
	var at = Vector2(0, Playfield.KEYS_TOP) + Playfield.SCRATCH_HOLE_CENTER * frame_scale
	draw_set_transform_matrix(base * Transform2D(angle, Vector2.ONE * frame_scale.x, 0.0, at))
	draw_texture(disc, -disc.get_size() / 2)
	draw_set_transform_matrix(base)

	# Bursts on the judge line
	for lane in lit:
		var center = Vector2(lane_left.call(lane) + lane_width.call(lane) / 2, judge)
		var f: float = lit[lane]
		draw_circle(center, 30.0 * (1.5 - f * 0.5), Color(skin["burst"], 0.15 * f))
		draw_circle(center, 20.0 * (1.5 - f * 0.5), Color(skin["burst"], 0.35 * f))
	draw_set_transform_matrix(Transform2D.IDENTITY)

# A rounded metal rail beside the lanes, like the playfield
func draw_rail(skin: Dictionary, left: float, top: float) -> void:
	var mid = left + Playfield.RAIL_WIDTH / 2.0
	var right = left + Playfield.RAIL_WIDTH
	var bottom = Playfield.PLATE_TOP
	var light: Color = skin["metal_light"]
	var dark: Color = skin["metal_dark"]
	draw_polygon(PackedVector2Array([Vector2(left, top), Vector2(mid, top), Vector2(mid, bottom), Vector2(left, bottom)]), PackedColorArray([dark, light, light, dark]))
	draw_polygon(PackedVector2Array([Vector2(mid, top), Vector2(right, top), Vector2(right, bottom), Vector2(mid, bottom)]), PackedColorArray([light, dark, dark, light]))
	draw_line(Vector2(left, top), Vector2(left, bottom), skin["metal_edge"], 1.0)
	draw_line(Vector2(right, top), Vector2(right, bottom), skin["metal_edge"], 1.0)

# The background in use, NOW PLAYING and the spectrum of the BGM under the cursor
func draw_bgm_preview(inner: Rect2) -> void:
	MenuBackground.draw_background(self, Global.menu_background, inner, now())
	draw_rect(inner, Color(0, 0, 0, 0.55))
	var name_ = items()[item_index]["name"]
	draw_text(TITLE_FONT, Vector2(inner.get_center().x, inner.position.y + 60), "NOW PLAYING" if bgm.playing else "LOADING", 20, ORANGE if blink() or not bgm.playing else YELLOW, HORIZONTAL_ALIGNMENT_CENTER, 6)
	draw_text(FONT, Vector2(inner.get_center().x, inner.position.y + 100), name_, fit_size(FONT, name_, 30, inner.size.x - 30), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6)
	# Bars in segments, like the groove gauge
	var area = Rect2(inner.position.x + 16, inner.position.y + 140, inner.size.x - 32, inner.size.y - 170)
	var bar_width = area.size.x / SPECTRUM_BARS
	const SEGMENT = 8.0
	var segments = int(area.size.y / SEGMENT)
	for i in SPECTRUM_BARS:
		var lit_segments = int(spectrum_levels[i] * segments)
		for k in segments:
			var y = area.end.y - (k + 1) * SEGMENT
			var color = Color(ORANGE, 0.12)
			if k < lit_segments:
				color = YELLOW if k > segments * 0.8 else ORANGE
			draw_rect(Rect2(area.position.x + i * bar_width + 1, y + 1, bar_width - 2, SEGMENT - 2), color)

func draw_header() -> void:
	draw_texture(INFO_BAR, Vector2(size.x + INFO_BAR_LEFT, 0))
	draw_text(TITLE_FONT, Vector2(16, 16 + TITLE_FONT.get_ascent(32)), "customize", 32, Color.WHITE)
	# DEFAULT with the EFFECT button, over the OPTIONS tag of the bar
	var tag = header_tag_rect(0)
	draw_rect(Rect2(tag.position - Vector2(10, 14), tag.size + Vector2(20, 14)), Color.BLACK)
	draw_spaced(Vector2(tag.get_center().x, tag.position.y + 18), "DEFAULT", 16)
	var box = Rect2(tag.position + Vector2(0, 24), Vector2(tag.size.x, tag.size.y - 24))
	draw_rect(box, TAG_BORDER, false, 2.0)
	draw_spaced(Vector2(box.get_center().x, box.position.y + 23), "EFFECT", 16)
	draw_spaced(Vector2(box.get_center().x, box.position.y + 46), "BUTTON", 16)

# Centered capitals spread out like the text of the info bar
func draw_spaced(center_baseline: Vector2, text: String, font_size: int) -> void:
	const SPACING = 6.0
	var width = 0.0
	for letter in text:
		width += TITLE_FONT.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + SPACING
	var x = center_baseline.x - (width - SPACING) / 2
	for letter in text:
		draw_string(TITLE_FONT, Vector2(x, center_baseline.y), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		x += TITLE_FONT.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + SPACING

func draw_footer() -> void:
	draw_rect(Rect2(0, body_bottom(), size.x, size.y - body_bottom()), Color.BLACK)
	draw_rect(Rect2(0, body_bottom(), size.x, 4), Color.RED)
	var bar = Rect2(20, body_bottom() + 10, size.x - 40, FOOTER_HEIGHT - 8)
	draw_rect(bar, TAG_BORDER, false, 2.0)
	var text = sections[section_index]["desc"]
	var font_size = fit_size(FONT, text, 32, bar.size.x - 40)
	draw_text(FONT, Vector2(bar.get_center().x, bar.get_center().y + font_size * 0.35), text, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
