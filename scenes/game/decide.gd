extends Control

# DECIDE screen of IIDX, shown by main.gd over the game while the chart loads: the difficulty at the top,
# the title on a band of a moving orange grid and lines, then the GAME OPTION panel of each player.
# It plays once the charts are loaded (play()), holds, fades out, then emits closed.

signal closed

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const STRIP_FONT = preload("res://assets/font/tallpixelfont.ttf")
const SongEntry = preload("res://scripts/menu/music_select/song_entry.gd")

const BACKGROUND = Color(0.07, 0.07, 0.08)
const RED = Color(0.9, 0.05, 0.05)
const ORANGE = Color(1, 0.36, 0)
const YELLOW = Color(1, 0.85, 0.2)
const METAL = Color(0.62, 0.62, 0.68)
const SEGMENT = Color(0.06, 0.06, 0.07)
const SEGMENT_TEXT = Color(0.86, 0.86, 0.9)
const LIT_TOP = Color(1, 0.78, 0.25)
const LIT_BORDER = Color(1, 0.92, 0.55)
const SMALL_TEXT = Color(0.6, 0.6, 0.65)
const PLAYER_COLORS = [Color(0.305, 0.305, 0.305), Color(0, 0.686, 1), Color(1, 0.157, 0)]

# Band of the title
const BAND_TOP = 228.0
const BAND_HEIGHT = 212.0
const BORDER = 5.0
# Grid of the band like grid.png, in orange, scrolling to the right
const GRID_CELL = 40.0
const GRID_SPEED = 60.0
const GRID_COLOR = Color(1, 0.45, 0.05, 0.85)
const LINE_COUNT = 14
const STREAK_COUNT = 9
# Option panels: 2 columns of 5 options like on IIDX
const PANEL_TOP = 466.0
const PANEL_SIZE = Vector2(592, 232)
const PANEL_MARGIN = 32.0
const HEADER_HEIGHT = 30.0
const CELL_GAP = Vector2(12, 6)
const CAP_WIDTH = 5.0

# Timeline (seconds from play()): everything comes in, holds, then fades out
const HOLD_TIME = 2.8
const OUT_TIME = 0.45
const CELL_DELAY = 0.035

var title := ""
var artist := ""
var tag := ""
var difficulty := ""
var level := 0
var style := ""
var started := false
var done := false
var start_usec := 0
# [x, slant, speed, width, alpha] crossing the band, and [y, x1, x2, speed] along it
var lines: Array = []
var flat_lines: Array = []
# [y, length, speed, phase]
var streaks: Array = []

func _ready() -> void:
	# The parent is a CanvasLayer, the anchors have no rect to follow
	size = get_viewport_rect().size
	mouse_filter = MOUSE_FILTER_IGNORE
	build_band()

func _process(_delta: float) -> void:
	queue_redraw()
	modulate.a = 1.0 - phase(HOLD_TIME, OUT_TIME)
	if started and not done and elapsed() >= HOLD_TIME + OUT_TIME:
		done = true
		closed.emit()
		get_parent().queue_free()

# Called once the charts are loaded
func play(song_title: String, song_artist: String, difficulty_name: String, chart_level: int) -> void:
	title = song_title
	artist = song_artist
	difficulty = difficulty_name
	level = chart_level
	if Arcade.active:
		tag = Arcade.current_stage_name()
	elif Training.active:
		tag = "TRAINING"
	elif Netplay.in_round():
		tag = "NETPLAY"
	else:
		var extension = Loader.file_path.get_extension().to_lower()
		tag = "MODULE" if extension in ModModule.EXTENSIONS else ("QUAVER" if extension == "qua" else "BMS")
	var player = 2 if Global.p2_joined and not Global.p1_joined else 1
	if Global.is_double_play():
		style = "DP 14 KEYS"
	else:
		style = "SP %d KEYS" % Global.get_player_var(player, "keys_mode")
	start_usec = Time.get_ticks_usec()
	started = true
	var whoosh = AudioStreamPlayer.new()
	whoosh.stream = preload("res://assets/music_select/open.ogg")
	add_child(whoosh)
	get_tree().create_timer(0.45).timeout.connect(whoosh.play)

func elapsed() -> float:
	return (Time.get_ticks_usec() - start_usec) / 1000000.0

# Eased progress of a part of the timeline, 0 before it starts, 1 once done
func phase(start: float, duration: float) -> float:
	if not started:
		return 0.0
	return ease(clampf((elapsed() - start) / duration, 0.0, 1.0), 0.3)

