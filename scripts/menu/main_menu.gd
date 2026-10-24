extends Control

# MENU SELECT, like on the console versions of IIDX, everything drawn in _draw():
# the turntable selects a mode, the white keys decide, the black keys quit (pressed twice).

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const DEFAULT_BGM = preload("res://assets/bgm/music_select.ogg")
# Top bar of the music select, drawn the same way: right aligned, 32 px out of the screen
const INFO_BAR = preload("res://assets/music_select/music_select_info.png")
const INFO_BAR_LEFT = -1888.0
# Tags of the info bar, in its pixels: OPTIONS (hidden), OK, EXIT
const INFO_TAGS = [Rect2(1313, 14, 189, 79), Rect2(1577, 14, 105, 79), Rect2(1755, 14, 103, 79)]

# Dark theme over the scrolling grid, like the options
const PANEL = Color(0, 0, 0, 0.7)
const ROW = Color(0.05, 0.05, 0.05)
const TAG_BORDER = Color(0.45, 0.45, 0.45)
const ORANGE = Color(1, 0.55, 0.05)
const DARK_ORANGE = Color(0.45, 0.18, 0)
const YELLOW = Color(1, 0.82, 0.1)
const PALE_BLUE = Color(0.6, 0.7, 1)

const HEADER_HEIGHT = 113.0
const FOOTER_HEIGHT = 64.0
const SCREEN_TOP = 92.0
const SCREEN_HEIGHT = 230.0
const TAB_HEIGHT = 44.0
const TAB_GAP = 18.0
const TABS_MARGIN = 100.0
const ANALOG_STEP = 0.08
const TITLE_SLIDE_TIME = 0.2
const NOTICE_TIME = 3.0
const LEAVE_TIME = 0.35
const SOUND_VOLUME_DB = -10.0
const BGM_VOLUME_DB = -6.0

var modes = [
	{"name": "ARCADE", "short": "ARCADE", "icon": "arcade", "scene": "res://scenes/menu/music_select.tscn", "arcade": true, "desc": "PLAY 3 STAGES IN A ROW, THEN ENTER THE RANKING."},
	{"name": "FREE", "short": "FREE", "icon": "free", "scene": "res://scenes/menu/music_select.tscn", "desc": "PLAY THE SONGS YOU WANT, FREELY."},
	{"name": "NETPLAY", "short": "NET", "icon": "netplay", "scene": "res://scenes/netplay/lobby.tscn", "desc": "PLAY AGAINST OTHER DJS ON THE NETWORK."},
	{"name": "TRAINING", "short": "TRAIN", "icon": "training", "scene": "res://scenes/menu/music_select.tscn", "training": true, "desc": "PRACTICE A SECTION OF A SONG, AT NORMAL SPEED OR SLOWER."},
	{"name": "EDITOR", "short": "EDIT", "icon": "editor", "scene": "res://scenes/editor/editor.tscn", "desc": "CREATE AND EDIT KEYSOUNDED BMS CHARTS FROM YOUR SONGS."},
	{"name": "OPTIONS", "short": "OPTION", "icon": "options", "scene": "res://scenes/menu/options.tscn", "desc": "DISPLAY, SOUND, DJ NAME AND CONTROLLERS."},
	{"name": "DOWNLOAD", "short": "DL", "icon": "download", "scene": "res://scenes/menu/download.tscn", "desc": "IMPORT NEW SONGS INTO THE GAME."},
]

# Wireframe cubes behind the mode title: center (fraction of the screen), size, spin
const CUBES = [
	[Vector2(0.1, 0.3), 46.0, Vector3(0.3, 0.5, 0.1)],
	[Vector2(0.24, 0.75), 30.0, Vector3(-0.4, 0.2, 0.3)],
	[Vector2(0.47, 0.18), 26.0, Vector3(0.2, -0.6, 0.2)],
	[Vector2(0.8, 0.35), 40.0, Vector3(-0.3, 0.4, -0.2)],
	[Vector2(0.93, 0.72), 34.0, Vector3(0.5, 0.3, 0.4)],
]
# Orange bands crossing the screen: a point (fraction of the screen), angle, width
const BANDS = [
	[Vector2(0.2, 0.9), -0.3, 22.0],
	[Vector2(0.65, 1.0), 0.22, 30.0],
	[Vector2(0.4, 0.15), 0.12, 8.0],
	[Vector2(0.9, 0.2), -0.45, 12.0],
]

