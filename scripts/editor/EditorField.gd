extends Control
class_name EditorField

# The lanes of the BMS editor, like in the Quaver editor: the chart goes down to the hit line, the notes are placed
# with the mouse on the beat snap. On the left the timeline of the whole song and the BPM column, on the right
# the background sounds (BGM). Drawn in _draw(), the changes go through editor.gd (undo, keysounds).

const NOTE = preload("res://scenes/game/note.gd")
const NOTE_HEIGHT : float = 12.0
# Hit line, from the bottom
const HIT_LINE_BOTTOM : float = 140.0
const KEYS_HEIGHT : float = 26.0
const MINIMAP_WIDTH : float = 22.0
const TIMING_WIDTH : float = 74.0
const BGM_COLUMNS : int = 4
const BGM_WIDTH : float = 30.0
const GAP : float = 12.0
const SIDE_GAP : float = 10.0
# Lane widths, in single play and in double play
const KEY_WIDTH : Array = [44.0, 30.0]
const SCRATCH_WIDTH : Array = [66.0, 44.0]
# Snap lines closer than this are not drawn
const MIN_LINE_SPACING : float = 5.0
const WAVE_COLOR : Color = Color(0.3, 0.6, 1.0, 0.35)
const LANE_COLOR : Color = Color(0, 0, 0, 0.82)
const BLACK_KEY_LANE : Color = Color(0.03, 0.04, 0.08, 0.86)
const SCRATCH_LANE : Color = Color(0.07, 0.02, 0.02, 0.86)
const BGM_LANE : Color = Color(0.05, 0.05, 0.06, 0.82)
const SEPARATOR : Color = Color(1, 1, 1, 0.1)
const MEASURE_LINE : Color = Color(1, 1, 1, 0.75)
# Snap lines by division of the beat, like Quaver
const DIVISION_COLORS : Dictionary = {
	1: Color(1, 1, 1, 0.45), 2: Color(1, 0.25, 0.25, 0.55), 3: Color(0.75, 0.3, 1, 0.55), 4: Color(0.3, 0.6, 1, 0.55),
	6: Color(1, 0.4, 0.8, 0.5), 8: Color(1, 0.85, 0.2, 0.45), 12: Color(0.6, 0.4, 1, 0.4), 16: Color(0.6, 0.6, 0.6, 0.35),
}
const OTHER_DIVISION : Color = Color(0.5, 0.5, 0.5, 0.3)
const SLICE_COLOR : Color = Color(0.25, 0.8, 0.8)
const BGM_COLOR : Color = Color(0.7, 0.7, 0.75)
const SELECTED_COLOR : Color = Color(1, 0.82, 0.1)

enum Drag {NONE, SELECT_BOX, MOVE, LONG, SEEK}

var editor
# Lanes from left to right, and the place of each lane
var order : Array = []
var laneLeft : PackedFloat32Array = []
var laneWidth : PackedFloat32Array = []
var lanesRect : Rect2
var timingLeft : float = 0.0
var bgmLeft : float = 0.0
var minimapRect : Rect2
# Background sounds drawn: [rect, event]
var bgmRects : Array = []
var selection : Array = []
var hoverNote = null
var hoverBgm = null
var hoverLane : int = -1
var mousePosition : Vector2 = Vector2(-1, -1)
var drag : int = Drag.NONE
var dragFrom : Vector2
var dragBeat : float = 0.0
var dragColumn : int = 0
var dragLane : int = 0
# Move of the selected notes: [columns, beats]
var dragDelta : Array = [0, 0.0]
var zoomButtons : VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true
	laneLeft.resize(EditorChart.DOUBLE_LANES)
	laneWidth.resize(EditorChart.DOUBLE_LANES)
	# Zoom buttons next to the lanes, like Quaver
	zoomButtons = VBoxContainer.new()
	for zoom in [["plus", 1, "ZOOM IN (+)"], ["minus", -1, "ZOOM OUT (-)"]]:
		var button : Button = EditorUI.button("")
		button.icon = EditorUI.icon(zoom[0])
		button.tooltip_text = zoom[2]
		button.pressed.connect(func(): editor.change_zoom(zoom[1]))
		zoomButtons.add_child(button)
	add_child(zoomButtons)
	mouse_exited.connect(func():
		mousePosition = Vector2(-1, -1)
		hoverNote = null
		hoverBgm = null
		hoverLane = -1)

