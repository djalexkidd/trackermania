extends Control

# Result of one player drawn like on IIDX: gauge graph with the DJ LEVEL, best and current scores,
# target, judgements and FAST/SLOW. The differences with the best score stick out towards the middle.

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const NUMBER_FONT = preload("res://assets/font/digitalix.ttf")

# Columns of the score rows: name, best, current
const LABEL_W = 132.0
const VALUE_W = 92.0
const SEPARATOR_W = 8.0
const PANEL_W = LABEL_W + VALUE_W + SEPARATOR_W + VALUE_W
# UP!/DOWN arrow and difference box, outside the panel
const ARROW_W = 30.0
const DIFF_W = 100.0
const PANEL_SIZE = Vector2(PANEL_W + ARROW_W + DIFF_W, 640)

# Graph box
const GRAPH_BOX = Rect2(0, 0, PANEL_W, 174)
const GRAPH = Rect2(6, 6, PANEL_W - 12, 128)
const STRIP_TOP = 140.0
const STRIP_H = 26.0
# Score rows
const TAGS_TOP = 180.0
const ROWS_TOP = 202.0
const ROW_H = 28.0
const ROW_STEP = 31.0
# Judgement rows
const JUDGE_TOP = 392.0
const JUDGE_H = 22.0
const JUDGE_STEP = 25.0
const GROUP_GAP = 7.0

const BOX = Color(0.07, 0.07, 0.09)
const BOX_LIGHT = Color(0.14, 0.14, 0.17)
const BOX_BORDER = Color(0.32, 0.32, 0.38)
const CURRENT_BORDER = Color(0.85, 0.6, 0.2)
const NUMBER = Color(0.35, 0.85, 1)
const NUMBER_DIM = Color(0.35, 0.85, 1, 0.3)
const TEXT_DIM = Color(0.6, 0.62, 0.7)
const UP = Color(1, 0.6, 0.1)
const DOWN = Color(0.3, 0.65, 1)
const MINUS = Color(1, 0.25, 0.2)
const GRAPH_BG = Color(0.02, 0.08, 0.09)
const GRAPH_GRID = Color(0.3, 0.6, 0.6, 0.15)
const CLEAR_BAND = Color(0.4, 0.03, 0.06)
const LINE_GREEN = Color(0.2, 1, 0.3)
const LINE_RED = Color(1, 0.2, 0.2)
const DJ_LEVEL_COLOR = Color(0.65, 1, 0.95)
const FAST_COLOR = Color(0.3, 0.6, 1)
const SLOW_COLOR = Color(1, 0.35, 0.3)
const P1_COLOR = Color(0, 0.686275, 1)
const P2_COLOR = Color(1, 0.156863, 0)
# Short lamp names of the CLEAR TYPE row, like Scores.LAMPS
const LAMP_SHORT = ["FAILED", "A-CLEAR", "E-CLEAR", "CLEAR", "H-CLEAR", "F-COMBO", "PERFECT"]
const GAUGES = ["NORMAL", "EASY", "HARD"]
const JUDGEMENTS = [
	["P-GREAT", "PGreat", Color(0.75, 0.95, 1)],
	["GREAT", "Great", Color(1, 0.88, 0.35)],
	["GOOD", "Good", Color(0.55, 1, 0.45)],
	["BAD", "Bad", Color(0.55, 0.6, 1)],
	["POOR", "Poor", Color(1, 0.4, 0.45)],
]

# Reveal: the graph line is drawn, then the rows come one by one and the numbers count up
const GRAPH_TIME = 0.9
const ROW_DELAY = 0.25
const ROW_INTERVAL = 0.045
const ROW_FADE = 0.2
const COUNT_TIME = 0.8
const DJ_LEVEL_POP = 0.25
const REVEAL_TIME = 1.6

@export var player : int = 1