func build_band() -> void:
	var rng = RandomNumberGenerator.new()
	for i in LINE_COUNT:
		lines.append([rng.randf_range(0, 1680), rng.randf_range(-0.9, 0.9), rng.randf_range(15, 60),
			rng.randf_range(1, 3), rng.randf_range(0.3, 0.8)])
	for i in 4:
		flat_lines.append([rng.randf(), rng.randf(), rng.randf(), rng.randf_range(-0.05, 0.05)])
	for i in STREAK_COUNT:
		streaks.append([rng.randf_range(0.1, 0.9), rng.randf_range(60, 260), rng.randf_range(250, 700), rng.randf_range(0, 1600)])

func _draw() -> void:
	var out = phase(HOLD_TIME, OUT_TIME)
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	# Faint diagonal stripes
	for x in range(-720, int(size.x), 48):
		draw_line(Vector2(x, size.y), Vector2(x + size.y, 0), Color(1, 1, 1, 0.02), 14.0)
	if not started:
		return
	draw_band(phase(0.0, 0.3) * (1.0 - out))
	draw_header()
	draw_title()
	var rise = phase(0.5, 0.35)
	for player in [1, 2]:
		draw_panel(player, (1.0 - rise + out) * 260.0, rise)

func draw_band(opened: float) -> void:
	var t = elapsed()
	var height = BAND_HEIGHT * opened
	var top = BAND_TOP + (BAND_HEIGHT - height) / 2
	if height < 1:
		return
	draw_rect(Rect2(0, top, size.x, height), Color.BLACK)
	# Columns move to the right, rows spread from the middle as the band opens
	var column = fmod(t * GRID_SPEED, GRID_CELL) - GRID_CELL
	while column < size.x:
		draw_line(Vector2(column, top), Vector2(column, top + height), GRID_COLOR, 2.0)
		column += GRID_CELL
	var center = BAND_TOP + BAND_HEIGHT / 2
	var cell = GRID_CELL * opened
	for row in range(-ceili(BAND_HEIGHT / GRID_CELL / 2), ceili(BAND_HEIGHT / GRID_CELL / 2) + 1):
		var y = center + row * cell
		if y > top and y < top + height:
			draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 2.0)

	# Orange lines across the band, a few along it
	for line in lines:
		var x = fmod(line[0] + t * line[2], size.x + 400) - 200
		draw_line(Vector2(x, top), Vector2(x + line[1] * height, top + height), Color(ORANGE, line[4]), line[3])
	for line in flat_lines:
		var y1 = top + height * fmod(line[1] + t * line[3] + 1.0, 1.0)
		var y2 = top + height * fmod(line[2] - t * line[3] + 1.0, 1.0)
		draw_line(Vector2(0, y1), Vector2(size.x, y2), Color(ORANGE, 0.5), 2.0)
	# Yellow streaks running to the right
	for streak in streaks:
		var x = fmod(streak[3] + t * streak[2], size.x + streak[1]) - streak[1]
		draw_rect(Rect2(x, top + height * streak[0], streak[1], 3), Color(YELLOW, 0.75))

	# Flash when the title lands
	var flash = 1.0 - phase(0.25, 0.4)
	if flash < 1.0:
		draw_rect(Rect2(0, top, size.x, height), Color(1, 0.9, 0.7, 0.5 * flash))
	draw_rect(Rect2(0, top - BORDER, size.x, BORDER), RED)
	draw_rect(Rect2(0, top + height, size.x, BORDER), RED)
	draw_rect(Rect2(0, top - BORDER - 3, size.x, 1), Color(RED, 0.6))
	draw_rect(Rect2(0, top + height + BORDER + 2, size.x, 1), Color(RED, 0.6))

