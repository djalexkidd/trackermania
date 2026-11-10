extends Control

# Welcome screen shown over the main menu on the first start (Global.welcome_seen):
# slides with the goal of the game and the default controls of both players, IIDX layout.
# Turntable or arrows: slide; white key / Enter: next; black key / Backspace: previous; START / Esc: skip.
# On the controls slides, E3 VEFX starts the test mode of the deck (held 2 s or Esc to leave).

signal closed

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const FONT = preload("res://assets/font/FT2FONT.TTF")
const TitleScreen = preload("res://scripts/menu/title_screen.gd")

# Colors of the main menu
const PANEL = Color(0, 0, 0, 0.94)
const ROW = Color(0.1, 0.1, 0.1, 0.95)
const TAG_BORDER = Color(0.45, 0.45, 0.45)
const ORANGE = Color(1, 0.55, 0.05)
const DARK_ORANGE = Color(0.45, 0.18, 0)
const YELLOW = Color(1, 0.82, 0.1)
const PALE_BLUE = Color(0.6, 0.7, 1)
const TEXT = Color(0.9, 0.9, 0.9)
const P1_COLOR = ControllerPanel.P1_COLOR
const P2_COLOR = ControllerPanel.P2_COLOR

const HEADER_HEIGHT = 80.0
const FOOTER_HEIGHT = 64.0
const MARGIN = 48.0
const SLIDE_TIME = 0.3
const FADE_TIME = 0.3
const ANALOG_STEP = 0.08
const SOUND_VOLUME_DB = -10.0

const SLIDES = ["WELCOME", "HOW TO PLAY", "YOUR SONGS", "1P CONTROLS", "2P CONTROLS"]

# Default bindings listed under the deck: [action, label]
const BINDINGS = [
	["key1", "KEY 1"], ["key2", "KEY 2"], ["key3", "KEY 3"], ["key4", "KEY 4"],
	["key5", "KEY 5"], ["key6", "KEY 6"], ["key7", "KEY 7"],
	["digital_turntable_fwd", "TT UP"], ["digital_turntable_rew", "TT DOWN"], ["analog_turntable_fwd", "ANALOG TT"],
	["start", "E1 START"], ["effect", "E2 EFFECT"], ["vefx", "E3 VEFX"], ["meta", "E4 META"],
]

# What the buttons do: [label, description]
const MENU_ROLES = [
	["TURNTABLE", "Move the cursor."],
	["WHITE KEYS", "Decide (keys 1 3 5 7)."],
	["BLACK KEYS", "Back, cancel (keys 2 4 6)."],
	["E1 START", "Join in the music select. Hold it for the OPTION SETTING (hi-speed, random, gauge...)."],
	["E2 EFFECT", "Next effector preset, hold it to turn it off."],
	["E3 VEFX", "Next difficulty of the songs."],
	["E4 META", "Leave the music select."],
]
const GAME_ROLES = [
	["KEYS, TT", "Hit the notes of their lane."],
	["START HELD", "Keys: hi-speed. Turntable: SUDDEN+ or LIFT cover."],
	["E4 META", "Give up the song."],
]

# Demo of the HOW TO PLAY slide: [time in the loop, lane] (lane 0 is the turntable)
const DEMO_NOTES = [
	[0.0, 0], [0.0, 1], [0.25, 3], [0.5, 5], [0.75, 7], [1.0, 2], [1.0, 6], [1.25, 4],
	[1.5, 1], [1.5, 0], [1.75, 3], [2.0, 5], [2.0, 7], [2.25, 6], [2.5, 4], [2.75, 2],
	[3.0, 0], [3.0, 1], [3.0, 7], [3.25, 3], [3.375, 4], [3.5, 5], [3.625, 6],
]
const DEMO_LOOP = 4.0
const DEMO_FALL = 0.9
const DEMO_LIGHT = 0.12
const DEMO_JUDGE_TIME = 0.4

