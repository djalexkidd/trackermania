extends Control

# Results of the netplay round: the DJs ranked by EX score, updated while the others are still playing

# [title, width] of each column, 0 fills the space left
const COLUMNS = [["", 64], ["DJ", 0], ["CLEAR", 190], ["GRADE", 90], ["EX SCORE", 150], ["PG/GR/GD/BD/PR", 270], ["COMBO", 100]]

var rows: VBoxContainer
var waiting_label: Label
var back_button: Button
var blink := 0.0
# The keys still held at the end of the song do not leave the screen at once
const INPUT_DELAY = 1.5

func _ready() -> void:
	var song = Netplay.room.get("song", {})
	$SongLabel.text = song.get("title", "")
	# BMS titles often end with the difficulty already
	if not $SongLabel.text.to_upper().contains(song.get("difficulty", "").to_upper()):
		$SongLabel.text += "  [%s]" % song.get("difficulty", "").to_upper()
	$SongLabel.add_theme_color_override("font_color", NetplayUI.difficulty_color(song.get("difficulty", "")))
	var content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 32
	content.offset_right = -32
	content.offset_top = 132
	content.offset_bottom = -100
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	content.add_child(row_box(COLUMNS.map(func(column): return NetplayUI.label(column[0], NetplayUI.TITLE_FONT, 14, NetplayUI.DIM)), false))
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	content.add_child(rows)
	waiting_label = NetplayUI.label("", NetplayUI.TITLE_FONT, 20, NetplayUI.WARNING)
	waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(waiting_label)

	var buttons = HBoxContainer.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.offset_left = 32
	buttons.offset_right = -32
	buttons.offset_top = -66
	buttons.offset_bottom = -22
	add_child(buttons)
	back_button = NetplayUI.button("BACK TO THE LOBBY", NetplayUI.ACCENT, 320)
	back_button.pressed.connect(back)
	buttons.add_child(back_button)
	var hint = NetplayUI.label("WHITE KEYS / START: BACK TO THE LOBBY", NetplayUI.TEXT_FONT, 20, NetplayUI.DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_child(hint)
	back_button.grab_focus()

	Netplay.results_changed.connect(refresh)
	Netplay.live_changed.connect(refresh)
	Netplay.players_changed.connect(refresh)
	Netplay.closed.connect(func(_reason): refresh())
	refresh()

# One line of the table, cells sized like COLUMNS
func row_box(cells: Array, framed := true, color := NetplayUI.ACCENT, mine := false) -> Control:
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	for i in cells.size():
		var cell: Control = cells[i]
		cell.custom_minimum_size.x = COLUMNS[i][1]
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if COLUMNS[i][1] == 0 else Control.SIZE_FILL
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if cell is Label and i != 1:
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cell)
	if not framed:
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 22)
		margin.add_theme_constant_override("margin_right", 22)
		margin.add_child(box)
		return margin
	var card = PanelContainer.new()
	card.custom_minimum_size.y = 52
	card.add_theme_stylebox_override("panel", NetplayUI.panel_style(color if mine else Color(color, 0.55), 0.15,
		Color(color.darkened(0.7), 0.9) if mine else NetplayUI.PANEL, 3 if mine else 2))
	card.add_child(box)
	return card

# Finished DJs by EX score, then the ones still playing
func ranking() -> Array:
	var ids = Netplay.room.get("round", []).duplicate()
	ids.sort_custom(func(a, b):
		if Netplay.results.has(a) != Netplay.results.has(b):
			return Netplay.results.has(a)
		return ex_of(a) > ex_of(b))
	return ids

func ex_of(id: int) -> int:
	if Netplay.results.has(id):
		return Netplay.results[id]["ex"]
	return Netplay.live.get(id, {}).get("ex", 0)

