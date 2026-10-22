extends Control

# OPTIONS menu, like on the console versions of IIDX, everything drawn in _draw():
# the turntable selects, the white keys decide, the black keys go back, EFFECT restores the defaults.
# Settings live in Global and are saved in user://settings.cfg.

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const FONT = preload("res://assets/font/FT2FONT.TTF")
const DEFAULT_BGM = preload("res://assets/bgm/music_select.ogg")
# Top bar of the music select, drawn the same way: right aligned, 32 px out of the screen
const INFO_BAR = preload("res://assets/music_select/music_select_info.png")
const INFO_BAR_LEFT = -1888.0
# Tags of the info bar, in its pixels: OPTIONS (replaced by DEFAULT), OK, EXIT
const INFO_TAGS = [Rect2(1313, 14, 189, 79), Rect2(1577, 14, 105, 79), Rect2(1755, 14, 103, 79)]

# Dark theme over the scrolling grid, like the music select
const PANEL = Color(0, 0, 0, 0.7)
const PANEL_DARK = Color(0, 0, 0, 0.85)
const ROW = Color(0.1, 0.1, 0.1, 0.95)
const ROW_BORDER = Color(0, 0, 0)
const TAG_BORDER = Color(0.45, 0.45, 0.45)
const ORANGE = Color(1, 0.55, 0.05)
const YELLOW = Color(1, 0.82, 0.1)
const CYAN = Color(0.3, 0.9, 1)

const HEADER_HEIGHT = 113.0
const FOOTER_HEIGHT = 64.0
const ROW_HEIGHT = 96.0
const WHEEL_WIDTH = 440.0
const PANEL_LEFT = 540.0
const ITEMS_TOP = 410.0
const ITEM_HEIGHT = 50.0
const ITEM_FONT_SIZE = 18
const ANALOG_STEP = 0.08
const SCROLL_DURATION = 0.16
const TITLE_SLIDE_TIME = 0.2
const NOTICE_TIME = 3.0
const SOUND_VOLUME_DB = -10.0
const BGM_VOLUME_DB = -6.0

# Latency calibration, same as the Customization menu
const CALIBRATION_CLICKS = 12
const CALIBRATION_INTERVAL = 0.6
const CALIBRATION_IGNORED = 2
const CALIBRATION_MIN_PRESSES = 4

# Letters of the DJ name, chosen with the turntable
const NAME_CHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.!?*#&$@"

enum Level { CATEGORIES, ITEMS, EDIT, NAME, CALIBRATION }

# Items: "var" is a Global setting; "type" bool, int (min, max, step, format), choice (values, labels),
# action (calls "action"), name (DJ name entry). A category with "scene" opens it.
var categories = [
	{"title": ["DISPLAY", "SETTINGS"], "icon": "display", "desc": "Window and judgement display.", "items": [
		{"name": "FULL SCREEN", "var": "fullscreen", "type": "bool", "desc": "Play in a window or in full screen."},
		{"name": "V-SYNC", "var": "vsync", "type": "bool", "desc": "Sync the frames with the screen. OFF lowers the input lag but may tear."},
		{"name": "TIMING DISPLAY", "var": "show_timing", "type": "bool", "desc": "Show the timing error in ms under the judgement."},
	]},
	{"title": ["SOUND", "SETTINGS"], "icon": "sound", "desc": "Volume, audio latency and music select BGM.", "items": [
		{"name": "MASTER VOLUME", "var": "master_volume", "type": "int", "min": 0, "max": 100, "step": 5, "format": "%d %%", "desc": "Volume of the whole game."},
		{"name": "AUDIO OFFSET", "var": "audio_offset", "type": "int", "min": -500, "max": 500, "step": 5, "format": "%+d MS", "desc": "Delay of the sound (bluetooth headphones...), positive when it comes late."},
		{"name": "AUTO CALIBRATION", "type": "action", "action": "start_calibration", "desc": "Press a key on each click to measure the audio offset."},
		{"name": "MUSIC SELECT BGM", "var": "custom_music_select_bgm", "type": "choice", "values": [""], "labels": ["DEFAULT"], "desc": "BGM of the music select, from the music_select_bgm folder."},
	]},
	{"title": ["DJ NAME"], "icon": "name", "desc": "Your DJ name, shown in the music select and in netplay.", "items": [
		{"name": "DJ NAME", "type": "name", "desc": "6 letters, chosen with the turntable."},
	]},
	{"title": ["CONTROLLER", "SET UP"], "icon": "controller", "scene": "res://scenes/menu/test_controller.tscn", "desc": "Test and remap the keys of the controllers."},
]