var index := 0
# Slide on screen, eased toward index
var slide_pos := 0.0
var slide_tween: Tween
var closing := false
var analog_previous = [0.0, 0.0]
var analog_remainder = [0.0, 0.0]
# Decks of both sides, drawn by the controller set up panel (they light up with the inputs)
var decks = {}
var scroll_sound: AudioStreamPlayer
var decide_sound: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for player in [1, 2]:
		var deck = ControllerPanel.new()
		deck.player = player
		deck.previous_value = deck.analog_value()
		add_child(deck)
		decks[player] = deck
		analog_previous[player - 1] = analog_value(player)
	scroll_sound = add_sound(preload("res://assets/music_select/scroll.wav"))
	decide_sound = add_sound(preload("res://assets/music_select/decide.wav"))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)

func add_sound(stream: AudioStream) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SOUND_VOLUME_DB
	player.max_polyphony = 4
	add_child(player)
	return player

func _process(_delta: float) -> void:
	queue_redraw()
	if closing:
		return
	# Test mode of the deck on screen: the inputs only light it
	var deck = controls_deck()
	if deck != null:
		deck.update_test()
		if deck.busy():
			return
	var steps = 0
	for player in [1, 2]:
		var prefix = "p%d_" % player
		if Input.is_action_just_pressed(prefix + "start"):
			close()
			return
		for key in ["key1", "key3", "key5", "key7"]:
			if Input.is_action_just_pressed(prefix + key):
				next()
				return
		for key in ["key2", "key4", "key6"]:
			if Input.is_action_just_pressed(prefix + key):
				go_to(index - 1)
				return
		steps += int(Input.is_action_just_pressed(prefix + "digital_turntable_fwd"))
		steps -= int(Input.is_action_just_pressed(prefix + "digital_turntable_rew"))
		var value = analog_value(player)
		analog_remainder[player - 1] += wrapf(value - analog_previous[player - 1], -1.0, 1.0)
		analog_previous[player - 1] = value
		var analog_steps = int(analog_remainder[player - 1] / ANALOG_STEP)
		analog_remainder[player - 1] -= analog_steps * ANALOG_STEP
		steps += analog_steps
	if steps != 0:
		go_to(index + signi(steps))

# Deck of the controls slide on screen, null on the other slides
func controls_deck() -> ControllerPanel:
	if slide_pos != float(index) or SLIDES[index] not in ["1P CONTROLS", "2P CONTROLS"]:
		return null
	return decks[1 if SLIDES[index] == "1P CONTROLS" else 2]

func testing() -> bool:
	var deck = controls_deck()
	return deck != null and deck.testing

func analog_value(player: int) -> float:
	return Input.get_action_strength("p%d_analog_turntable_fwd" % player) - Input.get_action_strength("p%d_analog_turntable_rew" % player)

