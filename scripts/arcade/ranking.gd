extends Control

# Ranking of the arcade games after the NAME ENTRY: the best total EX scores,
# the new game blinking. A key or the time goes back to the title menu.

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const SONG_FONT = preload("res://assets/font/monofonto.otf")
const INFO_BAR = preload("res://assets/music_select/music_select_info.png")
const INFO_BAR_LEFT = -1888.0

const PANEL = Color(0, 0, 0, 0.7)
const ROW = Color(0.05, 0.05, 0.05)
const TAG_BORDER = Color(0.45, 0.45, 0.45)
const ORANGE = Color(1, 0.55, 0.05)
const YELLOW = Color(1, 0.82, 0.1)
const PALE_BLUE = Color(0.6, 0.7, 1)
const TEXT_DIM = Color(0.6, 0.62, 0.7)
# Gold, silver and bronze
const PODIUM_COLORS = [Color(1, 0.85, 0.2), Color(0.8, 0.85, 0.9), Color(0.85, 0.5, 0.25)]
const HEADER_HEIGHT = 113.0
const FOOTER_HEIGHT = 64.0
const SHOWN = 10
const ROW_HEIGHT = 36.0
const ROW_GAP = 4.0
const TABLE_TOP = 168.0
# Columns: rank, DJ name, DJ LEVEL, EX score, date (x from the left of the table)
const COLUMNS = [24, 110, 330, 560, 700]
const SHOW_TIME = 20.0
# Rows sliding in one after the other
const ROW_DELAY = 0.06
const ROW_SLIDE = 0.25

var entries: Array = []
var elapsed := 0.0
var leaving = false

func _ready() -> void:
	entries = Arcade.load_ranking(Arcade.is_double())

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= SHOW_TIME:
		leave()

func _unhandled_input(event: InputEvent) -> void:
	var confirm = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	for action in ["ui_accept", "ui_cancel", "p1_start", "p2_start"]:
		if event.is_action_pressed(action):
			confirm = true
	for player in [1, 2]:
		for key in 7:
			if event.is_action_pressed("p%d_key%d" % [player, key + 1]):
				confirm = true
	if confirm:
		get_viewport().set_input_as_handled()
		leave()