var level = Level.CATEGORIES
var category_index = 0
var item_index = 0
# Value of the edited item before the edit, back with a black key
var edit_backup
var name_chars: Array[String] = []
var name_cursor = 0

var analog_previous = [0.0, 0.0]
var analog_remainder = [0.0, 0.0]
var repeat_direction = 0
var repeat_time = 0.0
var scroll_offset = 0.0
var scroll_tween: Tween
# Slide of the category title, 1 when it arrives, 0 in place
var title_slide = 0.0
var title_tween: Tween
var notice = ""
var notice_until = 0

var calibration_clicks = []
var next_click_usec = 0
var press_delays = []

var scroll_sound: AudioStreamPlayer
var decide_sound: AudioStreamPlayer
var cancel_sound: AudioStreamPlayer
var click_sound: AudioStreamPlayer
var bgm: AudioStreamPlayer

func _ready() -> void:
	# Full screen only exists on desktop
	if not OS.has_feature("pc"):
		categories[0]["items"].pop_front()
	var bgm_item = categories[1]["items"][3]
	for file in Loader.get_all_files("user://music_select_bgm", "ogg"):
		bgm_item["values"].append(file)
		bgm_item["labels"].append(file.get_file().get_basename().to_upper())

	scroll_sound = add_sound(preload("res://assets/music_select/scroll.wav"))
	decide_sound = add_sound(preload("res://assets/music_select/decide.wav"))
	cancel_sound = add_sound(preload("res://assets/music_select/cancel.wav"))
	click_sound = add_sound(make_click())
	click_sound.volume_db = 0.0
	bgm = add_sound(null)
	bgm.volume_db = BGM_VOLUME_DB
	play_bgm()
	for player in [1, 2]:
		analog_previous[player - 1] = analog_value(player)

func add_sound(stream: AudioStream) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SOUND_VOLUME_DB
	player.max_polyphony = 4
	add_child(player)
	return player

# The music select BGM, changed live while choosing it
func play_bgm() -> void:
	var stream: AudioStream = DEFAULT_BGM
	if Global.custom_music_select_bgm != "":
		stream = AudioStreamOggVorbis.load_from_file(Global.custom_music_select_bgm)
		stream.loop = true
	if bgm.stream == stream:
		return
	bgm.stream = stream
	bgm.play()

func _process(delta: float) -> void:
	queue_redraw()
	var steps = poll_turntable(delta)
	if level == Level.CALIBRATION:
		process_calibration()
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
	if level == Level.CALIBRATION:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: turn(-1)
			MOUSE_BUTTON_WHEEL_DOWN: turn(1)
			MOUSE_BUTTON_LEFT: click(event.position)
		return
	if not (event is InputEventKey and event.pressed) or is_player_input(event):
		return
	if level == Level.NAME:
		var letter = char(event.unicode).to_upper() if event.unicode > 0 else ""
		if letter != "" and NAME_CHARS.contains(letter):
			name_chars[name_cursor] = letter
			decide()
			return
	match event.keycode:
		KEY_UP: turn(-1)
		KEY_DOWN: turn(1)
		KEY_LEFT:
			if level in [Level.EDIT, Level.NAME]:
				turn(-1)
		KEY_RIGHT:
			if level in [Level.EDIT, Level.NAME]:
				turn(1)
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
	elif header_tag_rect(1).has_point(at):
		decide()
	elif header_tag_rect(2).has_point(at):
		back()
	elif at.x < WHEEL_WIDTH + 60 and level != Level.NAME:
		for i in categories.size():
			if category_rect(i).has_point(at):
				if i == category_index:
					if level == Level.CATEGORIES:
						decide()
				else:
					close_edit()
					level = Level.CATEGORIES
					turn(i - category_index)
				return
	elif level in [Level.ITEMS, Level.EDIT]:
		var items = current_items()
		for i in items.size():
			if item_rect(i).has_point(at):
				if i != item_index:
					close_edit()
					item_index = i
					scroll_sound.play()
				elif level == Level.ITEMS:
					decide()
				return