func _process(_delta) -> void:
	queue_redraw()

# Layout

func layout() -> void:
	var double : bool = editor.chart != null and editor.chart.double
	order = [7, 0, 1, 2, 3, 4, 5, 6]
	if double:
		order += [8, 9, 10, 11, 12, 13, 14, 15]
	var style : int = 1 if double else 0
	var lanesWidth : float = (KEY_WIDTH[style] * 7 + SCRATCH_WIDTH[style]) * (2 if double else 1) + (SIDE_GAP if double else 0.0)
	var total : float = MINIMAP_WIDTH + 14 + TIMING_WIDTH + lanesWidth + GAP + BGM_COLUMNS * BGM_WIDTH
	var x : float = maxf((size.x - total) / 2, 0.0)
	minimapRect = Rect2(x, 8, MINIMAP_WIDTH, size.y - 16)
	x += MINIMAP_WIDTH + 14
	timingLeft = x
	x += TIMING_WIDTH
	var lanesLeft : float = x
	for i in order.size():
		var lane : int = order[i]
		if i == EditorChart.SIDE_LANES:
			x += SIDE_GAP
		laneLeft[lane] = x
		laneWidth[lane] = SCRATCH_WIDTH[style] if lane % EditorChart.SIDE_LANES == EditorChart.SCRATCH_LANE else KEY_WIDTH[style]
		x += laneWidth[lane]
	lanesRect = Rect2(lanesLeft, 0, x - lanesLeft, size.y)
	bgmLeft = x + GAP
	zoomButtons.position = Vector2(bgmLeft + BGM_COLUMNS * BGM_WIDTH + 8, 8)

func hitY() -> float:
	return size.y - HIT_LINE_BOTTOM

func bottom() -> float:
	return size.y - KEYS_HEIGHT

func yOf(beat : float) -> float:
	return hitY() - (beat - editor.cursor_beat) * editor.zoom

func beatAt(y : float) -> float:
	return editor.cursor_beat + (hitY() - y) / editor.zoom

func laneAt(x : float) -> int:
	for lane in order:
		if x >= laneLeft[lane] and x < laneLeft[lane] + laneWidth[lane]:
			return lane
	return -1

# Column of the nearest lane, for the notes moved out of the lanes
func columnAt(x : float) -> int:
	var best : int = 0
	for i in order.size():
		var lane : int = order[i]
		if absf(x - laneLeft[lane] - laneWidth[lane] / 2) < absf(x - laneLeft[order[best]] - laneWidth[order[best]] / 2):
			best = i
	return best

func bgmColumnAt(x : float) -> int:
	if x < bgmLeft or x >= bgmLeft + BGM_COLUMNS * BGM_WIDTH:
		return -1
	return int((x - bgmLeft) / BGM_WIDTH)

func noteRect(lane : int, beat : float, length : float) -> Rect2:
	var top : float = yOf(beat + length) - NOTE_HEIGHT / 2
	return Rect2(laneLeft[lane] + 2, top, laneWidth[lane] - 4, yOf(beat) + NOTE_HEIGHT / 2 - top)

func noteAtPosition(at : Vector2):
	var lane : int = laneAt(at.x)
	if lane == -1:
		return null
	for n in editor.chart.notes:
		if n.lane == lane and noteRect(n.lane, n.beat, n.length).grow(1).has_point(at):
			return n
	return null

func bgmAtPosition(at : Vector2):
	for drawn in bgmRects:
		if drawn[0].grow(1).has_point(at):
			return drawn[1]
	return null