var elapsed := 0.0
var details : Dictionary
var best : Dictionary
var lamp : int
var rate : float
var ex_score : int
var max_ex : int
var miss_count : int
var rank_index : int
var target_name : String
var target_ex : int
# x of the score panel: the differences go to the right on the 1P side, to the left on the 2P side
# Opacity of the row being drawn (begin_row)
var row_alpha := 1.0
var panel_x : float
var diff_x : float
var arrow_x : float

func _ready() -> void:
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	details = Global.get_player_var(player, "result")
	best = details.get("previous_best", {})
	lamp = Scores.lamp(player)
	rate = Global.get_player_var(player, "score")
	ex_score = Global.get_player_var(player, "ex_score")
	max_ex = details.get("note_count", 0) * 2
	miss_count = details.get("miss_count", 0)
	rank_index = Scores.rank_index(rate)
	# Pacemaker of the next DJ LEVEL, the maximum score once AAA is reached
	var next_rank = rank_index + 1
	while next_rank <= 8 and ceili(max_ex * next_rank / 9.0 - 0.000001) <= ex_score:
		next_rank += 1
	if next_rank <= 8:
		target_name = "PACEMAKER " + Scores.RANKS[next_rank]
		target_ex = ceili(max_ex * next_rank / 9.0 - 0.000001)
	else:
		target_name = "PACEMAKER MAX"
		target_ex = max_ex
	if player == 1:
		panel_x = 0.0
		arrow_x = PANEL_W
		diff_x = PANEL_W + ARROW_W
	else:
		panel_x = ARROW_W + DIFF_W
		arrow_x = DIFF_W
		diff_x = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func skip_reveal() -> void:
	elapsed = maxf(elapsed, REVEAL_TIME)

func revealed() -> bool:
	return elapsed >= REVEAL_TIME

# Part of the values shown while they count up during the reveal
func count_progress() -> float:
	return clampf((elapsed - ROW_DELAY) / COUNT_TIME, 0.0, 1.0)

func counted(value: int) -> int:
	return roundi(value * count_progress())