func current_items() -> Array:
	return categories[category_index].get("items", [])

func current_item() -> Dictionary:
	return current_items()[item_index]

func turn(steps: int) -> void:
	match level:
		Level.CATEGORIES:
			var index = clampi(category_index + steps, 0, categories.size() - 1)
			if index == category_index:
				return
			scroll_offset += (index - category_index) * ROW_HEIGHT
			category_index = index
			scroll_sound.play()
			animate_scroll()
			animate_title()
		Level.ITEMS:
			var index = clampi(item_index + steps, 0, current_items().size() - 1)
			if index != item_index:
				item_index = index
				scroll_sound.play()
		Level.EDIT:
			var item = current_item()
			var value = step_value(item, Global.get(item["var"]), steps)
			if value != Global.get(item["var"]):
				set_setting(item, value)
				scroll_sound.play()
		Level.NAME:
			var index = NAME_CHARS.find(name_chars[name_cursor])
			name_chars[name_cursor] = NAME_CHARS[posmod(index + steps, NAME_CHARS.length())]
			scroll_sound.play()

func decide() -> void:
	match level:
		Level.CATEGORIES:
			decide_sound.play()
			var category = categories[category_index]
			if category.has("scene"):
				get_tree().change_scene_to_file(category["scene"])
				return
			level = Level.ITEMS
			item_index = 0
		Level.ITEMS:
			decide_sound.play()
			var item = current_item()
			match item["type"]:
				"action":
					call(item["action"])
				"name":
					start_name_entry()
				_:
					edit_backup = Global.get(item["var"])
					level = Level.EDIT
		Level.EDIT:
			decide_sound.play()
			Global.save_settings()
			level = Level.ITEMS
		Level.NAME:
			decide_sound.play()
			name_cursor += 1
			if name_cursor >= Netplay.NAME_LENGTH:
				finish_name_entry()

func back() -> void:
	match level:
		Level.CATEGORIES:
			cancel_sound.play()
			get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")
		Level.ITEMS:
			cancel_sound.play()
			level = Level.CATEGORIES
		Level.EDIT:
			cancel_sound.play()
			close_edit()
		Level.NAME:
			cancel_sound.play()
			name_cursor -= 1
			if name_cursor < 0:
				level = Level.ITEMS

# Leaves an edit without keeping the new value
func close_edit() -> void:
	if level == Level.EDIT:
		set_setting(current_item(), edit_backup)
		level = Level.ITEMS

# EFFECT: the item under the cursor, or the whole category
func restore_default() -> void:
	var items = []
	match level:
		Level.CATEGORIES:
			items = current_items()
		Level.ITEMS, Level.EDIT:
			items = [current_item()]
	items = items.filter(func(item): return item.has("var"))
	if items.is_empty():
		return
	decide_sound.play()
	for item in items:
		set_setting(item, Global.SETTING_DEFAULTS[item["var"]])
	if level != Level.EDIT:
		Global.save_settings()
	show_notice("DEFAULT SETTINGS RESTORED")