static func noteColor(lane : int) -> Color:
	var key : int = lane % EditorChart.SIDE_LANES
	if key == EditorChart.SCRATCH_LANE:
		return NOTE.SCRATCH_NOTE
	return NOTE.BLUE_NOTE if key in [1, 3, 5] else NOTE.WHITE_NOTE

# Input

func _gui_input(event : InputEvent) -> void:
	if editor.chart == null or editor.busy:
		return
	if event is InputEventMouseMotion:
		mousePosition = event.position
		updateHover()
		dragMotion(event.position)
	elif event is InputEventMouseButton:
		mousePosition = event.position
		if event.pressed:
			get_viewport().gui_release_focus()
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					editor.wheel(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1, event.ctrl_pressed, event.shift_pressed, event.alt_pressed)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					leftPress(event)
				else:
					leftRelease(event.position)
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					rightPress()
		accept_event()

func updateHover() -> void:
	hoverNote = noteAtPosition(mousePosition)
	hoverBgm = bgmAtPosition(mousePosition)
	hoverLane = laneAt(mousePosition.x)

func leftPress(event : InputEventMouseButton) -> void:
	var at : Vector2 = event.position
	updateHover()
	if minimapRect.grow_individual(4, 0, 4, 0).has_point(at):
		drag = Drag.SEEK
		dragMotion(at)
		return
	if at.x >= timingLeft and at.x < lanesRect.position.x:
		editor.open_timing_dialog(editor.snap_beat(beatAt(at.y)))
		return
	var beat : float = editor.snap_beat(beatAt(at.y))
	if hoverLane != -1:
		match editor.tool:
			BmsEditor.Tool.SELECT:
				if hoverNote != null:
					if event.ctrl_pressed and selection.has(hoverNote):
						selection.erase(hoverNote)
						return
					if event.ctrl_pressed:
						selection.append(hoverNote)
					elif not selection.has(hoverNote):
						selection = [hoverNote]
					editor.preview_note(hoverNote)
					drag = Drag.MOVE
					dragBeat = beat
					dragColumn = order.find(hoverLane)
					dragDelta = [0, 0.0]
				else:
					if not event.ctrl_pressed:
						selection.clear()
					drag = Drag.SELECT_BOX
					dragFrom = at
			BmsEditor.Tool.NOTE:
				if hoverNote != null:
					editor.delete_notes([hoverNote])
				else:
					editor.place_note(hoverLane, beat, 0.0)
			BmsEditor.Tool.LONG:
				if hoverNote != null:
					editor.delete_notes([hoverNote])
				else:
					drag = Drag.LONG
					dragLane = hoverLane
					dragBeat = beat
			BmsEditor.Tool.BGM:
				editor.toast("THE BGM SOUND TOOL PLACES SOUNDS IN THE BGM COLUMNS, ON THE RIGHT")
		return
	if bgmColumnAt(at.x) != -1:
		if hoverBgm != null:
			editor.preview_bgm(hoverBgm)
		else:
			editor.place_bgm(beat)

func leftRelease(at : Vector2) -> void:
	match drag:
		Drag.MOVE:
			if dragDelta[0] != 0 or absf(dragDelta[1]) > EditorChart.EPSILON:
				editor.move_notes(selection.duplicate(), dragDelta[0], dragDelta[1])
		Drag.SELECT_BOX:
			var box : Rect2 = Rect2(dragFrom, at - dragFrom).abs()
			for n in editor.chart.notes:
				if n.lane < editor.chart.lanes() and box.intersects(noteRect(n.lane, n.beat, n.length)) and not selection.has(n):
					selection.append(n)
		Drag.LONG:
			var length : float = maxf(editor.snap_beat(beatAt(at.y)) - dragBeat, 0.0)
			editor.place_note(dragLane, dragBeat, length if length > EditorChart.EPSILON else 0.0)
	drag = Drag.NONE

