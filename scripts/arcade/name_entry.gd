extends Control

# NAME ENTRY at the end of an arcade game, like IIDX: 6 letters chosen with the turntable,
# a white key goes to the next one, a black key back, START ends. Then the ranking.

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const SONG_FONT = preload("res://assets/font/monofonto.otf")
const INFO_BAR = preload("res://assets/music_select/music_select_info.png")
const INFO_BAR_LEFT = -1888.0
const NAME_CHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.!?*#&$@"
# Name of a player who entered nothing
const DEFAULT_NAME = "PLAYER"

const PANEL = Color(0, 0, 0, 0.7)
const ROW = Color(0.05, 0.05, 0.05)
const TAG_BORDER = Color(0.45, 0.45, 0.45)
const ORANGE = Color(1, 0.55, 0.05)
const YELLOW = Color(1, 0.82, 0.1)
const PALE_BLUE = Color(0.6, 0.7, 1)
const HEADER_HEIGHT = 113.0
const FOOTER_HEIGHT = 64.0
const BOX_SIZE = Vector2(64, 76)
const BOX_GAP = 12.0
const ANALOG_STEP = 0.08
const SOUND_VOLUME_DB = -10.0
const LEAVE_TIME = 0.6

var name_chars: Array[String] = []
var cursor = 0
var analog_previous = [0.0, 0.0]
var analog_remainder = [0.0, 0.0]
var repeat_direction = 0
var repeat_time = 0.0
var done = false
var timer: Control
var scroll_sound: AudioStreamPlayer
var decide_sound: AudioStreamPlayer
var cancel_sound: AudioStreamPlayer

func _ready() -> void:
	# The name of the side that plays
	var dj_name = Global.p2_name if Global.p2_joined and not Global.p1_joined else Netplay.dj_name
	for i in Netplay.NAME_LENGTH:
		var letter = dj_name[i] if i < dj_name.length() else " "
		name_chars.append(letter if NAME_CHARS.contains(letter) else " ")
	scroll_sound = add_sound(preload("res://assets/music_select/scroll.wav"))
	decide_sound = add_sound(preload("res://assets/music_select/decide.wav"))
	cancel_sound = add_sound(preload("res://assets/music_select/cancel.wav"))
	for player in [1, 2]:
		analog_previous[player - 1] = analog_value(player)
	timer = preload("res://scripts/arcade/arcade_timer.gd").new()
	timer.timeout.connect(confirm)
	add_child(timer)
	timer.start(Arcade.NAME_ENTRY_TIME)

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
	if done:
		return
	if steps != 0:
		change_letter(steps)
	for player in [1, 2]:
		if Input.is_action_just_pressed("p%d_start" % player):
			confirm()
			return
		for key in ["key1", "key3", "key5", "key7"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, key]):
				next_letter()
				return
		for key in ["key2", "key4", "key6"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, key]):
				previous_letter()
				return

func analog_value(player: int) -> float:
	return Input.get_action_strength("p%d_analog_turntable_fwd" % player) - Input.get_action_strength("p%d_analog_turntable_rew" % player)

# Steps of both turntables, like the menu
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

# Keyboard: letters typed, arrows, Enter and Backspace
func _unhandled_input(event: InputEvent) -> void:
	if done or not (event is InputEventKey and event.pressed) or is_player_input(event):
		return
	match event.keycode:
		KEY_UP, KEY_LEFT: change_letter(-1)
		KEY_DOWN, KEY_RIGHT: change_letter(1)
		KEY_ENTER, KEY_KP_ENTER: confirm()
		KEY_BACKSPACE, KEY_ESCAPE: previous_letter()
		_:
			var letter = char(event.unicode).to_upper() if event.unicode > 0 else ""
			if letter != "" and NAME_CHARS.contains(letter):
				name_chars[cursor] = letter
				next_letter()

func is_player_input(event: InputEvent) -> bool:
	for action in InputMap.get_actions():
		if (action.begins_with("p1_") or action.begins_with("p2_")) and event.is_action(action):
			return true
	return false

func change_letter(steps: int) -> void:
	var index = NAME_CHARS.find(name_chars[cursor])
	name_chars[cursor] = NAME_CHARS[posmod(index + steps, NAME_CHARS.length())]
	scroll_sound.play()

func next_letter() -> void:
	if cursor == Netplay.NAME_LENGTH - 1:
		confirm()
		return
	cursor += 1
	decide_sound.play()

func previous_letter() -> void:
	if cursor > 0:
		cursor -= 1
		cancel_sound.play()

func confirm() -> void:
	if done:
		return
	done = true
	timer.running = false
	decide_sound.play()
	var dj_name = Netplay.clean_name("".join(name_chars))
	Arcade.save_ranking(dj_name if dj_name != "" else DEFAULT_NAME)
	Arcade.stop()
	await get_tree().create_timer(LEAVE_TIME).timeout
	get_tree().change_scene_to_file("res://scenes/arcade/ranking.tscn")

func blink() -> bool:
	return Time.get_ticks_msec() % 500 < 300