func set_setting(item: Dictionary, value) -> void:
	Global.set(item["var"], value)
	Global.apply_settings()
	if item["var"] == "custom_music_select_bgm":
		play_bgm()

func step_value(item: Dictionary, value, steps: int):
	match item["type"]:
		"bool":
			return value if steps % 2 == 0 else not value
		"int":
			return clampi(value + steps * item["step"], item["min"], item["max"])
		"choice":
			var index = item["values"].find(value)
			return item["values"][posmod(index + steps, item["values"].size())]
	return value

func value_text(item: Dictionary) -> String:
	match item["type"]:
		"bool":
			return "ON" if Global.get(item["var"]) else "OFF"
		"int":
			return item["format"] % Global.get(item["var"])
		"choice":
			return item["labels"][maxi(0, item["values"].find(Global.get(item["var"])))]
		"name":
			return Netplay.dj_name
	return ""

func show_notice(text: String) -> void:
	notice = text
	notice_until = Time.get_ticks_msec() + int(NOTICE_TIME * 1000)

func animate_scroll() -> void:
	if scroll_tween:
		scroll_tween.kill()
	scroll_offset = clampf(scroll_offset, -size.y, size.y)
	scroll_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	scroll_tween.tween_property(self, "scroll_offset", 0.0, SCROLL_DURATION)

func animate_title() -> void:
	if title_tween:
		title_tween.kill()
	title_slide = 1.0
	title_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	title_tween.tween_property(self, "title_slide", 0.0, TITLE_SLIDE_TIME)

# DJ name

func start_name_entry() -> void:
	name_chars.clear()
	for i in Netplay.NAME_LENGTH:
		var letter = Netplay.dj_name[i] if i < Netplay.dj_name.length() else " "
		name_chars.append(letter if NAME_CHARS.contains(letter) else " ")
	name_cursor = 0
	level = Level.NAME

func finish_name_entry() -> void:
	level = Level.ITEMS
	var dj_name = Netplay.clean_name("".join(name_chars))
	if dj_name == "":
		show_notice("THE NAME IS EMPTY")
		return
	Netplay.set_dj_name(dj_name)
	show_notice("DJ NAME SAVED")

# Calibration: clicks at a steady beat, the player presses a key on each click

func start_calibration() -> void:
	level = Level.CALIBRATION
	calibration_clicks = []
	press_delays = []
	next_click_usec = Time.get_ticks_usec() + int(CALIBRATION_INTERVAL * 1e6)

func process_calibration() -> void:
	var now = Time.get_ticks_usec()
	if len(calibration_clicks) < CALIBRATION_CLICKS:
		if now >= next_click_usec:
			click_sound.play()
			calibration_clicks.append(now)
			next_click_usec += int(CALIBRATION_INTERVAL * 1e6)
	elif now >= calibration_clicks[-1] + int(CALIBRATION_INTERVAL * 1e6):
		finish_calibration()

func _input(event: InputEvent) -> void:
	if level != Level.CALIBRATION:
		return
	var is_press = (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch) \
		and event.is_pressed() and not event.is_echo()
	if not is_press:
		return
	get_viewport().set_input_as_handled()
	if len(calibration_clicks) <= CALIBRATION_IGNORED:
		return
	# Delay after the nearest click
	var now = Time.get_ticks_usec()
	var nearest = calibration_clicks[-1]
	if len(calibration_clicks) < CALIBRATION_CLICKS and next_click_usec - now < now - nearest:
		nearest = next_click_usec
	if abs(now - nearest) < CALIBRATION_INTERVAL * 0.5e6:
		press_delays.append((now - nearest) / 1e6)