func dragMotion(at : Vector2) -> void:
	match drag:
		Drag.MOVE:
			dragDelta = [columnAt(at.x) - dragColumn, editor.snap_beat(beatAt(at.y)) - dragBeat]
		Drag.SEEK:
			var length : float = editor.song_end
			var t : float = (minimapRect.end.y - at.y) / minimapRect.size.y * length
			editor.seek_beat(editor.chart.timeToBeat(clampf(t, 0.0, length)))

func rightPress() -> void:
	updateHover()
	if drag != Drag.NONE:
		drag = Drag.NONE
	elif hoverNote != null:
		editor.delete_notes([hoverNote])
	elif hoverBgm != null:
		editor.delete_bgm(hoverBgm)

# Drawing

func _draw() -> void:
	layout()
	var chart : EditorChart = editor.chart
	if chart == null:
		return
	var lanesBottom : float = bottom()
	var right : float = bgmLeft + BGM_COLUMNS * BGM_WIDTH
	draw_rect(Rect2(timingLeft, 0, TIMING_WIDTH, lanesBottom), Color(0, 0, 0, 0.6))
	for lane in order:
		var key : int = lane % EditorChart.SIDE_LANES
		var color : Color = SCRATCH_LANE if key == EditorChart.SCRATCH_LANE else BLACK_KEY_LANE if key in [1, 3, 5] else LANE_COLOR
		draw_rect(Rect2(laneLeft[lane], 0, laneWidth[lane], lanesBottom), color)
		draw_line(Vector2(laneLeft[lane], 0), Vector2(laneLeft[lane], lanesBottom), SEPARATOR)
	draw_line(Vector2(lanesRect.end.x, 0), Vector2(lanesRect.end.x, lanesBottom), SEPARATOR)
	draw_rect(Rect2(bgmLeft, 0, right - bgmLeft, lanesBottom), BGM_LANE)
	for column in range(1, BGM_COLUMNS):
		draw_line(Vector2(bgmLeft + column * BGM_WIDTH, 0), Vector2(bgmLeft + column * BGM_WIDTH, lanesBottom), Color(SEPARATOR, 0.05))
	if editor.show_waveform:
		drawWaveform(lanesBottom)
	drawGrid(lanesBottom, right)
	drawTiming()
	drawBgm()
	drawNotes(lanesBottom)
	drawPreviews()
	# Hit line
	draw_line(Vector2(timingLeft, hitY()), Vector2(right, hitY()), EditorUI.ORANGE, 3.0)
	draw_line(Vector2(timingLeft, hitY() - 3), Vector2(right, hitY() - 3), Color(EditorUI.YELLOW, 0.4), 1.0)
	drawKeys(lanesBottom, right)
	drawMinimap()
	if drag == Drag.SELECT_BOX:
		var box : Rect2 = Rect2(dragFrom, mousePosition - dragFrom).abs()
		draw_rect(box, Color(EditorUI.ORANGE, 0.12))
		draw_rect(box, EditorUI.ORANGE, false, 1.0)
	drawTooltip()

# Peaks of the sounds as they are placed, behind the lanes
func drawWaveform(lanesBottom : float) -> void:
	var wave : PackedFloat32Array = editor.waveform
	if wave.is_empty():
		return
	var chart : EditorChart = editor.chart
	var center : float = lanesRect.get_center().x
	var half : float = lanesRect.size.x / 2 - 4
	var points : PackedVector2Array = []
	var bins : int = wave.size()
	for y in range(0, int(lanesBottom), 2):
		var from : int = int(chart.beatToTime(beatAt(y + 2)) * AudioSlicer.ENVELOPE_RATE)
		var to : int = int(chart.beatToTime(beatAt(y)) * AudioSlicer.ENVELOPE_RATE)
		if to < 0 or from >= bins:
			continue
		var peak : float = 0.0
		for bin in range(maxi(from, 0), mini(maxi(to, from + 1), bins)):
			peak = maxf(peak, wave[bin])
		if peak > 0.005:
			points.append(Vector2(center - peak * half, y + 1))
			points.append(Vector2(center + peak * half, y + 1))
	if not points.is_empty():
		draw_multiline(points, WAVE_COLOR, 2.0)