func draw_text(font: Font, at: Vector2, text: String, font_size: int, text_color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, outline_color := Color.BLACK) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x = at.x - (width if alignment == HORIZONTAL_ALIGNMENT_RIGHT else width / 2 if alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
	if outline > 0:
		draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

# Text made smaller until it fits the width
func fit_size(font: Font, text: String, font_size: int, width: float) -> int:
	while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	return font_size

func _draw() -> void:
	var bottom = size.y - FOOTER_HEIGHT - 8
	draw_rect(Rect2(0, HEADER_HEIGHT, size.x, bottom - HEADER_HEIGHT), PANEL)
	draw_rect(Rect2(0, HEADER_HEIGHT + 4, size.x, 3), ORANGE)
	draw_rect(Rect2(0, bottom - 7, size.x, 3), ORANGE)
	draw_name()
	draw_stages()
	draw_header()
	draw_footer(bottom)

func draw_name() -> void:
	var center = size.x / 2
	draw_text(TITLE_FONT, Vector2(center, 190), "ENTER YOUR NAME", 32, YELLOW, HORIZONTAL_ALIGNMENT_CENTER, 8, Color(0.45, 0.18, 0))
	var count = Netplay.NAME_LENGTH
	var left = center - (count * BOX_SIZE.x + (count - 1) * BOX_GAP) / 2
	for i in count:
		var box = Rect2(left + i * (BOX_SIZE.x + BOX_GAP), 216, BOX_SIZE.x, BOX_SIZE.y)
		var current = i == cursor and not done
		draw_rect(Rect2(box.position + Vector2(6, 6), box.size), Color(0, 0, 0, 0.5))
		draw_rect(box, Color(ORANGE, 0.8) if current and blink() else ROW)
		draw_rect(box, YELLOW if current else Color(1, 1, 1, 0.5), false, 3.0)
		var letter = name_chars[i] if name_chars[i] != " " else "_"
		draw_text(TITLE_FONT, Vector2(box.get_center().x + 2, box.end.y - 18), letter, 48, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6)
		# Arrows of the turntable around the current letter
		if current:
			var x = box.get_center().x
			draw_colored_polygon([Vector2(x - 12, box.position.y - 8), Vector2(x + 12, box.position.y - 8), Vector2(x, box.position.y - 20)], ORANGE)
			draw_colored_polygon([Vector2(x - 12, box.end.y + 8), Vector2(x + 12, box.end.y + 8), Vector2(x, box.end.y + 20)], ORANGE)

# The stages of the game and the total EX score that goes into the ranking
func draw_stages() -> void:
	var table = Rect2(240, 340, size.x - 480, 40)
	for i in Arcade.stages.size():
		var stage = Arcade.stages[i]
		var row = Rect2(table.position + Vector2(0, i * (table.size.y + 8)), table.size)
		draw_rect(row, ROW)
		draw_rect(Rect2(row.position, Vector2(4, row.size.y)), ORANGE)
		draw_text(TITLE_FONT, Vector2(row.position.x + 16, row.end.y - 13), Arcade.stage_name(i), 14, ORANGE)
		var title = "%s [%s]" % [stage["title"], stage["difficulty"]]
		draw_text(SONG_FONT, Vector2(row.position.x + 210, row.end.y - 11), title, fit_size(SONG_FONT, title, 24, row.size.x - 380), Color.WHITE)
		draw_text(TITLE_FONT, Vector2(row.end.x - 16, row.end.y - 12), "EX %d" % stage["ex_score"], 16, PALE_BLUE, HORIZONTAL_ALIGNMENT_RIGHT)
	var total_y = table.position.y + Arcade.STAGES * (table.size.y + 8) + 40
	draw_text(TITLE_FONT, Vector2(table.position.x + 16, total_y), "TOTAL EX SCORE", 20, Color.WHITE)
	var total = "%s  %d" % [Scores.rank(Arcade.total_rate()), Arcade.total_ex()]
	draw_text(TITLE_FONT, Vector2(table.end.x - 16, total_y + 4), total, 32, YELLOW, HORIZONTAL_ALIGNMENT_RIGHT, 6)

func draw_header() -> void:
	draw_texture(INFO_BAR, Vector2(size.x + INFO_BAR_LEFT, 0))
	draw_text(TITLE_FONT, Vector2(16, 16 + TITLE_FONT.get_ascent(32)), "name entry", 32, Color.WHITE)
	# No OPTIONS tag here
	draw_rect(Rect2(size.x + INFO_BAR_LEFT + 1303, 0, 210, 98), Color.BLACK)

func draw_footer(top: float) -> void:
	draw_rect(Rect2(0, top, size.x, size.y - top), Color.BLACK)
	draw_rect(Rect2(0, top, size.x, 4), Color.RED)
	var bar = Rect2(20, top + 10, size.x - 40, FOOTER_HEIGHT - 8)
	draw_rect(bar, TAG_BORDER, false, 2.0)
	var help = "TURNTABLE: LETTER    WHITE: NEXT    BLACK: BACK    START: END"
	draw_text(TITLE_FONT, Vector2(bar.get_center().x, bar.get_center().y + 8), help, fit_size(TITLE_FONT, help, 18, bar.size.x - 40), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