func finish_calibration() -> void:
	level = Level.ITEMS
	if len(press_delays) < CALIBRATION_MIN_PRESSES:
		show_notice("NOT ENOUGH PRESSES, TRY AGAIN")
		return
	# Median delay, minus the latency the game already compensates
	press_delays.sort()
	var delay = press_delays[len(press_delays) / 2] - AudioServer.get_output_latency()
	Global.audio_offset = clampi(int(snappedf(delay * 1000.0, 5)), -500, 500)
	Global.save_settings()
	show_notice("AUDIO OFFSET SET TO %+d MS" % Global.audio_offset)

# Short 1 kHz beep with a fast decay
func make_click() -> AudioStreamWAV:
	var rate = 44100
	var data = PackedByteArray()
	data.resize(rate / 20 * 2)
	for i in rate / 20:
		var t = float(i) / rate
		data.encode_s16(i * 2, int(sin(TAU * 1000.0 * t) * exp(-t * 60.0) * 30000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

# Layout

func body_top() -> float:
	return HEADER_HEIGHT

func body_bottom() -> float:
	return size.y - FOOTER_HEIGHT - 8

func category_rect(i: int) -> Rect2:
	var center = (body_top() + body_bottom()) / 2
	var y = center - ROW_HEIGHT / 2 + (i - category_index) * ROW_HEIGHT + scroll_offset
	return Rect2(0, y, WHEEL_WIDTH, ROW_HEIGHT)

func item_rect(i: int) -> Rect2:
	return Rect2(PANEL_LEFT + 16, ITEMS_TOP + i * ITEM_HEIGHT, size.x - PANEL_LEFT - 80, ITEM_HEIGHT - 6)

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

func _draw() -> void:
	draw_panel()
	draw_wheel()
	draw_header()
	draw_footer()

func draw_wheel() -> void:
	# Rail between the wheel and the panel
	var rail = Rect2(WHEEL_WIDTH - 14, body_top(), 34, body_bottom() - body_top())
	draw_rect(rail, Color.BLACK)
	draw_line(Vector2(rail.position.x + 8, rail.position.y), Vector2(rail.position.x + 8, rail.end.y), TAG_BORDER, 2.0)
	draw_line(Vector2(rail.end.x - 8, rail.position.y), Vector2(rail.end.x - 8, rail.end.y), TAG_BORDER, 2.0)

	for i in categories.size():
		if i != category_index:
			draw_category(i, false)
	draw_category(category_index, true)

	# Arrows when there are more categories above or below
	var bob = sin(Time.get_ticks_msec() / 150.0) * 4
	var arrow_x = WHEEL_WIDTH + 64
	if category_index > 0:
		draw_chevron(Vector2(arrow_x, body_top() + 50 - bob), -1)
	if category_index < categories.size() - 1:
		draw_chevron(Vector2(arrow_x, body_bottom() - 50 + bob), 1)

func draw_chevron(at: Vector2, direction: int) -> void:
	for offset in [0, 12]:
		var y = at.y + offset * direction
		draw_polyline([Vector2(at.x - 18, y - 10 * direction), Vector2(at.x, y), Vector2(at.x + 18, y - 10 * direction)], ORANGE, 6.0)

func draw_category(i: int, selected: bool) -> void:
	var rect = category_rect(i)
	if rect.end.y < body_top() or rect.position.y > body_bottom():
		return
	var dim = 1.0 if selected or level == Level.CATEGORIES else 0.5
	if selected:
		rect.size.x += 60
		var glow = Color(ORANGE, 0.12)
		for grow in [12, 8, 4]:
			draw_rect(rect.grow(grow), glow)
	draw_rect(rect, ROW)
	draw_rect(Rect2(rect.position.x, rect.end.y - 4, rect.size.x, 4), ROW_BORDER)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 2), Color(0.3, 0.3, 0.3))
	if selected:
		draw_rect(rect, ORANGE, false, 5.0)
		draw_rect(rect.grow(-5), Color(YELLOW, 0.8), false, 1.0)
		draw_line(Vector2(rect.end.x - 26, rect.position.y + 12), Vector2(rect.end.x - 26, rect.end.y - 12), Color.BLACK, 6.0)
	var category = categories[i]
	var icon_center = Vector2(WHEEL_WIDTH - 70, rect.get_center().y - 6)
	draw_icon(category["icon"], icon_center, Color(1, 1, 1, dim))
	var label = " ".join(category["title"])
	var font_size = fit_size(TITLE_FONT, label, 16, WHEEL_WIDTH - 160)
	draw_text(TITLE_FONT, Vector2(WHEEL_WIDTH - 136, rect.end.y - 14), label, font_size, Color(1, 1, 1, dim), HORIZONTAL_ALIGNMENT_RIGHT, 4)