# Measure lines and the lines of the beat snap, from the start of each measure
func drawGrid(lanesBottom : float, right : float) -> void:
	var chart : EditorChart = editor.chart
	var snap : int = editor.snap()
	var step : float = 1.0 / snap
	var last : float = beatAt(0)
	var m : int = chart.measureAt(maxf(beatAt(lanesBottom), 0.0))
	while chart.measureBeat(m) <= last:
		var start : float = chart.measureBeat(m)
		var end : float = chart.measureBeat(m + 1)
		var k : int = 1
		while start + k * step < end - EditorChart.EPSILON:
			var y : float = yOf(start + k * step)
			var division : int = snap / gcd(k % snap, snap) if k % snap != 0 else 1
			if division == 1 or step * editor.zoom >= MIN_LINE_SPACING:
				if y >= 0 and y <= lanesBottom:
					draw_line(Vector2(lanesRect.position.x, y), Vector2(right, y), DIVISION_COLORS.get(division, OTHER_DIVISION), 2.0 if division == 1 else 1.0)
			k += 1
		var y : float = yOf(start)
		if y >= -20 and y <= lanesBottom + 20:
			draw_line(Vector2(timingLeft, y), Vector2(right, y), MEASURE_LINE, 2.0)
			draw_string(EditorUI.TEXT_FONT, Vector2(timingLeft + 4, y - 4), "#%03d" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
		m += 1

static func gcd(a : int, b : int) -> int:
	while b != 0:
		var t : int = b
		b = a % b
		a = t
	return a

# Tempo changes and stops in the BPM column
func drawTiming() -> void:
	var chart : EditorChart = editor.chart
	var marks : Array = [[0.0, EditorChart.number(snappedf(chart.bpm, 0.01)), EditorUI.YELLOW]]
	for change in chart.bpmChanges:
		marks.append([change.beat, EditorChart.number(snappedf(change.bpm, 0.01)), EditorUI.YELLOW])
	for stop in chart.stops:
		marks.append([stop.beat, "STOP", EditorUI.RED])
	for mark in marks:
		var y : float = yOf(mark[0])
		if y < -10 or y > size.y + 10:
			continue
		var width : float = EditorUI.TEXT_FONT.get_string_size(mark[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var tag : Rect2 = Rect2(lanesRect.position.x - width - 12, y - 9, width + 10, 18)
		draw_rect(tag, mark[2])
		draw_string(EditorUI.TEXT_FONT, Vector2(tag.position.x + 5, y + 6), mark[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
		draw_line(Vector2(lanesRect.position.x, y), Vector2(lanesRect.end.x, y), Color(mark[2], 0.6), 1.0)

# Background sounds side by side when they are at the same beat
func drawBgm() -> void:
	var chart : EditorChart = editor.chart
	bgmRects.clear()
	var low : float = beatAt(size.y) - EditorChart.EPSILON
	var high : float = beatAt(0) + EditorChart.EPSILON
	var visible : Array = chart.bgm.filter(func(e): return e.beat >= low and e.beat <= high)
	visible.sort_custom(func(a, b): return a.beat < b.beat)
	var column : int = 0
	for i in visible.size():
		var e : Dictionary = visible[i]
		column = column + 1 if i > 0 and absf(e.beat - visible[i - 1].beat) < EditorChart.EPSILON else 0
		var y : float = yOf(e.beat)
		if column >= BGM_COLUMNS:
			if column == BGM_COLUMNS:
				draw_string(EditorUI.TEXT_FONT, Vector2(bgmLeft + BGM_COLUMNS * BGM_WIDTH + 2, y + 5), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, EditorUI.DIM)
			continue
		var rect : Rect2 = Rect2(bgmLeft + column * BGM_WIDTH + 2, y - 5, BGM_WIDTH - 4, 10)
		var color : Color = SLICE_COLOR if chart.isSlice(e.sound) else BGM_COLOR
		draw_rect(rect, Color(color, 0.85))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color(1, 1, 1, 0.5))
		if e == hoverBgm:
			draw_rect(rect.grow(1), SELECTED_COLOR, false, 2.0)
		bgmRects.append([rect, e])

func drawNotes(lanesBottom : float) -> void:
	var chart : EditorChart = editor.chart
	var moving : bool = drag == Drag.MOVE and (dragDelta[0] != 0 or absf(dragDelta[1]) > EditorChart.EPSILON)
	for n in chart.notes:
		if n.lane >= chart.lanes():
			continue
		if yOf(n.beat + n.length) > lanesBottom + NOTE_HEIGHT or yOf(n.beat) < -NOTE_HEIGHT:
			continue
		var selected : bool = selection.has(n)
		drawNote(n.lane, n.beat, n.length, n.sound >= 0, 0.35 if selected and moving else 1.0, selected, n == hoverNote)

func drawNote(lane : int, beat : float, length : float, sounding : bool, alpha : float, selected : bool, hovered : bool) -> void:
	var color : Color = noteColor(lane)
	var head : Rect2 = Rect2(laneLeft[lane] + 2, yOf(beat) - NOTE_HEIGHT / 2, laneWidth[lane] - 4, NOTE_HEIGHT)
	if length > EditorChart.EPSILON:
		var top : float = yOf(beat + length)
		var body : Rect2 = Rect2(head.position.x + 4, top, head.size.x - 8, head.position.y - top)
		draw_rect(body, Color(color, 0.4 * alpha))
		draw_rect(body, Color(color, 0.8 * alpha), false, 1.0)
		draw_rect(Rect2(head.position.x, top - 3, head.size.x, 6), Color(color, alpha))
	draw_rect(head, Color(color, alpha))
	draw_rect(Rect2(head.position, Vector2(head.size.x, 3)), Color(1, 1, 1, 0.55 * alpha))
	draw_rect(Rect2(head.position.x, head.end.y - 3, head.size.x, 3), Color(0, 0, 0, 0.3 * alpha))
	# A note without keysound has a hole
	if not sounding:
		draw_rect(Rect2(head.get_center() - Vector2(4, 3), Vector2(8, 6)), Color(0, 0, 0, 0.8 * alpha))
	if selected:
		draw_rect(head.grow(2), SELECTED_COLOR, false, 2.0)
	elif hovered:
		draw_rect(head.grow(1), Color(1, 1, 1, 0.8), false, 1.0)

# Notes being moved, the long note being drawn and the note under the mouse
func drawPreviews() -> void:
	var chart : EditorChart = editor.chart
	match drag:
		Drag.MOVE:
			if dragDelta[0] == 0 and absf(dragDelta[1]) < EditorChart.EPSILON:
				return
			for n in selection:
				var column : int = order.find(n.lane) + dragDelta[0]
				if column >= 0 and column < order.size():
					drawNote(order[column], n.beat + dragDelta[1], n.length, n.sound >= 0, 0.8, true, false)
		Drag.LONG:
			var length : float = maxf(editor.snap_beat(beatAt(mousePosition.y)) - dragBeat, 0.0)
			drawNote(dragLane, dragBeat, length, true, 0.6, false, false)
		Drag.NONE:
			if hoverLane != -1 and hoverNote == null and editor.tool in [BmsEditor.Tool.NOTE, BmsEditor.Tool.LONG] and hoverLane < chart.lanes():
				drawNote(hoverLane, editor.snap_beat(beatAt(mousePosition.y)), 0.0, true, 0.35, false, false)

# Names of the lanes under them
func drawKeys(lanesBottom : float, right : float) -> void:
	draw_rect(Rect2(timingLeft, lanesBottom, right - timingLeft, KEYS_HEIGHT), Color(0.06, 0.06, 0.07, 0.95))
	draw_line(Vector2(timingLeft, lanesBottom), Vector2(right, lanesBottom), EditorUI.ORANGE, 2.0)
	var labels : Array = [[timingLeft, TIMING_WIDTH, "BPM", EditorUI.YELLOW], [bgmLeft, BGM_COLUMNS * BGM_WIDTH, "BGM", SLICE_COLOR]]
	for lane in order:
		var key : int = lane % EditorChart.SIDE_LANES
		labels.append([laneLeft[lane], laneWidth[lane], "S" if key == EditorChart.SCRATCH_LANE else str(key + 1), noteColor(lane)])
	for item in labels:
		var width : float = EditorUI.TITLE_FONT.get_string_size(item[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(EditorUI.TITLE_FONT, Vector2(item[0] + (item[1] - width) / 2, lanesBottom + 19), item[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, item[3])

# Whole song from the bottom to the top, like the Quaver editor: the notes, the part on screen and the cursor
func drawMinimap() -> void:
	var chart : EditorChart = editor.chart
	var rect : Rect2 = minimapRect
	draw_rect(rect, Color(0, 0, 0, 0.7))
	var length : float = maxf(editor.song_end, 1.0)
	var scale : float = rect.size.y / length
	var columns : int = order.size()
	for n in chart.notes:
		var column : int = order.find(n.lane)
		if column == -1:
			continue
		var y : float = rect.end.y - chart.beatToTime(n.beat) * scale
		draw_rect(Rect2(rect.position.x + 2 + (rect.size.x - 4) * column / columns, y - 1, maxf((rect.size.x - 4) / columns, 1.0), 2), noteColor(n.lane))
	var viewTop : float = rect.end.y - chart.beatToTime(beatAt(0)) * scale
	var viewBottom : float = rect.end.y - chart.beatToTime(beatAt(bottom())) * scale
	var view : Rect2 = Rect2(rect.position.x, viewTop, rect.size.x, viewBottom - viewTop).intersection(rect)
	draw_rect(view, Color(1, 1, 1, 0.12))
	draw_rect(view, Color(1, 1, 1, 0.5), false, 1.0)
	var cursor : float = rect.end.y - chart.beatToTime(editor.cursor_beat) * scale
	draw_line(Vector2(rect.position.x - 4, cursor), Vector2(rect.end.x + 4, cursor), EditorUI.ORANGE, 2.0)
	draw_rect(rect, Color(1, 1, 1, 0.3), false, 1.0)

# Keysound of the note or background sound under the mouse
func drawTooltip() -> void:
	var chart : EditorChart = editor.chart
	var lines : Array = []
	if hoverNote != null and drag == Drag.NONE:
		var key : int = hoverNote.lane % EditorChart.SIDE_LANES
		var name : String = "SCRATCH" if key == EditorChart.SCRATCH_LANE else "KEY %d" % (key + 1)
		if hoverNote.lane >= EditorChart.SIDE_LANES:
			name = "2P " + name
		lines.append(name + ("  LONG NOTE" if hoverNote.length > EditorChart.EPSILON else ""))
		lines.append(editor.sound_name(hoverNote.sound))
	elif hoverBgm != null and drag == Drag.NONE:
		lines.append("BGM SOUND")
		lines.append(editor.sound_name(hoverBgm.sound))
	if lines.is_empty():
		return
	var width : float = 0.0
	for line in lines:
		width = maxf(width, EditorUI.TEXT_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var box : Rect2 = Rect2(mousePosition + Vector2(16, 12), Vector2(width + 16, lines.size() * 18 + 8))
	if box.end.x > size.x:
		box.position.x = mousePosition.x - box.size.x - 8
	if box.end.y > size.y:
		box.position.y = mousePosition.y - box.size.y - 8
	draw_rect(box, Color(0.03, 0.03, 0.04, 0.95))
	draw_rect(box, EditorUI.ORANGE, false, 1.0)
	for i in lines.size():
		draw_string(EditorUI.TEXT_FONT, box.position + Vector2(8, 18 + i * 18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, EditorUI.YELLOW if i == 0 else Color.WHITE)
