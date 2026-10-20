extends Control

# Result screen of the solo and local versus plays, like on IIDX: 1P on the left, 2P on the right,
# the song in the middle. START or a key goes back to the music select.

const ResultPanel = preload("res://scripts/result/result_panel.gd")
const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const FONT = preload("res://assets/font/FT2FONT.TTF")
const SONG_FONT = preload("res://assets/font/monofonto.otf")

const BACKGROUND_TOP = Color(0.02, 0.02, 0.06)
const BACKGROUND_BOTTOM = Color(0.07, 0.03, 0.12)
const TITLE_GLOW = Color(0.35, 0.5, 1, 0.6)
const TEXT_DIM = Color(0.6, 0.62, 0.7)
const MARGIN = 16.0
const PANEL_TOP = 74.0
# Rings turning behind the middle, in place of the IIDX character art
const RING_CENTER = Vector2(640, 360)
const RING_RADII = [70.0, 105.0, 140.0, 175.0]

var panels : Array = []
var elapsed := 0.0
var versus := false

func _ready() -> void:
	versus = Global.p1_joined and Global.p2_joined
	var players = [1, 2] if versus else [1 if Global.p1_joined else 2]
	for player in players:
		var panel = ResultPanel.new()
		panel.player = player
		add_child(panel)
		panel.position = Vector2(MARGIN if player == 1 else get_viewport_rect().size.x - MARGIN - panel.size.x, PANEL_TOP)
		panels.append(panel)
	# The panels have read the results
	Global.failed = false
	Global.p2_failed = false

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var confirm = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	for action in ["ui_accept", "p1_start", "p2_start", "p1_key1", "p2_key1", "p1_key7", "p2_key7"]:
		if event.is_action_pressed(action):
			confirm = true
	if not confirm:
		return
	get_viewport().set_input_as_handled()
	# The first press ends the reveal, the next one leaves
	if not panels.all(func(panel): return panel.revealed()):
		for panel in panels:
			panel.skip_reveal()
		return
	for player in [1, 2]:
		Global.set_player_var(player, "score", 0)
		Global.set_player_var(player, "ex_score", 0)
		Global.set_player_var(player, "combo_max", 0)
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")

func _draw() -> void:
	# Background: a dark gradient and slanted stripes
	var gradient = PackedColorArray([BACKGROUND_TOP, BACKGROUND_TOP, BACKGROUND_BOTTOM, BACKGROUND_BOTTOM])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), gradient)
	var shift = fmod(elapsed * 20.0, 48.0)
	for x in range(-int(size.y), int(size.x) + 48, 48):
		draw_line(Vector2(x + shift, size.y), Vector2(x + shift + size.y * 0.5, 0), Color(1, 1, 1, 0.025), 2.0)

	# Turning rings in the middle
	for i in RING_RADII.size():
		var radius : float = RING_RADII[i]
		var turn = elapsed * (0.4 if i % 2 == 0 else -0.25) * (1.0 + i * 0.2)
		for arc in 3:
			var start = turn + arc * TAU / 3.0
			draw_arc(RING_CENTER, radius, start, start + TAU / 5.0, 32, Color(0.4, 0.5, 1, 0.12 + 0.04 * i), 3.0 + i, true)
	draw_circle(RING_CENTER, 34, Color(0.4, 0.5, 1, 0.12))

	# Title
	var title = "STAGE RESULT" if not Netplay.active else "RESULT"
	var title_size = 32
	var title_width = TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var title_pos = Vector2((size.x - title_width) / 2, 50)
	draw_string_outline(TITLE_FONT, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 8, TITLE_GLOW)
	draw_string(TITLE_FONT, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	# Versus: WIN, LOSE or DRAW on each side of the middle
	if versus:
		var shown = clampf((elapsed - 1.2) / 0.3, 0.0, 1.0)
		for player in [1, 2]:
			var result = Global.get_versus_result(player)
			var color : Color = Global.VERSUS_RESULT_COLORS[result]
			var column = Rect2(640 - 170 if player == 1 else 640, 84, 170, 20)
			draw_centered(TITLE_FONT, column, "%dP" % player, 16, Color(TEXT_DIM, shown))
			draw_centered(TITLE_FONT, Rect2(column.position + Vector2(0, 30), Vector2(column.size.x, 50)), result, 40, Color(color, shown))

	# Song: title, artist, then the key to go on
	var info : Dictionary = Global.song_info
	var song_title : String = info.get("title", "")
	if song_title == "":
		song_title = Loader.file_path.get_file().get_basename()
	var middle = Rect2(470, 600, 340, 40)
	draw_centered(SONG_FONT, middle, song_title, 36, Color.WHITE, 8, Color(0.2, 0.25, 0.6))
	draw_centered(SONG_FONT, Rect2(middle.position + Vector2(0, 38), middle.size), info.get("artist", ""), 24, TEXT_DIM)
	if panels.all(func(panel): return panel.revealed()) and Time.get_ticks_msec() % 1000 < 650:
		draw_centered(TITLE_FONT, Rect2(470, 684, 340, 24), "PRESS START", 14, Color(1, 0.85, 0.2))

# Text centered in a box, made smaller if it does not fit
func draw_centered(font: Font, rect: Rect2, text: String, font_size: int, color: Color, outline := 0, outline_color := Color.BLACK) -> void:
	while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
		font_size -= 1
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline = rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2
	var pos = Vector2(rect.get_center().x - width / 2, baseline)
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