# White line icons of the categories, about 90x64
func draw_icon(icon: String, center: Vector2, icon_color: Color) -> void:
	match icon:
		"display":
			draw_rect(Rect2(center - Vector2(40, 30), Vector2(80, 52)), icon_color, false, 5.0)
			draw_rect(Rect2(center - Vector2(30, 21), Vector2(60, 34)), Color(icon_color, icon_color.a * 0.25))
			draw_rect(Rect2(center + Vector2(-18, 22), Vector2(36, 6)), icon_color)
		"sound":
			draw_arc(center + Vector2(0, 4), 30, PI, TAU, 24, icon_color, 6.0)
			draw_rect(Rect2(center + Vector2(-38, 2), Vector2(14, 28)), icon_color)
			draw_rect(Rect2(center + Vector2(24, 2), Vector2(14, 28)), icon_color)
		"name":
			draw_rect(Rect2(center - Vector2(42, 28), Vector2(84, 56)), icon_color, false, 5.0)
			draw_circle(center + Vector2(-18, -6), 10, icon_color)
			draw_rect(Rect2(center + Vector2(-32, 8), Vector2(28, 12)), icon_color)
			for line in 3:
				draw_rect(Rect2(center + Vector2(6, -14 + line * 12), Vector2(26, 4)), icon_color)
		"controller":
			draw_rect(Rect2(center - Vector2(46, 24), Vector2(92, 48)), icon_color, false, 4.0)
			draw_circle(center + Vector2(-22, 0), 16, icon_color, false, 4.0)
			draw_circle(center + Vector2(-22, 0), 3, icon_color)
			for key in 7:
				var top = -16.0 if key % 2 == 1 else -2.0
				draw_rect(Rect2(center + Vector2(4 + key * 5.5, top), Vector2(5, 14)), icon_color)

