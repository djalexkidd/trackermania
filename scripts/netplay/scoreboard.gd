extends Control

# Live ranking of the netplay round, beside the playfield: EX score of each DJ with a bar towards the maximum

const ROW_HEIGHT = 54.0
const BAR_HEIGHT = 6.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Netplay.live_changed.connect(queue_redraw)
	Netplay.results_changed.connect(queue_redraw)
	Netplay.players_changed.connect(queue_redraw)
	Netplay.closed.connect(func(_reason): queue_redraw())

# Players of the round, the best EX score first
func ranking() -> Array:
	var ids = Netplay.room.get("round", []).duplicate()
	ids.sort_custom(func(a, b): return ex_of(a) > ex_of(b))
	return ids

func ex_of(id: int) -> int:
	return Netplay.live.get(id, {}).get("ex", 0)

func _draw() -> void:
	var title_font = NetplayUI.TITLE_FONT
	var font = NetplayUI.TEXT_FONT
	draw_string(title_font, Vector2(0, 20), "DJ RANKING", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, NetplayUI.ACCENT)
	var y = 36.0
	var rank = 0
	var last_ex = -1
	var ids = ranking()
	for i in ids.size():
		var id = ids[i]
		var data = Netplay.live.get(id, {})
		var ex = data.get("ex", 0)
		if ex != last_ex:
			rank = i + 1
			last_ex = ex
		var color = Netplay.color_of(id)
		var mine = id == Netplay.my_id()
		var rect = Rect2(0, y, size.x, ROW_HEIGHT - 6)
		draw_rect(rect, Color(color.darkened(0.75), 0.85) if mine else Color(NetplayUI.PANEL, 0.75))
		draw_rect(Rect2(0, y, 6, rect.size.y), color)
		draw_string(title_font, Vector2(12, y + 30), str(rank), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		var player_name = Netplay.players.get(id, Netplay.results.get(id, {})).get("name", "?")
		draw_string(title_font, Vector2(56, y + 22), player_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 160, 18, color.lightened(0.3))
		draw_string(font, Vector2(56, y + 40), state_text(id, data), HORIZONTAL_ALIGNMENT_LEFT, size.x - 160, 16, NetplayUI.DIM)
		draw_string(title_font, Vector2(0, y + 30), "%d" % ex, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 10, 24, Color.WHITE)
		# Bar towards the maximum EX score
		var max_ex = maxi(data.get("max_ex", 0), 1)
		draw_rect(Rect2(56, y + rect.size.y - BAR_HEIGHT - 2, size.x - 66, BAR_HEIGHT), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(56, y + rect.size.y - BAR_HEIGHT - 2, (size.x - 66) * clampf(float(ex) / max_ex, 0, 1), BAR_HEIGHT), color)
		y += ROW_HEIGHT
	if not Netplay.active:
		draw_string(title_font, Vector2(0, y + 24), "CONNECTION LOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, NetplayUI.ERROR)

func state_text(id: int, data: Dictionary) -> String:
	if Netplay.results.has(id):
		return "FAILED" if Netplay.results[id].get("failed", false) else "FINISHED"
	if Netplay.active and not Netplay.players.has(id):
		return "LEFT"
	if data.is_empty():
		return "LOADING"
	return "GAUGE %d%%  COMBO %d" % [data.get("gauge", 0), data.get("combo", 0)]