var mode_index = 1
var analog_previous = [0.0, 0.0]
var analog_remainder = [0.0, 0.0]
var repeat_direction = 0
var repeat_time = 0.0
# Slide of the mode title, 1 when it arrives, 0 in place
var title_slide = 0.0
var title_tween: Tween
var notice = ""
var notice_until = 0
# A black key asks to quit, a second one quits
var exit_until = 0
var leaving = false

var scroll_sound: AudioStreamPlayer
var decide_sound: AudioStreamPlayer
var cancel_sound: AudioStreamPlayer
var bgm: AudioStreamPlayer

func _ready() -> void:
	# The effector chosen in the music select lasts until the main menu
	Effector.set_effect(0)
	# Back to the default: player 1 only, player 2 has to press start in the music select
	Global.p1_joined = true
	Global.p2_joined = false
	Arcade.stop()
	Training.stop()

	scroll_sound = add_sound(preload("res://assets/music_select/scroll.wav"))
	decide_sound = add_sound(preload("res://assets/music_select/decide.wav"))
	cancel_sound = add_sound(preload("res://assets/music_select/cancel.wav"))
	bgm = add_sound(DEFAULT_BGM)
	bgm.volume_db = BGM_VOLUME_DB
	# BGM disabled for now
	#if Global.custom_music_select_bgm != "":
	#	bgm.stream = AudioStreamOggVorbis.load_from_file(Global.custom_music_select_bgm)
	#	bgm.stream.loop = true
	#bgm.play()
	for player in [1, 2]:
		analog_previous[player - 1] = analog_value(player)
	animate_title()

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
		KEY_LEFT, KEY_UP: turn(-1)
		KEY_RIGHT, KEY_DOWN: turn(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: decide()
		KEY_ESCAPE, KEY_BACKSPACE: back()

# A key bound to a player action is already handled in _process
func is_player_input(event: InputEvent) -> bool:
	for action in InputMap.get_actions():
		if (action.begins_with("p1_") or action.begins_with("p2_")) and event.is_action(action):
			return true
	return false

func click(at: Vector2) -> void:
	if header_tag_rect(1).has_point(at):
		decide()
	elif header_tag_rect(2).has_point(at):
		back()
	elif at.y > tabs_top() - 20 and at.y < tabs_top() + TAB_HEIGHT + 20:
		if at.x < TABS_MARGIN:
			turn(-1)
		elif at.x > size.x - TABS_MARGIN:
			turn(1)
		for i in modes.size():
			if tab_rect(i).has_point(at):
				if i == mode_index:
					decide()
				else:
					turn(i - mode_index)
				return

func turn(steps: int) -> void:
	var index = posmod(mode_index + steps, modes.size())
	if index == mode_index:
		return
	mode_index = index
	exit_until = 0
	scroll_sound.play()
	animate_title()

func decide() -> void:
	var mode = modes[mode_index]
	if not mode.has("scene"):
		cancel_sound.play()
		show_notice("%s MODE IS COMING SOON" % mode["name"])
		return
	decide_sound.play()
	leaving = true
	if mode.get("arcade", false):
		Arcade.start()
	if mode.get("training", false):
		Training.start()
	await get_tree().create_timer(LEAVE_TIME).timeout
	get_tree().change_scene_to_file(mode["scene"])

func back() -> void:
	cancel_sound.play()
	if OS.has_feature("web"):
		return
	if Time.get_ticks_msec() < exit_until:
		get_tree().quit()
		return
	exit_until = Time.get_ticks_msec() + int(NOTICE_TIME * 1000)
	show_notice("PRESS A BLACK KEY AGAIN TO EXIT")

func show_notice(text: String) -> void:
	notice = text
	notice_until = Time.get_ticks_msec() + int(NOTICE_TIME * 1000)

func animate_title() -> void:
	if title_tween:
		title_tween.kill()
	title_slide = 1.0
	title_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	title_tween.tween_property(self, "title_slide", 0.0, TITLE_SLIDE_TIME)

# Layout

func body_top() -> float:
	return HEADER_HEIGHT

func body_bottom() -> float:
	return size.y - FOOTER_HEIGHT - 8

func screen_rect() -> Rect2:
	return Rect2(40, body_top() + SCREEN_TOP, size.x - 80, SCREEN_HEIGHT)

func tabs_top() -> float:
	return screen_rect().end.y + 28

func tab_rect(i: int) -> Rect2:
	var width = (size.x - TABS_MARGIN * 2 - TAB_GAP * (modes.size() - 1)) / modes.size()
	return Rect2(TABS_MARGIN + i * (width + TAB_GAP), tabs_top(), width, TAB_HEIGHT)

# OK and EXIT in the header
func header_tag_rect(i: int) -> Rect2:
	var tag: Rect2 = INFO_TAGS[i]
	return Rect2(tag.position + Vector2(size.x + INFO_BAR_LEFT, 0), tag.size)

# Drawing

func draw_text(position_: Vector2, text: String, font_size: int, text_color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, outline_color := Color.BLACK) -> void:
	var width = TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x = position_.x - (width if alignment == HORIZONTAL_ALIGNMENT_RIGHT else width / 2 if alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
	if outline > 0:
		draw_string_outline(TITLE_FONT, Vector2(x, position_.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
	draw_string(TITLE_FONT, Vector2(x, position_.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

# Text made smaller until it fits the width
func fit_size(text: String, font_size: int, width: float) -> int:
	while font_size > 8 and TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	return font_size

func blink() -> bool:
	return Time.get_ticks_msec() % 500 < 300

func _draw() -> void:
	draw_body()
	draw_screen()
	draw_tabs()
	draw_header()
	draw_footer()

func draw_body() -> void:
	var top = body_top()
	var right = size.x - 20
	draw_rect(Rect2(0, top, size.x, body_bottom() - top), PANEL)
	draw_rect(Rect2(0, top + 4, size.x, 3), ORANGE)

	# Help banner, top right
	var help = "TURNTABLE: SELECT    KEYS: DECIDE"
	var banner_left = right - 520
	draw_colored_polygon([Vector2(banner_left - 40, top + 14), Vector2(right, top + 14), Vector2(right, top + 52), Vector2(banner_left, top + 52)], YELLOW)
	draw_colored_polygon([Vector2(banner_left - 70, top + 14), Vector2(banner_left - 52, top + 14), Vector2(banner_left - 12, top + 52), Vector2(banner_left - 30, top + 52)], ORANGE)
	draw_rect(Rect2(right - 6, top + 14, 6, 38), Color.BLACK)
	draw_text(Vector2((banner_left + right) / 2, top + 40), help, fit_size(help, 14, right - banner_left - 30), Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)

	# Notice (coming soon, exit), top left
	if Time.get_ticks_msec() < notice_until:
		draw_text(Vector2(56, top + 42), notice, 12, YELLOW)

	draw_rect(Rect2(0, body_bottom() - 7, size.x, 3), ORANGE)

func draw_corners(rect: Rect2, length: float, line_color: Color) -> void:
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var dx = length if corner.x == rect.position.x else -length
		var dy = length if corner.y == rect.position.y else -length
		draw_polyline([corner + Vector2(dx, 0), corner, corner + Vector2(0, dy)], line_color, 2.0)

# MENU INFORMATION: black screen with orange wireframes, the mode title and its description
func draw_screen() -> void:
	var screen = screen_rect()
	var time = Time.get_ticks_msec() / 1000.0
	draw_rect(screen, Color.BLACK)

	var screen_polygon = PackedVector2Array([screen.position, Vector2(screen.end.x, screen.position.y), screen.end, Vector2(screen.position.x, screen.end.y)])
	for band in BANDS:
		var center = screen.position + screen.size * band[0]
		var direction = Vector2.from_angle(band[1] + sin(time * 0.3 + center.x) * 0.03)
		var normal = direction.orthogonal() * band[2] / 2
		var reach = direction * screen.size.x
		var polygon = PackedVector2Array([center - reach - normal, center + reach - normal, center + reach + normal, center - reach + normal])
		for part in Geometry2D.intersect_polygons(polygon, screen_polygon):
			draw_colored_polygon(part, Color(ORANGE, 0.75))

	for cube in CUBES:
		draw_cube(screen, screen.position + screen.size * cube[0], cube[1], cube[2] * time)

	draw_text(screen.position + Vector2(10, 18), "MENU INFORMATION", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4)
	draw_rect(screen, Color.WHITE, false, 2.0)

	# Big slanted title, sliding in
	var mode = modes[mode_index]
	var alpha = 1.0 - title_slide
	var font_size = fit_size(mode["name"], 96, screen.size.x - 160)
	var width = TITLE_FONT.get_string_size(mode["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin = Vector2(screen.get_center().x + title_slide * 160, screen.position.y + 150)
	draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, -0.3, origin))
	var at = Vector2(-width / 2, 0)
	draw_string_outline(TITLE_FONT, at + Vector2(0, 6), mode["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 20, Color(0, 0, 0, alpha))
	draw_string_outline(TITLE_FONT, at, mode["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 14, Color(DARK_ORANGE, alpha))
	draw_string(TITLE_FONT, at + Vector2(0, 5), mode["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(ORANGE, alpha))
	draw_string_outline(TITLE_FONT, at, mode["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(ORANGE, alpha))
	draw_string(TITLE_FONT, at, mode["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(YELLOW, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)

	var desc_size = fit_size(mode["desc"], 22, screen.size.x - 80)
	draw_text(Vector2(screen.get_center().x, screen.end.y - 30), mode["desc"], desc_size, Color(PALE_BLUE, alpha), HORIZONTAL_ALIGNMENT_CENTER, 8, Color(0, 0, 0.15, alpha))

# Dotted wireframe cube, clipped to the screen
func draw_cube(screen: Rect2, center: Vector2, radius: float, rotation_: Vector3) -> void:
	var basis = Basis.from_euler(rotation_)
	var points = []
	for i in 8:
		var vertex = basis * Vector3(1 if i & 1 else -1, 1 if i & 2 else -1, 1 if i & 4 else -1)
		points.append(center + Vector2(vertex.x, vertex.y) * radius * (1.0 + vertex.z * 0.15))
	for a in 8:
		for bit in [1, 2, 4]:
			if a & bit == 0:
				var segment = clip_segment(points[a], points[a | bit], screen)
				if not segment.is_empty():
					draw_dashed_line(segment[0], segment[1], Color(ORANGE, 0.8), 2.0, 4.0)

# Part of a segment inside a rectangle (Liang-Barsky), empty if outside
func clip_segment(a: Vector2, b: Vector2, rect: Rect2) -> Array:
	var d = b - a
	var t0 = 0.0
	var t1 = 1.0
	for edge in [[-d.x, a.x - rect.position.x], [d.x, rect.end.x - a.x], [-d.y, a.y - rect.position.y], [d.y, rect.end.y - a.y]]:
		if edge[0] == 0.0:
			if edge[1] < 0.0:
				return []
			continue
		var t = edge[1] / edge[0]
		if edge[0] < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
	if t0 > t1:
		return []
	return [a + d * t0, a + d * t1]

func draw_tabs() -> void:
	var first = tab_rect(0)
	var last = tab_rect(modes.size() - 1)
	draw_corners(Rect2(first.position.x - 24, first.position.y - 14, last.end.x - first.position.x + 48, TAB_HEIGHT + 28), 10.0, Color.WHITE)

	# Arrows on both sides
	var bob = sin(Time.get_ticks_msec() / 150.0) * 4
	var middle = first.get_center().y
	draw_chevron(Vector2(TABS_MARGIN - 52 - bob, middle), -1)
	draw_chevron(Vector2(size.x - TABS_MARGIN + 52 + bob, middle), 1)

	for i in modes.size():
		if i != mode_index:
			var rect = tab_rect(i)
			draw_rect(Rect2(rect.position + Vector2(6, 6), rect.size), Color(0, 0, 0, 0.5))
			draw_rect(rect, ROW)
			draw_text(Vector2(rect.get_center().x, rect.get_center().y + 10), modes[i]["name"], fit_size(modes[i]["name"], 24, rect.size.x - 20), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	draw_selected_tab()

func draw_chevron(at: Vector2, direction: int) -> void:
	draw_colored_polygon([at + Vector2(-8 * direction, -18), at + Vector2(4 * direction, -18), at + Vector2(16 * direction, 0), at + Vector2(4 * direction, 18), at + Vector2(-8 * direction, 18), at + Vector2(4 * direction, 0)], ORANGE)

# Orange frame of the selected mode, hanging below its tab with its icon and DECIDE?
func draw_selected_tab() -> void:
	var rect = tab_rect(mode_index)
	var frame_color = YELLOW if leaving and Time.get_ticks_msec() % 100 < 50 else ORANGE
	var frame = Rect2(rect.position - Vector2(12, 14), Vector2(rect.size.x + 24, rect.size.y + 112))
	var notch = frame.position.x + 60
	var outline = PackedVector2Array([frame.position, Vector2(frame.end.x, frame.position.y), frame.end,
		Vector2(notch + 24, frame.end.y), Vector2(notch, frame.end.y - 16), Vector2(frame.position.x, frame.end.y - 16)])
	draw_colored_polygon(outline, Color(frame_color, 0.2))
	outline.append(frame.position)
	draw_polyline(outline, frame_color, 6.0)

	draw_rect(rect, ROW)
	var mode = modes[mode_index]
	var font_size = fit_size(mode["name"], 24, rect.size.x - 50)
	draw_text(Vector2(rect.get_center().x, rect.get_center().y + 10), mode["name"], font_size, frame_color, HORIZONTAL_ALIGNMENT_CENTER)
	for side in [-1, 1]:
		var x = rect.get_center().x + side * (rect.size.x / 2 - 12)
		draw_polyline([Vector2(x - side * 6, rect.position.y + 6), Vector2(x, rect.position.y + 6), Vector2(x, rect.end.y - 6), Vector2(x - side * 6, rect.end.y - 6)], frame_color, 2.0)

	# Fake readout lines, like the console menu
	for line in 4:
		var y = rect.end.y + 14 + line * 10
		var length = [0.7, 0.45, 0.25, 0.35][line] * (rect.size.x - 70)
		draw_rect(Rect2(rect.position.x + 8, y, length, 5), Color(ORANGE, 0.6))
	var icon_box = Rect2(rect.end.x - 46, rect.end.y + 10, 46, 46)
	draw_rect(icon_box, frame_color)
	draw_icon(mode["icon"], icon_box.get_center(), Color.BLACK)
	if not leaving or blink():
		draw_text(Vector2(frame.end.x - 12, frame.end.y - 12), "DECIDE?", 14, YELLOW, HORIZONTAL_ALIGNMENT_RIGHT, 4)

# Small line icons of the modes, about 36x36
func draw_icon(icon: String, center: Vector2, icon_color: Color) -> void:
	match icon:
		"arcade":
			draw_rect(Rect2(center + Vector2(-16, 8), Vector2(32, 10)), icon_color)
			draw_line(center + Vector2(-4, 8), center + Vector2(-8, -6), icon_color, 4.0)
			draw_circle(center + Vector2(-9, -10), 7, icon_color)
			draw_circle(center + Vector2(9, 0), 4, icon_color)
		"free":
			draw_circle(center + Vector2(-8, 10), 7, icon_color)
			draw_line(center + Vector2(-2, 10), center + Vector2(-2, -16), icon_color, 4.0)
			draw_polyline([center + Vector2(-2, -15), center + Vector2(14, -10), center + Vector2(14, 0)], icon_color, 4.0)
		"netplay":
			for x in [-10, 10]:
				draw_rect(Rect2(center + Vector2(x - 8, -14), Vector2(16, 12)), icon_color, false, 3.0)
				draw_rect(Rect2(center + Vector2(x - 2, -2), Vector2(4, 6)), icon_color)
			draw_polyline([center + Vector2(-10, 4), center + Vector2(-10, 12), center + Vector2(10, 12), center + Vector2(10, 4)], icon_color, 3.0)
		"training":
			# Stopwatch
			draw_circle(center + Vector2(0, 3), 14, icon_color, false, 4.0)
			draw_rect(Rect2(center + Vector2(-4, -18), Vector2(8, 5)), icon_color)
			draw_line(center + Vector2(0, 3), center + Vector2(6, -4), icon_color, 3.0)
			draw_line(center + Vector2(11, -10), center + Vector2(15, -14), icon_color, 3.0)
		"editor":
			# Pencil over a note
			draw_rect(Rect2(center + Vector2(-16, 8), Vector2(20, 8)), icon_color)
			draw_line(center + Vector2(-2, 4), center + Vector2(12, -12), icon_color, 6.0)
			draw_colored_polygon([center + Vector2(-6, 6), center + Vector2(-4, -1), center + Vector2(1, 4)], icon_color)
			draw_line(center + Vector2(13, -13), center + Vector2(16, -16), icon_color, 6.0)
		"options":
			for i in 8:
				var direction = Vector2.from_angle(i * TAU / 8)
				draw_line(center + direction * 10, center + direction * 17, icon_color, 6.0)
			draw_circle(center, 12, icon_color, false, 5.0)
		"download":
			draw_rect(Rect2(center + Vector2(-4, -16), Vector2(8, 14)), icon_color)
			draw_colored_polygon([center + Vector2(-12, -3), center + Vector2(12, -3), center + Vector2(0, 9)], icon_color)
			draw_rect(Rect2(center + Vector2(-16, 12), Vector2(32, 4)), icon_color)

func draw_header() -> void:
	draw_texture(INFO_BAR, Vector2(size.x + INFO_BAR_LEFT, 0))
	draw_text(Vector2(16, 16 + TITLE_FONT.get_ascent(32)), "menu select", 32, Color.WHITE)
	# Credits, small under the title like the console menu
	var version = Engine.get_version_info()
	draw_text(Vector2(18, 72), "noiseBMS  2024-2026 DJALEXKIDD", 8, TAG_BORDER)
	draw_text(Vector2(18, 84), "GODOT ENGINE %d.%d.%d" % [version["major"], version["minor"], version["patch"]], 8, TAG_BORDER)
	# No OPTIONS tag here
	var tag = header_tag_rect(0)
	draw_rect(Rect2(tag.position - Vector2(10, 14), tag.size + Vector2(20, 18)), Color.BLACK)

# All the modes, the current one raised, like the console menu
func draw_footer() -> void:
	var top = body_bottom()
	draw_rect(Rect2(0, top, size.x, size.y - top), Color.BLACK)
	draw_rect(Rect2(0, top, size.x, 4), Color.RED)
	var bar = Rect2(20, top + 14, size.x - 40, FOOTER_HEIGHT - 16)
	draw_rect(bar, TAG_BORDER, false, 2.0)
	var width = (bar.size.x - 8) / modes.size()
	for i in modes.size():
		var cell = Rect2(bar.position.x + 4 + i * width, bar.position.y + 4, width - 4, bar.size.y - 8)
		var selected = i == mode_index
		if selected:
			cell = Rect2(cell.position - Vector2(0, 8), cell.size + Vector2(0, 8))
			draw_rect(cell, Color(0.15, 0.15, 0.15))
			draw_rect(Rect2(cell.position, Vector2(cell.size.x, 3)), ORANGE)
		else:
			draw_rect(cell, TAG_BORDER, false, 1.0)
		var text = modes[i]["short"]
		draw_text(Vector2(cell.get_center().x, cell.get_center().y + 9), text, 20, ORANGE if selected else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