func draw_panel() -> void:
	var top = body_top()
	var right = size.x - 20

	# Dark panel, darker with fine stripes under the title
	draw_rect(Rect2(WHEEL_WIDTH + 20, top, size.x - WHEEL_WIDTH - 20, ITEMS_TOP - 20 - top), PANEL)
	var lower = Rect2(WHEEL_WIDTH + 20, ITEMS_TOP - 20, size.x - WHEEL_WIDTH - 20, body_bottom() - ITEMS_TOP + 20)
	draw_rect(lower, PANEL_DARK)
	for x in range(int(lower.position.x) - int(lower.size.y), int(lower.end.x), 6):
		draw_line(Vector2(x, lower.end.y), Vector2(x + lower.size.y, lower.position.y), Color(1, 1, 1, 0.03), 1.0)

	# Help banner, top right
	var help = "TURNTABLE: SELECT    KEYS: DECIDE"
	match level:
		Level.EDIT: help = "TURNTABLE: CHANGE    WHITE: OK    BLACK: CANCEL"
		Level.NAME: help = "TURNTABLE: LETTER    WHITE: NEXT    BLACK: BACK"
		Level.CALIBRATION: help = "PRESS A KEY ON EACH CLICK"
	var banner_left = right - 600
	draw_colored_polygon([Vector2(banner_left - 40, top + 4), Vector2(right, top + 4), Vector2(right, top + 42), Vector2(banner_left, top + 42)], YELLOW)
	draw_colored_polygon([Vector2(banner_left - 70, top + 4), Vector2(banner_left - 52, top + 4), Vector2(banner_left - 12, top + 42), Vector2(banner_left - 30, top + 42)], ORANGE)
	draw_rect(Rect2(right - 6, top + 4, 6, 38), Color.BLACK)
	draw_text(TITLE_FONT, Vector2((banner_left + right) / 2, top + 30), help, fit_size(TITLE_FONT, help, 14, right - banner_left - 30), Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)

	# INFORMATION box with its corner brackets
	var info = Rect2(PANEL_LEFT + 30, top + 62, mini(700, right - PANEL_LEFT - 60), 66)
	for corner in [info.position, Vector2(info.end.x, info.position.y), Vector2(info.position.x, info.end.y), info.end]:
		var dx = 12.0 if corner.x == info.position.x else -12.0
		var dy = 12.0 if corner.y == info.position.y else -12.0
		draw_polyline([corner + Vector2(dx, 0), corner, corner + Vector2(0, dy)], Color.WHITE, 2.0)
	draw_text(TITLE_FONT, info.position + Vector2(14, 24), "INFORMATION", 16, Color.WHITE)
	draw_rect(Rect2(info.position + Vector2(178, 21), Vector2(30, 3)), Color.WHITE)
	draw_rect(Rect2(info.position + Vector2(16, 36), Vector2(16, 16)), Color.WHITE, false, 2.0)
	draw_rect(Rect2(info.position + Vector2(20, 40), Vector2(8, 8)), Color.WHITE)
	if Time.get_ticks_msec() < notice_until:
		draw_text(TITLE_FONT, info.position + Vector2(42, 52), notice, 12, YELLOW)
	else:
		draw_text(TITLE_FONT, info.position + Vector2(42, 52), "PRESS EFFECT TO", 12, Color.WHITE)
		draw_text(TITLE_FONT, info.position + Vector2(42 + TITLE_FONT.get_string_size("PRESS EFFECT TO ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, 52), "RESTORE THE DEFAULTS", 12, ORANGE)

	# Big title of the category, sliding in, over a dark shard
	var title_x = PANEL_LEFT + 40 + title_slide * 120
	var title_alpha = 1.0 - title_slide
	var shard = Vector2(PANEL_LEFT + 330, top + 210)
	draw_colored_polygon([shard + Vector2(-280, 20), shard + Vector2(320, -90), shard + Vector2(60, 10), shard + Vector2(380, 70)], Color(1, 1, 1, 0.07))
	draw_colored_polygon([shard + Vector2(-120, 40), shard + Vector2(260, -30), shard + Vector2(140, 30)], Color(ORANGE, 0.08))
	var title = categories[category_index]["title"]
	for line in title.size():
		var baseline = top + 196 + line * 58 + (29 if title.size() == 1 else 0)
		var font_size = fit_size(TITLE_FONT, title[line], 50, right - title_x)
		draw_text(TITLE_FONT, Vector2(title_x, baseline), title[line], font_size, Color(1, 1, 1, title_alpha), HORIZONTAL_ALIGNMENT_LEFT, 8)
	draw_line(Vector2(PANEL_LEFT + 40, ITEMS_TOP - 24), Vector2(size.x, ITEMS_TOP - 24), Color.WHITE, 3.0)

	var items = current_items()
	if items.is_empty():
		draw_text(TITLE_FONT, Vector2(PANEL_LEFT + 56, ITEMS_TOP + 30), "PRESS A WHITE KEY TO OPEN", 20, Color(1, 1, 1, 0.6))
	for i in items.size():
		draw_item(i, items[i])

func draw_item(i: int, item: Dictionary) -> void:
	var rect = item_rect(i)
	var selected = i == item_index and level != Level.CATEGORIES
	var editing = selected and level in [Level.EDIT, Level.NAME, Level.CALIBRATION]
	if selected:
		draw_rect(rect, Color(ORANGE, 0.25 if editing else 0.15))
		draw_rect(Rect2(rect.position, Vector2(6, rect.size.y)), ORANGE)
	var baseline = rect.position.y + 30
	draw_text(TITLE_FONT, Vector2(rect.position.x + 24, baseline), item["name"], ITEM_FONT_SIZE, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4)
	if selected:
		var arrow_x = rect.position.x + 32 + TITLE_FONT.get_string_size(item["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, ITEM_FONT_SIZE).x
		var arrow = Vector2(arrow_x, baseline - 8)
		draw_colored_polygon([arrow + Vector2(0, -8), arrow + Vector2(10, 0), arrow + Vector2(0, 8)], CYAN)
		draw_colored_polygon([arrow + Vector2(8, -8), arrow + Vector2(18, 0), arrow + Vector2(8, 8)], Color(CYAN, 0.5))
	draw_line(Vector2(rect.position.x + 24, rect.end.y), Vector2(rect.end.x, rect.end.y), Color(1, 1, 1, 0.8), 2.0)

	var value_right = rect.end.x - 40
	if editing and level == Level.NAME:
		draw_name_entry(Vector2(value_right, baseline))
		return
	if editing and level == Level.CALIBRATION:
		var text = "PRESS ON EACH CLICK  %d" % len(press_delays)
		draw_text(TITLE_FONT, Vector2(value_right, baseline), text, ITEM_FONT_SIZE, YELLOW if blink() else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 4)
		return
	var text = value_text(item)
	if item["type"] == "action":
		text = "START"
	var font_size = fit_size(TITLE_FONT, text, ITEM_FONT_SIZE, rect.size.x * 0.45)
	var value_color = YELLOW if editing else CYAN if item["type"] == "action" else Color.WHITE
	draw_text(TITLE_FONT, Vector2(value_right, baseline), text, font_size, value_color, HORIZONTAL_ALIGNMENT_RIGHT, 4)
	if editing and blink():
		var width = TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var middle = baseline - 8
		var left = Vector2(value_right - width - 14, middle)
		var right = Vector2(value_right + 14, middle)
		draw_colored_polygon([left + Vector2(0, -8), left + Vector2(0, 8), left + Vector2(-10, 0)], ORANGE)
		draw_colored_polygon([right + Vector2(0, -8), right + Vector2(0, 8), right + Vector2(10, 0)], ORANGE)

# The 6 letters of the DJ name, the one being chosen blinks
func draw_name_entry(right_baseline: Vector2) -> void:
	const BOX = 30.0
	var left = right_baseline.x - Netplay.NAME_LENGTH * (BOX + 4)
	for i in Netplay.NAME_LENGTH:
		var box = Rect2(left + i * (BOX + 4), right_baseline.y - 26, BOX, 34)
		var current = i == name_cursor
		draw_rect(box, Color(ORANGE, 0.8) if current and blink() else Color(0, 0, 0, 0.5))
		draw_rect(box, YELLOW if current else Color(1, 1, 1, 0.5), false, 2.0)
		var letter = name_chars[i] if name_chars[i] != " " else "_"
		draw_text(TITLE_FONT, Vector2(box.get_center().x + 1, right_baseline.y - 1), letter, ITEM_FONT_SIZE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

func draw_header() -> void:
	draw_texture(INFO_BAR, Vector2(size.x + INFO_BAR_LEFT, 0))
	draw_text(TITLE_FONT, Vector2(16, 16 + TITLE_FONT.get_ascent(32)), "options", 32, Color.WHITE)
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
	var text = categories[category_index]["desc"]
	if level != Level.CATEGORIES and not current_items().is_empty():
		text = current_item()["desc"]
	var font_size = fit_size(FONT, text, 32, bar.size.x - 40)
	draw_text(FONT, Vector2(bar.get_center().x, bar.get_center().y + font_size * 0.35), text, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