func leave() -> void:
	if leaving:
		return
	leaving = true
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func draw_text(font: Font, at: Vector2, text: String, font_size: int, text_color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, outline_color := Color.BLACK) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x = at.x - (width if alignment == HORIZONTAL_ALIGNMENT_RIGHT else width / 2 if alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
	if outline > 0:
		draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func _draw() -> void:
	var bottom = size.y - FOOTER_HEIGHT - 8
	draw_rect(Rect2(0, HEADER_HEIGHT, size.x, bottom - HEADER_HEIGHT), PANEL)
	draw_rect(Rect2(0, HEADER_HEIGHT + 4, size.x, 3), ORANGE)
	draw_rect(Rect2(0, bottom - 7, size.x, 3), ORANGE)
	draw_table()
	draw_header()
	draw_footer(bottom)

func draw_table() -> void:
	var table = Rect2(160, TABLE_TOP, size.x - 320, ROW_HEIGHT)
	var heads = ["RANK", "DJ NAME", "DJ LEVEL", "EX SCORE", "DATE"]
	for column in heads.size():
		draw_text(TITLE_FONT, Vector2(table.position.x + COLUMNS[column], TABLE_TOP - 14), heads[column], 12, ORANGE)
	if entries.is_empty():
		draw_text(TITLE_FONT, Vector2(size.x / 2, TABLE_TOP + 120), "NO RECORD", 32, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return
	# The new game is shown under the 10 best when it is not in them
	var rows = range(mini(entries.size(), SHOWN))
	if Arcade.last_rank >= SHOWN:
		rows.append(Arcade.last_rank)
	for slot in rows.size():
		var y = TABLE_TOP + slot * (ROW_HEIGHT + ROW_GAP)
		if slot == SHOWN:
			y += 12
		var slide = 1.0 - ease(clampf((elapsed - slot * ROW_DELAY) / ROW_SLIDE, 0.0, 1.0), 0.3)
		draw_row(Rect2(table.position.x + slide * 120, y, table.size.x, ROW_HEIGHT), rows[slot], 1.0 - slide)

func draw_row(row: Rect2, rank: int, alpha: float) -> void:
	var entry: Dictionary = entries[rank]
	var new_game = rank == Arcade.last_rank
	var lit = new_game and Time.get_ticks_msec() % 600 < 400
	draw_rect(row, Color(Color(ORANGE, 0.45) if lit else ROW, alpha))
	var accent = PODIUM_COLORS[rank] if rank < PODIUM_COLORS.size() else TAG_BORDER
	draw_rect(Rect2(row.position, Vector2(4, row.size.y)), Color(YELLOW if new_game else accent, alpha))
	var baseline = row.end.y - 10
	var x = row.position.x
	draw_text(TITLE_FONT, Vector2(x + COLUMNS[0], baseline), "%d" % (rank + 1), 20, Color(accent if rank < 3 else Color.WHITE, alpha), HORIZONTAL_ALIGNMENT_LEFT, 4)
	draw_text(TITLE_FONT, Vector2(x + COLUMNS[1], baseline), entry.get("name", ""), 20, Color(Color.WHITE, alpha), HORIZONTAL_ALIGNMENT_LEFT, 4)
	draw_text(TITLE_FONT, Vector2(x + COLUMNS[2], baseline), Scores.rank(entry.get("rate", 0.0)), 20, Color(YELLOW, alpha), HORIZONTAL_ALIGNMENT_LEFT, 4)
	draw_text(TITLE_FONT, Vector2(x + COLUMNS[3] + 100, baseline), "%d" % entry.get("ex_score", 0), 20, Color(PALE_BLUE, alpha), HORIZONTAL_ALIGNMENT_RIGHT, 4)
	draw_text(SONG_FONT, Vector2(x + COLUMNS[4], baseline + 2), entry.get("date", ""), 22, Color(Color.WHITE if lit else TEXT_DIM, alpha))
	if new_game:
		draw_text(TITLE_FONT, Vector2(row.end.x + 12, baseline), "NEW", 14, Color(YELLOW, alpha))

func draw_header() -> void:
	draw_texture(INFO_BAR, Vector2(size.x + INFO_BAR_LEFT, 0))
	draw_text(TITLE_FONT, Vector2(16, 16 + TITLE_FONT.get_ascent(32)), "ranking", 32, Color.WHITE)
	# Single play and double play games have their own ranking
	draw_text(TITLE_FONT, Vector2(16, 16 + TITLE_FONT.get_ascent(32) + 30), "DOUBLE PLAY" if Arcade.is_double() else "SINGLE PLAY", 16, YELLOW)
	# No tag here
	draw_rect(Rect2(size.x + INFO_BAR_LEFT + 1303, 0, 600, 98), Color.BLACK)

# Songs of the new game, then the key to go on
func draw_footer(top: float) -> void:
	draw_rect(Rect2(0, top, size.x, size.y - top), Color.BLACK)
	draw_rect(Rect2(0, top, size.x, 4), Color.RED)
	var bar = Rect2(20, top + 10, size.x - 40, FOOTER_HEIGHT - 8)
	draw_rect(bar, TAG_BORDER, false, 2.0)
	var songs = " / ".join(entries[Arcade.last_rank].get("songs", [])) if Arcade.last_rank >= 0 and Arcade.last_rank < entries.size() else ""
	var font_size = 24
	while font_size > 8 and SONG_FONT.get_string_size(songs, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > bar.size.x - 260:
		font_size -= 1
	draw_text(SONG_FONT, Vector2(bar.position.x + 20, bar.get_center().y + 9), songs, font_size, TEXT_DIM)
	if Time.get_ticks_msec() % 1000 < 650:
		draw_text(TITLE_FONT, Vector2(bar.end.x - 20, bar.get_center().y + 8), "PRESS START", 18, YELLOW, HORIZONTAL_ALIGNMENT_RIGHT)