# Keyboard and mouse; the main menu under it never sees them
func _input(event: InputEvent) -> void:
	if closing:
		return
	# Esc is handled by the deck, the rest is ignored
	if testing():
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: go_to(index - 1)
			MOUSE_BUTTON_WHEEL_DOWN: go_to(index + 1)
			MOUSE_BUTTON_LEFT: click(event.position)
			MOUSE_BUTTON_RIGHT: go_to(index - 1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
	if not (event is InputEventKey and event.pressed) or is_player_input(event):
		return
	match event.keycode:
		KEY_LEFT, KEY_UP, KEY_BACKSPACE: go_to(index - 1)
		KEY_RIGHT, KEY_DOWN: go_to(index + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: next()
		KEY_ESCAPE: close()

# A key bound to a player action is already handled in _process
func is_player_input(event: InputEvent) -> bool:
	for action in InputMap.get_actions():
		if (action.begins_with("p1_") or action.begins_with("p2_")) and event.is_action(action):
			return true
	return false

func click(at: Vector2) -> void:
	for i in SLIDES.size():
		if dot_rect(i).grow(8).has_point(at):
			go_to(i)
			return
	if at.x < MARGIN * 1.5:
		go_to(index - 1)
	else:
		next()

func next() -> void:
	if index == SLIDES.size() - 1:
		close()
	else:
		go_to(index + 1)

func go_to(i: int) -> void:
	i = clampi(i, 0, SLIDES.size() - 1)
	if i == index:
		return
	index = i
	scroll_sound.play()
	if slide_tween:
		slide_tween.kill()
	slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_tween.tween_property(self, "slide_pos", float(index), SLIDE_TIME)

func close() -> void:
	closing = true
	decide_sound.play()
	Global.welcome_seen = true
	Global.save_settings()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	closed.emit()
	queue_free()

# Drawing

# Same helpers as the options menu, used by the controller set up panel too
func draw_text(font: Font, position_: Vector2, text: String, font_size: int, text_color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, outline := 0) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x = position_.x - (width if alignment == HORIZONTAL_ALIGNMENT_RIGHT else width / 2 if alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
	if outline > 0:
		draw_string_outline(font, Vector2(x, position_.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color.BLACK)
	draw_string(font, Vector2(x, position_.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func fit_size(font: Font, text: String, font_size: int, width: float) -> int:
	while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	return font_size

# Wrapped paragraph, returns its height
func draw_paragraph(at: Vector2, text: String, width: float, font_size: int, text_color: Color) -> float:
	draw_multiline_string(FONT, at + Vector2(0, FONT.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, text_color)
	return FONT.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size).y

func blink() -> bool:
	return Time.get_ticks_msec() % 500 < 300

func body_top() -> float:
	return HEADER_HEIGHT

func body_bottom() -> float:
	return size.y - FOOTER_HEIGHT

# Page dots, top right
func dot_rect(i: int) -> Rect2:
	var step = 28.0
	return Rect2(size.x - 24 - (SLIDES.size() - i) * step + 14, 30, 14, 14)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL)
	# The slide on screen, and the next one while sliding
	var first = floori(slide_pos)
	draw_slide(first, (first - slide_pos) * size.x)
	if slide_pos > first:
		draw_slide(first + 1, (first + 1 - slide_pos) * size.x)
	draw_header()
	draw_footer()

func draw_header() -> void:
	draw_rect(Rect2(0, 0, size.x, HEADER_HEIGHT), Color.BLACK)
	draw_text(TITLE_FONT, Vector2(16, 16 + TITLE_FONT.get_ascent(32)), "welcome", 32, Color.WHITE)
	draw_text(TITLE_FONT, Vector2(18, 70), "FIRST START OF noiseBMS", 8, TAG_BORDER)
	for i in SLIDES.size():
		var dot = dot_rect(i)
		if i == index:
			draw_rect(dot, ORANGE)
		else:
			draw_rect(dot, TAG_BORDER, false, 2.0)
	draw_rect(Rect2(0, HEADER_HEIGHT - 7, size.x, 3), ORANGE)

func draw_footer() -> void:
	var top = body_bottom()
	draw_rect(Rect2(0, top, size.x, size.y - top), Color.BLACK)
	draw_rect(Rect2(0, top, size.x, 4), Color.RED)
	if testing():
		draw_text(TITLE_FONT, Vector2(24, top + 40), "TEST MODE: THE MENU IGNORES YOUR INPUTS", 12, TAG_BORDER)
		draw_text(TITLE_FONT, Vector2(size.x - 24, top + 42), "HOLD E3 VEFX 2 SEC: EXIT", 16, YELLOW, HORIZONTAL_ALIGNMENT_RIGHT, 4)
		return
	var last = index == SLIDES.size() - 1
	var help = "TURNTABLE: SLIDE    BLACK KEY: BACK    START: SKIP"
	if controls_deck() != null:
		help += "    E3: TEST"
	draw_text(TITLE_FONT, Vector2(24, top + 40), help, 12, TAG_BORDER)
	var action = "WHITE KEY: LET'S PLAY!" if last else "WHITE KEY: NEXT"
	if not last or blink():
		draw_text(TITLE_FONT, Vector2(size.x - 24, top + 42), action, 16, YELLOW if last else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 4)

func draw_slide(i: int, offset: float) -> void:
	var area = Rect2(MARGIN + offset, body_top() + 24, size.x - MARGIN * 2, body_bottom() - body_top() - 48)
	draw_text(TITLE_FONT, area.position + Vector2(0, 26), SLIDES[i], 28, ORANGE, HORIZONTAL_ALIGNMENT_LEFT, 6)
	var line_width = TITLE_FONT.get_string_size(SLIDES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_rect(Rect2(area.position.x + line_width + 16, area.position.y + 14, area.size.x - line_width - 16, 3), DARK_ORANGE)
	var content = Rect2(area.position.x, area.position.y + 56, area.size.x, area.size.y - 56)
	match i:
		0: draw_welcome(content)
		1: draw_how_to_play(content)
		2: draw_songs(content)
		3: draw_controls(content, 1)
		4: draw_controls(content, 2)

# The game logo, as on the title screen, and what the game is about
func draw_welcome(area: Rect2) -> void:
	TitleScreen.draw_logo(self, Vector2(area.get_center().x, area.position.y + 80), 40, area.size.x)

	var subtitle = "THE RHYTHM GAME POWERED BY YOUR MUSIC !"
	draw_text(TITLE_FONT, Vector2(area.get_center().x, area.position.y + 180), subtitle, 22, PALE_BLUE, HORIZONTAL_ALIGNMENT_CENTER, 8)

	var text_width = 820.0
	var y = area.position.y + 230
	var left = area.get_center().x - text_width / 2
	for paragraph in [
		"Every note is a keysound: hitting it plays its own sound, so the music is built by your play. Miss a note and it stays silent.",
		"Amiga modules (.MOD) and FastTracker II modules (.XM) are played directly: the module is the chart, with three difficulties made from its notes.",
		"Quaver beatmaps (.QUA) and BMS charts (.BMS, .BME, .BML, .BMSON) work too, in single play, double play and versus.",
	]:
		draw_rect(Rect2(left - 20, y + 5, 8, 8), ORANGE)
		y += draw_paragraph(Vector2(left, y), paragraph, text_width, 18, TEXT) + 18

# Animated playfield on the left, the rules on the right
func draw_how_to_play(area: Rect2) -> void:
	var field = Rect2(area.position.x + 40, area.position.y, 330, area.size.y - 10)
	draw_demo(field)
	var left = field.end.x + 60
	var width = area.end.x - left
	var y = area.position.y
	for rule in [
		["NOTES FALL", "Hit the key of the lane when its note reaches the red line. The wide lane is the turntable: scratch it."],
		["TIMING", "P-GREAT, GREAT and GOOD keep the combo, BAD and POOR break it. A key pressed without a note hurts the gauge."],
		["GROOVE GAUGE", "Good timings fill it, misses drain it. Finish the song with 80% or more to CLEAR (HARD: don't let it reach 0%)."],
		["EX SCORE", "2 points per P-GREAT, 1 per GREAT. The DJ LEVEL (F to AAA) comes from it."],
	]:
		draw_text(TITLE_FONT, Vector2(left, y + 16), rule[0], 18, YELLOW, HORIZONTAL_ALIGNMENT_LEFT, 4)
		y += 28
		y += draw_paragraph(Vector2(left, y), rule[1], width, 16, TEXT) + 22

func draw_demo(field: Rect2) -> void:
	var scratch_width = 70.0
	var lane_width = (field.size.x - scratch_width) / 7
	var keys_height = 60.0
	var judge_y = field.end.y - keys_height
	var time = fmod(Time.get_ticks_msec() / 1000.0, DEMO_LOOP)
	draw_rect(Rect2(field.position, Vector2(field.size.x, judge_y - field.position.y)), Color(0.02, 0.02, 0.02))
	for lane in range(1, 8):
		var x = field.position.x + scratch_width + (lane - 1) * lane_width
		draw_line(Vector2(x, field.position.y), Vector2(x, judge_y), Color(0.25, 0.25, 0.25), 1.0)

	# Time until each note, and since the last hit
	var since_hit = INF
	var lit = {}
	for note in DEMO_NOTES:
		var due = fposmod(note[0] - time, DEMO_LOOP)
		var since = DEMO_LOOP - due
		since_hit = minf(since_hit, since)
		if since < DEMO_LIGHT:
			lit[note[1]] = true
		if due <= DEMO_FALL:
			var rect = lane_rect(field, note[1], scratch_width, lane_width)
			var y = judge_y - due / DEMO_FALL * (judge_y - field.position.y)
			var note_color = Color.RED if note[1] == 0 else PALE_BLUE if note[1] % 2 == 0 else Color.WHITE
			draw_rect(Rect2(rect.position.x + 2, y - 8, rect.size.x - 4, 8), note_color)
	draw_rect(Rect2(field.position.x, judge_y - 3, field.size.x, 5), Color.RED)

	# Keys and turntable, lit when a note is hit
	var deck_top = judge_y + 4
	draw_rect(Rect2(field.position.x, deck_top, field.size.x, keys_height - 4), Color(0.12, 0.12, 0.14))
	var tt_center = Vector2(field.position.x + scratch_width / 2, deck_top + (keys_height - 4) / 2)
	draw_circle(tt_center, 24, Color(0.3, 0.3, 0.35) if not lit.has(0) else P1_COLOR)
	draw_arc(tt_center, 24, 0, TAU, 32, Color(0.7, 0.7, 0.75), 2.0, true)
	for lane in range(1, 8):
		var rect = lane_rect(field, lane, scratch_width, lane_width)
		var black = lane % 2 == 0
		var key = Rect2(rect.position.x + 4, deck_top + (6 if black else 22), rect.size.x - 8, 28)
		var key_color = Color(0.08, 0.08, 0.1) if black else Color(0.78, 0.78, 0.8)
		if lit.has(lane):
			key_color = Color.RED
		draw_rect(key, key_color)
		draw_rect(key, Color(0.55, 0.55, 0.6), false, 1.0)
	draw_rect(field, TAG_BORDER, false, 2.0)

	if since_hit < DEMO_JUDGE_TIME:
		var judge_color = YELLOW if Time.get_ticks_msec() % 100 < 50 else PALE_BLUE
		draw_text(TITLE_FONT, Vector2(field.get_center().x, judge_y - 120), "P-GREAT", 28, judge_color, HORIZONTAL_ALIGNMENT_CENTER, 6)

func lane_rect(field: Rect2, lane: int, scratch_width: float, lane_width: float) -> Rect2:
	if lane == 0:
		return Rect2(field.position.x, field.position.y, scratch_width, field.size.y)
	return Rect2(field.position.x + scratch_width + (lane - 1) * lane_width, field.position.y, lane_width, field.size.y)

func draw_songs(area: Rect2) -> void:
	var width = area.size.x / 2 - 30
	var y = area.position.y
	draw_text(TITLE_FONT, Vector2(area.position.x, y + 16), "WHERE TO PUT THEM", 18, YELLOW, HORIZONTAL_ALIGNMENT_LEFT, 4)
	y += 30
	var where = "Import a song pack with DOWNLOAD in the main menu." if OS.has_feature("web") else \
		"Copy your songs into this folder, one folder per song (subfolders are scanned too):"
	y += draw_paragraph(Vector2(area.position.x, y), where, width, 16, TEXT) + 10
	if not OS.has_feature("web"):
		var path = ProjectSettings.globalize_path("user://songs")
		var box_height = draw_paragraph(Vector2(area.position.x + 12, y + 10), path, width - 24, 14, ORANGE) + 20
		draw_rect(Rect2(area.position.x, y, width, box_height), ORANGE, false, 2.0)
		y += box_height + 14
		y += draw_paragraph(Vector2(area.position.x, y), "Or import a song pack with DOWNLOAD in the main menu.", width, 16, TEXT) + 22
	draw_text(TITLE_FONT, Vector2(area.position.x, y + 16), "FILES", 18, YELLOW, HORIZONTAL_ALIGNMENT_LEFT, 4)
	y += 30
	for line in [
		[".MOD .XM", "A module is a whole song: keysounds and charts are made from it."],
		[".QUA", "A Quaver beatmap with its MP3 or OGG, one file per difficulty."],
		[".BMS .BME .BML .BMSON", "A BMS folder with its sounds, one file per difficulty."],
	]:
		draw_text(TITLE_FONT, Vector2(area.position.x, y + 13), line[0], 13, ORANGE)
		y += 20
		y += draw_paragraph(Vector2(area.position.x + 12, y), line[1], width - 12, 15, TEXT) + 16

	var left = area.get_center().x + 30
	y = area.position.y
	draw_text(TITLE_FONT, Vector2(left, y + 16), "GAME MODES", 18, YELLOW, HORIZONTAL_ALIGNMENT_LEFT, 4)
	y += 34
	for mode in [
		["ARCADE", "3 stages in a row, then the ranking."],
		["FREE", "Play the songs you want."],
		["NETPLAY", "Play against other DJs on the network."],
		["TRAINING", "Practice a section, slower if needed."],
		["EDITOR", "Make keysounded BMS charts."],
		["OPTIONS", "Display, sound, DJ name, controllers."],
	]:
		draw_rect(Rect2(left, y, area.end.x - left, 40), ROW)
		draw_rect(Rect2(left, y, 6, 40), ORANGE)
		draw_text(TITLE_FONT, Vector2(left + 18, y + 26), mode[0], 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4)
		draw_text(FONT, Vector2(left + 160, y + 26), mode[1], fit_size(FONT, mode[1], 16, area.end.x - left - 170), TEXT)
		y += 46

# The deck of a side with its default bindings, and what each button does
func draw_controls(area: Rect2, player: int) -> void:
	var accent = P1_COLOR if player == 1 else P2_COLOR
	var device = player - 1
	var pad = "PAD %d" % player
	if binding_event(player, "key1") is InputEventKey:
		pad = "KEYBOARD"
	elif device in Input.get_connected_joypads():
		pad += ": " + Input.get_joy_name(device).to_upper()
	else:
		pad += " (NOT CONNECTED)"
	var deck_width = ControllerPanel.DECK_SIZE.x
	draw_text(TITLE_FONT, area.position + Vector2(0, 14), "YOUR CONTROLS", 14, accent, HORIZONTAL_ALIGNMENT_LEFT, 4)
	draw_text(FONT, area.position + Vector2(deck_width, 14), pad, fit_size(FONT, pad, 16, deck_width - 220), TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

	var deck: ControllerPanel = decks[player]
	deck.area = Rect2(area.position + Vector2(0, 28 - ControllerPanel.DECK_TOP), Vector2(deck_width, 0))
	deck.draw_deck(self, false)
	deck.draw_test_banner(self, Rect2(area.position.x + 640, area.position.y - 62, area.size.x - 640, 40))

	# Default bindings, two columns under the deck
	var rows_top = area.position.y + 28 + ControllerPanel.DECK_SIZE.y + 14
	var row_width = (deck_width - 10) / 2
	var rows = 7
	for i in BINDINGS.size():
		var rect = Rect2(area.position.x + (i / rows) * (row_width + 10), rows_top + (i % rows) * 27, row_width, 23)
		draw_rect(rect, ROW)
		draw_text(TITLE_FONT, Vector2(rect.position.x + 10, rect.position.y + 17), BINDINGS[i][1], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4)
		var binding = current_binding(player, BINDINGS[i][0])
		var label_width = TITLE_FONT.get_string_size(BINDINGS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_text(TITLE_FONT, Vector2(rect.end.x - 10, rect.position.y + 17), binding, fit_size(TITLE_FONT, binding, 12, rect.size.x - label_width - 34), accent, HORIZONTAL_ALIGNMENT_RIGHT, 4)

	var left = area.position.x + deck_width + 40
	var width = area.end.x - left
	var y = area.position.y
	for section in [["IN THE MENUS", MENU_ROLES], ["IN GAME", GAME_ROLES]]:
		draw_text(TITLE_FONT, Vector2(left, y + 16), section[0], 16, YELLOW, HORIZONTAL_ALIGNMENT_LEFT, 4)
		y += 26
		for role in section[1]:
			draw_text(TITLE_FONT, Vector2(left, y + 12), role[0], 11, ORANGE)
			y += draw_paragraph(Vector2(left + 150, y), role[1], width - 150, 14, TEXT) + 6
		y += 10
	var note = "E3 VEFX here: test your inputs on the deck, hold it 2 seconds to stop. Keyboard or another controller: OPTIONS > CONTROLLER SET UP. Arrows, Enter and Esc also work in the menus."
	draw_paragraph(Vector2(left, y), note, width, 14, PALE_BLUE)

# Current binding (remapped in CONTROLLER SET UP), a key first if there is one
func binding_event(player: int, action: String) -> InputEvent:
	var events = InputMap.action_get_events("p%d_%s" % [player, action])
	for event in events:
		if event is InputEventKey:
			return event
	return null if events.is_empty() else events[0]

func current_binding(player: int, action: String) -> String:
	var event = binding_event(player, action)
	if event == null:
		return "---"
	var text = decks[player].input_text(event)
	return text.replace(" +", "").replace(" -", "") if action.begins_with("analog") else text