func _draw() -> void:
	row_alpha = 1.0
	draw_graph_box()
	var accent = P1_COLOR if player == 1 else P2_COLOR
	var row = 0

	# Side of the player above the names, BEST and NOW tags above the values
	begin_row(row)
	draw_text(TITLE_FONT, Rect2(panel_x + 2, TAGS_TOP, LABEL_W, 18), "%dP" % player, 14, accent, HORIZONTAL_ALIGNMENT_LEFT)
	draw_tag(Rect2(panel_x + LABEL_W + 6, TAGS_TOP + 1, VALUE_W - 12, 16), "BEST")
	draw_tag(Rect2(panel_x + LABEL_W + VALUE_W + SEPARATOR_W + 6, TAGS_TOP + 1, VALUE_W - 12, 16), "NOW")
	row += 1

	# Options of the play, written in the TARGET row
	var options = [GAUGES[Global.get_player_var(player, "gauge_level")]]
	if Global.get_player_var(player, "random"):
		options.append("RANDOM")
	if Global.get_player_var(player, "keys_mode") == 5:
		options.append("5KEYS")
	if Global.get_player_var(player, "auto_scratch"):
		options.append("A-SCR")
	if Global.get_player_var(player, "auto_play"):
		options.append("AUTO PLAY")

	# CLEAR TYPE, DJ LEVEL, EX SCORE, MISS COUNT: best before this play, then this play
	var played = not best.is_empty()
	var y = ROWS_TOP
	begin_row(row)
	var cells = score_row(y, "CLEAR TYPE")
	if played:
		draw_text(TITLE_FONT, cells[0], LAMP_SHORT[best["lamp"]], 13, Scores.LAMP_COLORS[best["lamp"]])
		draw_change(y, signi(lamp - best["lamp"]))
	else:
		draw_text(TITLE_FONT, cells[0], "NO PLAY", 13, TEXT_DIM)
	draw_text(TITLE_FONT, cells[1], LAMP_SHORT[lamp], 13, Scores.LAMP_COLORS[lamp])
	row += 1

	y += ROW_STEP
	begin_row(row)
	cells = score_row(y, "DJ LEVEL")
	if played:
		var best_rank = Scores.rank_index(best["rate"])
		draw_text(TITLE_FONT, cells[0], Scores.RANKS[best_rank], 16, DJ_LEVEL_COLOR)
		draw_change(y, signi(rank_index - best_rank))
	else:
		draw_text(TITLE_FONT, cells[0], "-", 16, TEXT_DIM)
	draw_text(TITLE_FONT, cells[1], Scores.RANKS[rank_index], 16, DJ_LEVEL_COLOR)
	row += 1

	y += ROW_STEP
	begin_row(row)
	cells = score_row(y, "EX SCORE")
	if played:
		draw_number(cells[0], best["ex_score"])
		draw_change(y, signi(ex_score - best["ex_score"]))
		draw_diff(y, ex_score - best["ex_score"])
	else:
		draw_text(NUMBER_FONT, cells[0], "----", 18, NUMBER_DIM)
	draw_number(cells[1], counted(ex_score))
	row += 1

	y += ROW_STEP
	begin_row(row)
	cells = score_row(y, "MISS COUNT")
	if best.has("miss_count"):
		draw_number(cells[0], best["miss_count"])
		# Fewer misses is better
		draw_change(y, signi(best["miss_count"] - miss_count))
		draw_diff(y, miss_count - best["miss_count"])
	else:
		draw_text(NUMBER_FONT, cells[0], "----", 18, NUMBER_DIM)
	draw_number(cells[1], counted(miss_count))
	row += 1

	# TARGET: pacemaker of the next DJ LEVEL
	y += ROW_STEP
	begin_row(row)
	var target_rect = Rect2(panel_x, y, PANEL_W, ROW_H - 4)
	draw_row_box(target_rect)
	draw_text(TITLE_FONT, target_rect.grow_side(SIDE_LEFT, -10), "TARGET", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	draw_text(TITLE_FONT, Rect2(panel_x + 118, y, PANEL_W - 126, ROW_H - 4), " ".join(options), 11, TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	row += 1
	y += ROW_H
	begin_row(row)
	var pacemaker = Rect2(panel_x, y, PANEL_W, ROW_H)
	draw_row_box(pacemaker, CURRENT_BORDER)
	draw_text(TITLE_FONT, Rect2(panel_x + 10, y, LABEL_W + VALUE_W, ROW_H), target_name, 14, UP, HORIZONTAL_ALIGNMENT_LEFT)
	draw_number(Rect2(panel_x + LABEL_W + VALUE_W + SEPARATOR_W, y, VALUE_W, ROW_H), target_ex)
	draw_diff(y, ex_score - target_ex)
	row += 1

	# Judgements, combo and FAST/SLOW
	var judge_w = LABEL_W + VALUE_W
	var counts : Dictionary = details.get("counts", {})
	y = JUDGE_TOP
	for judgement in JUDGEMENTS:
		begin_row(row)
		var label_color : Color = judgement[2]
		if judgement[1] == "PGreat":
			# The P-GREAT flashes in rainbow colors like the judgement in game
			label_color = Color.from_hsv(fmod(Time.get_ticks_msec() / 1500.0, 1.0), 0.35, 1.0)
		judge_row(Rect2(panel_x, y, judge_w, JUDGE_H), judgement[0], label_color, counted(counts.get(judgement[1], 0)))
		y += JUDGE_STEP
		row += 1
	y += GROUP_GAP
	begin_row(row)
	judge_row(Rect2(panel_x, y, judge_w, JUDGE_H), "COMBO BREAK", Color.WHITE, counted(details.get("combo_break", 0)))
	y += JUDGE_STEP
	row += 1
	begin_row(row)
	judge_row(Rect2(panel_x, y, judge_w, JUDGE_H), "MAX COMBO", Color.WHITE, counted(Global.get_player_var(player, "combo_max")))
	y += JUDGE_STEP + GROUP_GAP
	row += 1
	begin_row(row)
	judge_row(Rect2(panel_x, y, judge_w, JUDGE_H), "FAST", FAST_COLOR, counted(details.get("fast", 0)))
	y += JUDGE_STEP
	row += 1
	begin_row(row)
	judge_row(Rect2(panel_x, y, judge_w, JUDGE_H), "SLOW", SLOW_COLOR, counted(details.get("slow", 0)))
	row += 1

	# Score rate beside the judgements, appearing with the P-GREAT row
	begin_row(row - 9)
	var rate_rect = Rect2(panel_x + judge_w + 8, JUDGE_TOP, PANEL_W - judge_w - 8, JUDGE_STEP * 2 + JUDGE_H)
	draw_row_box(rate_rect)
	draw_text(TITLE_FONT, Rect2(rate_rect.position, Vector2(rate_rect.size.x, 24)), "RATE", 12, TEXT_DIM)
	draw_text(NUMBER_FONT, Rect2(rate_rect.position + Vector2(0, 20), Vector2(rate_rect.size.x, 26)), "%.2f" % (rate * count_progress()), 18, NUMBER)
	draw_text(TITLE_FONT, Rect2(rate_rect.position + Vector2(0, 44), Vector2(rate_rect.size.x, 22)), "%", 12, TEXT_DIM)

	# FAST/SLOW balance bar under the rate
	var fast = details.get("fast", 0)
	var slow = details.get("slow", 0)
	var bar = Rect2(rate_rect.position.x, JUDGE_TOP + JUDGE_STEP * 7 + GROUP_GAP * 2, rate_rect.size.x, JUDGE_STEP + JUDGE_H)
	begin_row(row - 2)
	draw_row_box(bar)
	var inner = bar.grow(-5)
	if fast + slow > 0:
		var fast_w = inner.size.x * fast / float(fast + slow)
		draw_rect(Rect2(inner.position, Vector2(fast_w, inner.size.y)), fade(Color(FAST_COLOR, 0.8)))
		draw_rect(Rect2(inner.position + Vector2(fast_w, 0), Vector2(inner.size.x - fast_w, inner.size.y)), fade(Color(SLOW_COLOR, 0.8)))
	else:
		draw_rect(inner, fade(BOX_LIGHT))
	draw_set_transform(Vector2.ZERO)

# Fade and slide of the n-th row while it appears
func begin_row(n: int) -> void:
	var t = clampf((elapsed - ROW_DELAY - n * ROW_INTERVAL) / ROW_FADE, 0.0, 1.0)
	var slide = (1.0 - t) * 24.0 * (-1.0 if player == 1 else 1.0)
	draw_set_transform(Vector2(slide, 0))
	row_alpha = t

# Colors of the row being drawn, faded while it appears
func fade(c: Color) -> Color:
	return Color(c, c.a * row_alpha)

# Gauge graph, DJ LEVEL and chart badges
func draw_graph_box() -> void:
	var box = Rect2(GRAPH_BOX.position + Vector2(panel_x, 0), GRAPH_BOX.size)
	draw_rect(box, Color(0.04, 0.05, 0.06))
	draw_rect(box, BOX_BORDER, false, 2.0)
	var graph = Rect2(GRAPH.position + Vector2(panel_x, 0), GRAPH.size)
	draw_rect(graph, GRAPH_BG)
	var hard = Global.get_player_var(player, "gauge_level") == Judge.HARD
	# The clear zone above 80 %, except on HARD which clears as long as it lasts
	if not hard:
		draw_rect(Rect2(graph.position, Vector2(graph.size.x, graph.size.y * 0.2)), CLEAR_BAND)
	for i in range(1, 10):
		var gy = graph.position.y + graph.size.y * i / 10.0
		draw_line(Vector2(graph.position.x, gy), Vector2(graph.end.x, gy), GRAPH_GRID)
	for i in range(1, 8):
		var gx = graph.position.x + graph.size.x * i / 8.0
		draw_line(Vector2(gx, graph.position.y), Vector2(gx, graph.end.y), GRAPH_GRID)
	if not hard:
		var clear_y = graph.position.y + graph.size.y * 0.2
		draw_line(Vector2(graph.position.x, clear_y), Vector2(graph.end.x, clear_y), Color(LINE_RED, 0.6))

	# Gauge line, drawn from left to right during the reveal
	var history : PackedVector2Array = details.get("gauge_history", PackedVector2Array())
	var shown = clampf(elapsed / GRAPH_TIME, 0.0, 1.0)
	var to_point = func(p: Vector2) -> Vector2:
		return Vector2(graph.position.x + p.x * graph.size.x, graph.end.y - p.y / 100.0 * graph.size.y)
	for i in range(1, history.size()):
		var from = history[i - 1]
		var to = history[i]
		if from.x > shown:
			break
		if to.x > shown:
			to = from.lerp(to, (shown - from.x) / maxf(to.x - from.x, 0.0001))
		# Steps of the gauge: flat until the next judgement, then the change
		var corner = Vector2(to.x, from.y)
		var color = LINE_RED if hard or from.y >= 80 else LINE_GREEN
		draw_line(to_point.call(from), to_point.call(corner), color, 2.0)
		draw_line(to_point.call(corner), to_point.call(to), LINE_RED if hard or to.y >= 80 else LINE_GREEN, 2.0)

	# DJ LEVEL, popping out once the graph is drawn
	var pop = clampf((elapsed - GRAPH_TIME) / DJ_LEVEL_POP, 0.0, 1.0)
	if pop > 0.0:
		var level = Scores.RANKS[rank_index]
		var font_size = 76
		var text_size = TITLE_FONT.get_string_size(level, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var center = Vector2(graph.position.x + 18 + text_size.x / 2, graph.get_center().y)
		var scale = lerpf(1.8, 1.0, ease(pop, 0.4))
		draw_set_transform(center, 0.0, Vector2(scale, scale))
		var origin = Vector2(-text_size.x / 2, (TITLE_FONT.get_ascent(font_size) - TITLE_FONT.get_descent(font_size)) / 2)
		draw_string_outline(TITLE_FONT, origin, level, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 10, Color(0.02, 0.15, 0.2, pop))
		draw_string(TITLE_FONT, origin, level, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(DJ_LEVEL_COLOR, pop))
		draw_set_transform(Vector2.ZERO)

	# SP or DP, difficulty, level and number of notes
	var info : Dictionary = Global.song_info
	var difficulty = info.get("difficulty", "")
	var difficulty_color = NetplayUI.DIFFICULTY_COLORS.get(difficulty, Color.WHITE)
	var x = panel_x + 8
	draw_badge(Rect2(x, STRIP_TOP, 34, STRIP_H), "DP" if info.get("double", false) else "SP", Color.WHITE)
	draw_badge(Rect2(x + 40, STRIP_TOP, 104, STRIP_H), difficulty.to_upper() if difficulty != "" else "-", difficulty_color, true)
	draw_badge(Rect2(x + 150, STRIP_TOP, 30, STRIP_H), str(info.get("level", "")), difficulty_color)
	draw_badge(Rect2(panel_x + PANEL_W - 8 - 120, STRIP_TOP, 120, STRIP_H), "%04d NOTES" % details.get("note_count", 0), Color(0.4, 1, 0.4))

func draw_badge(rect: Rect2, text: String, color: Color, filled := false) -> void:
	draw_rect(rect, Color(color, 0.25) if filled else Color.BLACK)
	draw_rect(rect, color, false, 2.0)
	draw_text(TITLE_FONT, rect, text, 13, color)

# Row with its name, the best value and the current one, returns the two value cells
func score_row(y: float, title: String) -> Array:
	var rect = Rect2(panel_x, y, PANEL_W, ROW_H)
	draw_row_box(rect)
	draw_text(TITLE_FONT, Rect2(panel_x + 10, y, LABEL_W - 10, ROW_H), title, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	var best_cell = Rect2(panel_x + LABEL_W, y + 3, VALUE_W, ROW_H - 6)
	var separator_x = best_cell.end.x + SEPARATOR_W / 2
	draw_line(Vector2(separator_x, y + 4), Vector2(separator_x, y + ROW_H - 4), fade(TEXT_DIM), 2.0)
	var now_cell = Rect2(best_cell.end.x + SEPARATOR_W, y + 3, VALUE_W - 4, ROW_H - 6)
	draw_rect(now_cell, fade(Color(0.12, 0.1, 0.06)))
	draw_rect(now_cell, fade(CURRENT_BORDER), false, 1.5)
	return [best_cell, now_cell]

func draw_row_box(rect: Rect2, border := BOX_BORDER) -> void:
	draw_rect(rect, fade(BOX))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.45)), fade(BOX_LIGHT))
	draw_rect(rect, fade(border), false, 1.0)

func judge_row(rect: Rect2, title: String, title_color: Color, value: int) -> void:
	draw_row_box(rect)
	draw_text(TITLE_FONT, Rect2(rect.position.x + 10, rect.position.y, LABEL_W - 10, rect.size.y), title, 14, title_color, HORIZONTAL_ALIGNMENT_LEFT)
	draw_number(Rect2(rect.position.x + LABEL_W, rect.position.y, VALUE_W, rect.size.y), value)

# Small white tag above a column
func draw_tag(rect: Rect2, text: String) -> void:
	draw_rect(rect, fade(Color(0.85, 0.85, 0.88)))
	draw_text(TITLE_FONT, rect, text, 11, Color(0.05, 0.05, 0.08))

# UP! or DOWN arrow beside the current value of a row
func draw_change(y: float, change: int) -> void:
	if change == 0:
		return
	var color = UP if change > 0 else DOWN
	var cx = arrow_x + ARROW_W / 2
	# Head of 9 px and shaft of 6 px, pointing up or down
	var top = y + 2
	var tip = top if change > 0 else top + 15
	var base = top + 9 if change > 0 else top + 6
	draw_colored_polygon(PackedVector2Array([Vector2(cx, tip), Vector2(cx - 9, base), Vector2(cx + 9, base)]), fade(color))
	draw_rect(Rect2(cx - 3, top + 9 if change > 0 else top, 6, 6), fade(color))
	draw_text(TITLE_FONT, Rect2(arrow_x - 6, y + 16, ARROW_W + 12, 12), "UP!" if change > 0 else "DOWN", 9, color)

# Signed difference with the best or the target: "+0136", "-0006"
func draw_diff(y: float, diff: int) -> void:
	var rect = Rect2(diff_x, y, DIFF_W, ROW_H)
	draw_row_box(rect)
	var color = Color.WHITE if diff >= 0 else MINUS
	draw_text(NUMBER_FONT, rect, "%s%04d" % ["+" if diff >= 0 else "-", absi(diff)], 18, color)

# Four digits, the leading zeros dimmed like on the IIDX segment displays
func draw_number(rect: Rect2, value: int, digits := 4) -> void:
	var text = str(value).pad_zeros(digits)
	var zeros = 0
	while zeros < text.length() - 1 and text[zeros] == "0":
		zeros += 1
	var font_size = 18
	var width = NUMBER_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline = rect.position.y + (rect.size.y + NUMBER_FONT.get_ascent(font_size) - NUMBER_FONT.get_descent(font_size)) / 2
	var x = rect.get_center().x - width / 2
	var dim = text.substr(0, zeros)
	draw_string(NUMBER_FONT, Vector2(x, baseline), dim, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fade(NUMBER_DIM))
	x += NUMBER_FONT.get_string_size(dim, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(NUMBER_FONT, Vector2(x, baseline), text.substr(zeros), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fade(NUMBER))

# Text fitted in a box, centered, left or right aligned
func draw_text(font: Font, rect: Rect2, text: String, font_size: int, text_color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x - 6:
		font_size -= 1
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline = rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2
	var x = rect.get_center().x - width / 2
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		x = rect.position.x
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = rect.end.x - width
	draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fade(text_color))