func refresh() -> void:
	for child in rows.get_children():
		child.queue_free()
	var rank = 0
	var last_ex = -1
	var ids = ranking()
	var waiting = 0
	for i in ids.size():
		var id = ids[i]
		var color = Netplay.color_of(id)
		var result = Netplay.results.get(id, {})
		var gone = Netplay.active and not Netplay.players.has(id) and result.is_empty()
		var player_name = result.get("name", Netplay.players.get(id, {}).get("name", "?"))
		var cells = []
		if result.is_empty():
			waiting += 0 if gone else 1
			cells = [
				NetplayUI.label("-", NetplayUI.TITLE_FONT, 28, NetplayUI.DIM),
				NetplayUI.label(player_name, NetplayUI.TITLE_FONT, 26, color.lightened(0.3)),
				NetplayUI.label("LEFT" if gone else "PLAYING", NetplayUI.TITLE_FONT, 18, NetplayUI.ERROR if gone else NetplayUI.WARNING),
				NetplayUI.label("", NetplayUI.TITLE_FONT, 24),
				NetplayUI.label(str(ex_of(id)), NetplayUI.TITLE_FONT, 26, NetplayUI.DIM),
				NetplayUI.label("", NetplayUI.TEXT_FONT, 22),
				NetplayUI.label("", NetplayUI.TEXT_FONT, 22),
			]
		else:
			if result["ex"] != last_ex:
				rank = i + 1
				last_ex = result["ex"]
			var counts = result.get("counts", {})
			var rank_color = [Color(1, 0.85, 0), Color(0.85, 0.85, 0.9), Color(0.85, 0.55, 0.3)][rank - 1] if rank <= 3 else Color.WHITE
			var lamp = clampi(result.get("lamp", 0), 0, Scores.LAMPS.size() - 1)
			cells = [
				NetplayUI.label(ordinal(rank), NetplayUI.TITLE_FONT, 28, rank_color),
				NetplayUI.label(player_name, NetplayUI.TITLE_FONT, 26, color.lightened(0.3)),
				NetplayUI.label("AUTO PLAY", NetplayUI.TITLE_FONT, 18, NetplayUI.DIM) if result.get("auto_play", false) \
					else NetplayUI.label(Scores.LAMPS[lamp], NetplayUI.TITLE_FONT, 18, Scores.LAMP_COLORS[lamp]),
				NetplayUI.label(Scores.rank(result.get("rate", 0.0)), NetplayUI.TITLE_FONT, 28),
				NetplayUI.label("%d" % result["ex"], NetplayUI.TITLE_FONT, 26),
				NetplayUI.label("%d/%d/%d/%d/%d" % [counts.get("PGreat", 0), counts.get("Great", 0), counts.get("Good", 0), counts.get("Bad", 0), counts.get("Poor", 0)], NetplayUI.TEXT_FONT, 24),
				NetplayUI.label(str(result.get("combo_max", 0)), NetplayUI.TEXT_FONT, 24),
			]
		cells[1].clip_text = true
		rows.add_child(row_box(cells, true, color, id == Netplay.my_id()))
	if not Netplay.active and Netplay.last_reason != "":
		waiting_label.text = "CONNECTION LOST: " + Netplay.last_reason.to_upper()
		waiting_label.add_theme_color_override("font_color", NetplayUI.ERROR)
	elif waiting > 0 and Netplay.active:
		waiting_label.text = "WAITING FOR %d DJ%s" % [waiting, "S" if waiting > 1 else ""]
	else:
		waiting_label.text = ""

static func ordinal(rank: int) -> String:
	return str(rank) + ("ST" if rank == 1 else "ND" if rank == 2 else "RD" if rank == 3 else "TH")

func _process(delta: float) -> void:
	blink += delta
	waiting_label.modulate.a = 0.55 + 0.45 * cos(blink * 4.0)
	if blink < INPUT_DELAY:
		return
	for key in ["start", "key1", "key3", "key5", "key7"]:
		if Input.is_action_just_pressed("p1_" + key):
			back()
			return

func back() -> void:
	get_tree().change_scene_to_file("res://scenes/netplay/lobby.tscn")