# Red bar and small captions on the left, DIFFICULTY on the right
func draw_header() -> void:
	var grow = phase(0.1, 0.4)
	draw_rect(Rect2(48, 196 - 160 * grow, 14, 160 * grow), RED)
	var typed = phase(0.4, 0.5)
	var captions = ["noiseBMS", "MUSIC DECIDE", style]
	for i in captions.size():
		var text: String = captions[i]
		draw_string(STRIP_FONT, Vector2(76, 160 + i * 18), text.left(int(text.length() * typed)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, SMALL_TEXT)

	var slide = phase(0.3, 0.35)
	var shift = (1.0 - slide) * 240.0
	var right = size.x - 90 + shift
	var color = SongEntry.difficulty_color(difficulty, level)
	var name_size = fit_size(TITLE_FONT, difficulty.to_upper(), 72, 760)
	draw_right(TITLE_FONT, Vector2(right, 76), "DIFFICULTY", 16, Color(1, 1, 1, slide), 0)
	draw_right(TITLE_FONT, Vector2(right, 160), difficulty.to_upper(), name_size, Color(color, slide), 10, Color(0, 0, 0, slide))
	draw_right(STRIP_FONT, Vector2(right, 196), "LEVEL %d" % level, 28, Color(1, 1, 1, slide), 4, Color(0, 0, 0, slide))
	# Chevrons pointing at the name
	for i in 2:
		var pulse = 0.5 + 0.5 * sin(elapsed() * TAU * 1.5 - i)
		var x = size.x - 74 + shift + i * 18
		var points = PackedVector2Array([Vector2(x + 12, 132), Vector2(x, 144), Vector2(x + 12, 156), Vector2(x + 16, 156), Vector2(x + 4, 144), Vector2(x + 16, 132)])
		draw_colored_polygon(points, Color(ORANGE.lerp(YELLOW, pulse), slide))

# Tag, title and artist in the middle of the band
func draw_title() -> void:
	var center = BAND_TOP + BAND_HEIGHT / 2
	var landed = phase(0.2, 0.35)
	var x = size.x / 2 + (1.0 - landed) * 320.0
	var title_size = fit_size(TITLE_FONT, title, 64, size.x - 160)
	draw_centered(TITLE_FONT, Vector2(x + 4, center + 18 + 4), title, title_size, Color(RED.darkened(0.5), landed * 0.8), 0)
	draw_centered(TITLE_FONT, Vector2(x, center + 18), title, title_size, Color(1, 1, 1, landed), 12, Color(0.1, 0.02, 0.0, landed))
	var shown = phase(0.35, 0.3)
	draw_centered(TITLE_FONT, Vector2(size.x / 2, center - 64 + (1.0 - shown) * -20), tag, 22, Color(1, 1, 1, shown), 8, Color(0.1, 0.02, 0.0, shown))
	draw_centered(STRIP_FONT, Vector2(size.x / 2, center + 70 + (1.0 - shown) * 20), artist, fit_size(STRIP_FONT, artist, 36, size.x - 160), Color(1, 1, 1, shown), 8, Color(0.1, 0.02, 0.0, shown))

func is_joined(player: int) -> bool:
	return Global.get("p%d_joined" % player)

# GAME OPTION panel of a player, ABSENCE when nobody plays this side, DOUBLE PLAY for the side of a double play
func draw_panel(player: int, drop: float, alpha: float) -> void:
	var rect = Rect2(PANEL_MARGIN if player == 1 else size.x - PANEL_MARGIN - PANEL_SIZE.x, PANEL_TOP + drop, PANEL_SIZE.x, PANEL_SIZE.y)
	var joined = is_joined(player)
	var double_side = not joined and Global.is_double_play()
	var color = PLAYER_COLORS[player] if joined else (PLAYER_COLORS[3 - player] if double_side else PLAYER_COLORS[0])
	var dim = 1.0 if joined else 0.35
	draw_rect(rect, Color(0.1, 0.1, 0.11, alpha * dim))
	draw_rect(rect, Color(color, alpha * dim), false, 3.0)
	var header = Rect2(rect.position, Vector2(rect.size.x, HEADER_HEIGHT))
	draw_rect(header, Color(color, alpha * dim))
	var dj_name = Global.p1_name if player == 1 else Global.p2_name
	var caption = "PLAYER %d" % player if dj_name == "" else "DJ " + dj_name
	if double_side:
		caption = "DOUBLE PLAY"
	elif not joined:
		caption = "ABSENCE %d" % player
	draw_fitted(TITLE_FONT, header, caption + "   GAME OPTION", 18, Color(0, 0, 0, alpha * dim))
	if double_side:
		return

	var options = panel_options(player)
	var inner = Rect2(rect.position.x + 14, rect.position.y + HEADER_HEIGHT + 10, rect.size.x - 28, rect.size.y - HEADER_HEIGHT - 20)
	var rows = options.size() / 2
	var cell_size = Vector2((inner.size.x - CELL_GAP.x) / 2, (inner.size.y - CELL_GAP.y * (rows - 1)) / rows)
	for i in options.size():
		var column = i / rows
		var row = i % rows
		var cell = Rect2(inner.position + Vector2(column * (cell_size.x + CELL_GAP.x), row * (cell_size.y + CELL_GAP.y)), cell_size)
		# Chosen options light up one after the other
		var light = phase(0.85 + i * CELL_DELAY, 0.15)
		draw_cell(cell, options[i][0], joined and options[i][1] and light > 0.0, 1.0 - light, color, alpha * dim)

# [text, chosen] of each option, left column then right column
func panel_options(player: int) -> Array:
	var hispeed = Global.get_player_var(player, "hispeed")
	var gauge = Global.get_player_var(player, "gauge_level")
	var effector = Effector.index != 0
	return [
		["HI-SPEED  %.2f" % hispeed if is_joined(player) else "HI-SPEED", hispeed != 1.0],
		[["EASY or HARD", "EASY", "HARD"][gauge], gauge != 0],
		["RANDOM", Global.get_player_var(player, "random")],
		["5KEYS", Global.get_player_var(player, "keys_mode") == 5],
		["AUTO PLAY", Global.is_auto_play(player)],
		["BATTLE", Global.is_battle()],
		["DOUBLE", Global.is_double_play() and Global.get_player_var(player, "double_play")],
		["MIRROR", Global.get_player_var(player, "mirror")],
		["AUTO SCRATCH", Global.get_player_var(player, "auto_scratch")],
		["SUDDEN+", Global.has_sudden(player)],
		["LIFT", Global.has_lift(player)],
		[Effector.current_name() if effector else "EFFECTOR", effector],
	]

# An option in a metal frame with caps of the player color: orange when chosen, a white flash as it lights up
func draw_cell(rect: Rect2, text: String, lit: bool, flash: float, color: Color, alpha: float) -> void:
	draw_rect(rect.grow(2), Color(METAL, alpha), false, 2.0)
	draw_rect(Rect2(rect.position, Vector2(CAP_WIDTH, rect.size.y)), Color(color, alpha))
	draw_rect(Rect2(rect.end.x - CAP_WIDTH, rect.position.y, CAP_WIDTH, rect.size.y), Color(color, alpha))
	var segment = Rect2(rect.position.x + CAP_WIDTH + 2, rect.position.y, rect.size.x - 2 * (CAP_WIDTH + 2), rect.size.y)
	# The text fits the height of the cells too
	var text_size = mini(26, int(rect.size.y))
	if not lit:
		draw_rect(segment, Color(SEGMENT, alpha))
		draw_rect(Rect2(segment.position, Vector2(segment.size.x, 1)), Color(1, 1, 1, 0.08 * alpha))
		draw_fitted(STRIP_FONT, segment, text, text_size, Color(SEGMENT_TEXT, alpha), Color(0, 0, 0, alpha))
		return
	var top = LIT_TOP.lerp(Color.WHITE, flash)
	var bottom = ORANGE.lerp(Color.WHITE, flash)
	draw_polygon(PackedVector2Array([segment.position, Vector2(segment.end.x, segment.position.y), segment.end, Vector2(segment.position.x, segment.end.y)]),
		PackedColorArray([Color(top, alpha), Color(top, alpha), Color(bottom, alpha), Color(bottom, alpha)]))
	draw_rect(segment, Color(LIT_BORDER, alpha), false, 1.0)
	draw_fitted(STRIP_FONT, segment, text, text_size, Color(1, 1, 1, alpha), Color(0.45, 0.12, 0, alpha))

# Largest size up to font_size where the text fits in width
func fit_size(font: Font, text: String, font_size: int, width: float) -> int:
	while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	return font_size

func draw_outlined(font: Font, at: Vector2, text: String, font_size: int, color: Color, outline_size: int, outline: Color) -> void:
	if outline_size > 0:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func draw_centered(font: Font, at: Vector2, text: String, font_size: int, color: Color, outline_size: int, outline := Color.BLACK) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_outlined(font, at - Vector2(width / 2, 0), text, font_size, color, outline_size, outline)

func draw_right(font: Font, at: Vector2, text: String, font_size: int, color: Color, outline_size: int, outline := Color.BLACK) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_outlined(font, at - Vector2(width, 0), text, font_size, color, outline_size, outline)

# Text centered in a rect, made smaller until it fits
func draw_fitted(font: Font, rect: Rect2, text: String, font_size: int, color: Color, outline := Color.TRANSPARENT) -> void:
	font_size = fit_size(font, text, font_size, rect.size.x - 6)
	var baseline = rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2
	draw_centered(font, Vector2(rect.get_center().x, baseline), text, font_size, color, 4 if outline.a > 0 else 0, outline)
