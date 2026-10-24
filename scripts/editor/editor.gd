extends Control
class_name BmsEditor

# BMS editor (EDITOR of the main menu), inspired by the Quaver editor: the lanes in the middle (EditorField),
# details, tools and timing on the left, the song and its keysounds on the right, the playback at the bottom.
# A song (OGG, MP3, WAV) is cut into keysounds like on IIDX: each note takes the slice of the song under it,
# the other slices are the background music (BGM). See BMS.md for the guide.

const SONGS_DIR = "user://songs"
const EDITOR_DIR = "user://songs/editor"
const MAIN_MENU = "res://scenes/menu/main_menu.tscn"
const GAME_SCENE = "res://scenes/game/main.tscn"
# Beat snap: lines per beat
const SNAPS = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32]
const SPEEDS = [1.0, 0.75, 0.5, 0.25]
# Zoom in pixels per beat
const ZOOM_MIN = 30.0
const ZOOM_MAX = 1200.0
const ZOOM_STEP = 1.25
const DEFAULT_ZOOM = 150.0
const UNDO_LIMIT = 200
const TOAST_TIME = 4.0
# Taps further apart start a new BPM measure (seconds)
const TAP_RESET = 2.0
const TAPS_NEEDED = 4
# Keys placing notes at the cursor: 1~7 the keys, 8 the scratch
const RECORD_KEYS = {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 6, KEY_8: 7}
const ANALOG_SCRATCH = 0.04
const SCRATCH_REPEAT_MSEC = 150
# Cut of the song: a slice every measure or every part of a beat (0 = measure)
const SLICE_STEPS = [["1 MEASURE", 0.0], ["1 BEAT", 1.0], ["1/2 BEAT", 0.5], ["1/4 BEAT", 0.25]]
const DEFAULT_SLICE_STEP = 1
const AUDIO_EXTENSIONS = ["ogg", "mp3", "wav"]
# The song to cut is a sound of the BGM longer than this (seconds)
const SONG_MIN_LENGTH = 2.0
const PANEL_WIDTH = 256.0
const MENU_HEIGHT = 30.0
const TRANSPORT_HEIGHT = 48.0

enum Tool {SELECT, NOTE, LONG, BGM}
const TOOL_NAMES = ["SELECT", "NOTE", "LONG NOTE", "BGM SOUND"]
const TOOL_KEYS = ["F1", "F2", "F3", "F4"]
const TOOL_HELP = [
	"Click a note to select it, drag to move it, drag on empty space to select several. Delete removes them.",
	"Click to place a note, click it again to remove it.",
	"Press and drag up to draw a long note.",
	"Click in the BGM columns to place the keysound chosen in the list.",
]
enum Menu {NEW, OPEN, SAVE, SAVE_DIFFICULTY, SETUP, TEST, FOLDER, EXIT,
	UNDO = 10, REDO, CUT, COPY, PASTE, DELETE, SELECT_ALL, MIRROR, MEASURE,
	ZOOM_IN = 20, ZOOM_OUT, WAVEFORM, GO_START, GO_END,
	PLAY = 30, METRONOME, HITSOUNDS, SLICE, ADD_SOUNDS, SPEED = 40,
	GUIDE = 50}

# Kept while the chart is tested in the game
static var testPath := ""
static var testBeat := 0.0
static var testZoom := DEFAULT_ZOOM
static var testSnap := 3
static var testUndo := []
static var testDoublePlay := false

var chart: EditorChart
var player: EditorPlayer
var field: EditorField
var tool := Tool.NOTE
var snap_index := 3
var speed_index := 0
var zoom := DEFAULT_ZOOM
var cursor_beat := 0.0
# Beat where the playback started, STOP goes back there
var play_start_beat := 0.0
var dirty := false
var undo_stack := []
var redo_stack := []
# Keysound of the new notes, -1 for AUTO: the sound under the note
var current_sound := -1
var keep_in_bgm := true
var show_waveform := true
var clipboard := []
# Waveform: envelope of each sound file, and the peaks of the sounds as placed
var envelopes := {}
var envelope_task := -1
var envelope_jobs := []
var envelope_results := {}
var waveform := PackedFloat32Array()
# End of the song (seconds)
var song_end := 1.0
var level := 1
# Cut of the song in a thread
var busy := false
var slice_task := -1
var slice_job := {}
var slice_progress := 0.0
var next_slice := 1
var taps := []
var analog_previous := [0.0, 0.0]
var last_scratch := [0, 0]
var listed_sounds := -1
var toast_until := 0
var pending_action: Callable
var timing_dialog_beat := 0.0

# Interface
var menus := {}
var details := {}
var tool_buttons := []
var bpm_spin: SpinBox
var offset_spin: SpinBox
var tap_label: Label
var song_title: Label
var song_artist: Label
var song_difficulty: Label
var song_file: Label
var sound_list: ItemList
var keep_check: CheckBox
var play_button: Button
var time_label: Label
var remain_label: Label
var seek_slider: HSlider
var speed_button: Button
var metronome_button: Button
var hitsound_button: Button
var toast_panel: PanelContainer
var toast_label: Label
var welcome: Control
var progress_panel: PanelContainer
var progress_label: Label
var progress_bar: ProgressBar
var stage: TextureRect
# Dialogs
var setup_dialog: AcceptDialog
var setup_new := false
var setup_fields := {}
var setup_audio := ""
var setup_preview: AudioStreamPlayer
var difficulty_dialog: AcceptDialog
var difficulty_option: OptionButton
var difficulty_level: SpinBox
var timing_dialog: AcceptDialog
var timing_label: Label
var timing_bpm: SpinBox
var timing_stop: SpinBox
var timing_delete: Button
var measure_dialog: AcceptDialog
var measure_spin: SpinBox
var measure_label: Label
var slice_dialog: AcceptDialog
var slice_source: OptionButton
var slice_step: OptionButton
var slice_sources := []
var confirm_dialog: ConfirmationDialog
var help_dialog: AcceptDialog
var open_dialog: FileDialog
var audio_dialog: FileDialog
var sounds_dialog: FileDialog

func _ready() -> void:
	theme = EditorUI.make_theme()
	player = EditorPlayer.new()
	add_child(player)
	build_background()
	field = EditorField.new()
	field.editor = self
	add_child(field)
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.offset_left = PANEL_WIDTH + 16
	field.offset_right = -PANEL_WIDTH - 16
	field.offset_top = MENU_HEIGHT + 6
	field.offset_bottom = -TRANSPORT_HEIGHT - 6
	build_left()
	build_right()
	build_transport()
	build_menus()
	build_welcome()
	build_overlays()
	build_dialogs()
	get_window().files_dropped.connect(_on_files_dropped)

	# Back from a test play
	if Loader.editor_test:
		Loader.editor_test = false
		Global.double_play = testDoublePlay
		var tested = EditorChart.load_file(testPath)
		if tested != null:
			open_chart(tested)
			undo_stack = testUndo
			cursor_beat = testBeat
			zoom = testZoom
			snap_index = testSnap
	update_tools()

func _exit_tree() -> void:
	Training.set_bus_rate(1.0)
	# The threads use this node
	for task in [slice_task, envelope_task]:
		if task != -1:
			WorkerThreadPool.wait_for_task_completion(task)

# Layout of the screen

func build_background() -> void:
	stage = TextureRect.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage.modulate = Color(1, 1, 1, 0.22)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

func side_column(left: bool) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	if left:
		column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		column.offset_left = 10
		column.offset_right = 10 + PANEL_WIDTH
	else:
		column.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		column.offset_left = -10 - PANEL_WIDTH
		column.offset_right = -10
	column.offset_top = MENU_HEIGHT + 10
	column.offset_bottom = -TRANSPORT_HEIGHT - 10
	add_child(column)
	return column

func build_left() -> void:
	var column = side_column(true)
	var panel = EditorUI.panel("DETAILS")
	column.add_child(panel)
	var body = EditorUI.body(panel)
	for row in [["notes", "NOTES"], ["bgm", "BGM SOUNDS"], ["level", "LEVEL (GAME)"], ["bpm", "BPM"], ["position", "MEASURE"], ["speed", "PLAYBACK SPEED"]]:
		details[row[0]] = EditorUI.value_row(body, row[1])
	# Beat snap with its buttons
	var snap_row = HBoxContainer.new()
	var snap_name = EditorUI.label("BEAT SNAP", EditorUI.DIM)
	snap_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snap_row.add_child(snap_name)
	for step in [-1, 1]:
		var button = EditorUI.button("")
		button.icon = EditorUI.icon("minus" if step < 0 else "plus")
		button.tooltip_text = "CTRL + MOUSE WHEEL"
		button.pressed.connect(change_snap.bind(step))
		snap_row.add_child(button)
		if step < 0:
			details["snap"] = EditorUI.label("")
			details["snap"].custom_minimum_size = Vector2(44, 0)
			details["snap"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			snap_row.add_child(details["snap"])
	body.add_child(snap_row)

	panel = EditorUI.panel("TOOLS")
	column.add_child(panel)
	body = EditorUI.body(panel)
	var group = ButtonGroup.new()
	for i in TOOL_NAMES.size():
		var button = EditorUI.button(TOOL_NAMES[i], true)
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = TOOL_HELP[i]
		button.pressed.connect(set_tool.bind(i))
		var key = EditorUI.label(TOOL_KEYS[i], EditorUI.DIM)
		key.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		key.offset_left = -40
		key.offset_right = -10
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(key)
		body.add_child(button)
		tool_buttons.append(button)

	panel = EditorUI.panel("TIMING")
	column.add_child(panel)
	body = EditorUI.body(panel)
	var grid = GridContainer.new()
	grid.columns = 2
	body.add_child(grid)
	grid.add_child(EditorUI.label("BPM", EditorUI.DIM))
	bpm_spin = EditorUI.spin_box(1, 999, 0.01)
	bpm_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bpm_spin.tooltip_text = "Tempo of the start of the song. Change it with the metronome on until the clicks follow the song."
	bpm_spin.value_changed.connect(_on_bpm_changed)
	grid.add_child(bpm_spin)
	grid.add_child(EditorUI.label("OFFSET", EditorUI.DIM))
	offset_spin = EditorUI.spin_box(0, 60000, 1, "ms")
	offset_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offset_spin.tooltip_text = "Time of the first beat in the song file. Measure 000 lasts this long, measure 001 starts on the first beat."
	offset_spin.value_changed.connect(_on_offset_changed)
	grid.add_child(offset_spin)
	var tap_row = HBoxContainer.new()
	var tap = EditorUI.button("TAP BPM")
	tap.tooltip_text = "Click (or press T) on each beat while the song plays: the BPM follows your taps."
	tap.pressed.connect(tap_bpm)
	tap_row.add_child(tap)
	tap_label = EditorUI.label("", EditorUI.YELLOW)
	tap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tap_row.add_child(tap_label)
	body.add_child(tap_row)
	var hint = EditorUI.label("CLICK THE BPM COLUMN TO ADD A TEMPO CHANGE", EditorUI.DIM, 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(hint)

func build_right() -> void:
	var column = side_column(false)
	var panel = EditorUI.panel("SONG")
	column.add_child(panel)
	var body = EditorUI.body(panel)
	song_title = EditorUI.title_label("", 16)
	song_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	song_title.add_theme_font_override("font", EditorUI.TEXT_FONT)
	song_title.add_theme_font_size_override("font_size", 16)
	body.add_child(song_title)
	song_artist = EditorUI.label("", EditorUI.DIM)
	song_artist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(song_artist)
	song_difficulty = EditorUI.title_label("", 14)
	body.add_child(song_difficulty)
	song_file = EditorUI.label("", EditorUI.DIM, 12)
	song_file.clip_text = true
	body.add_child(song_file)
	var setup = EditorUI.button("SONG SETUP")
	setup.pressed.connect(open_setup.bind(false))
	body.add_child(setup)

	panel = EditorUI.panel("KEYSOUNDS")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	var add = EditorUI.button("")
	add.icon = EditorUI.icon("plus")
	add.tooltip_text = "Add sound files (WAV, OGG, MP3) to the keysounds."
	add.pressed.connect(func(): if chart: sounds_dialog.popup_centered_ratio(0.7))
	EditorUI.header(panel).add_child(add)
	body = EditorUI.body(panel)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var slice = EditorUI.button("SLICE THE SONG")
	slice.tooltip_text = "Cut the song into keysounds: each note plays its part of the song, like on IIDX."
	slice.add_theme_color_override("font_color", EditorUI.YELLOW)
	slice.pressed.connect(open_slice_dialog)
	body.add_child(slice)
	sound_list = ItemList.new()
	sound_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sound_list.focus_mode = Control.FOCUS_NONE
	sound_list.item_selected.connect(_on_sound_selected)
	sound_list.custom_minimum_size = Vector2(0, 120)
	body.add_child(sound_list)
	var row = HBoxContainer.new()
	var assign = EditorUI.button("ASSIGN")
	assign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assign.tooltip_text = "Give the chosen keysound to the selected notes (AUTO: the sound under each note)."
	assign.pressed.connect(assign_sound)
	row.add_child(assign)
	var play = EditorUI.button("")
	play.icon = EditorUI.icon("play")
	play.tooltip_text = "Listen to the chosen keysound."
	play.pressed.connect(func(): if chart and current_sound >= 0: player.preview(current_sound))
	row.add_child(play)
	body.add_child(row)
	keep_check = CheckBox.new()
	keep_check.text = "DELETED NOTES STAY IN BGM"
	keep_check.focus_mode = Control.FOCUS_NONE
	keep_check.button_pressed = keep_in_bgm
	keep_check.tooltip_text = "A deleted note gives its keysound back to the BGM: the song stays complete."
	keep_check.toggled.connect(func(on): keep_in_bgm = on)
	keep_check.add_theme_font_size_override("font_size", 12)
	body.add_child(keep_check)

func build_transport() -> void:
	var bar = PanelContainer.new()
	var style = EditorUI.box(Color(0.02, 0.02, 0.03, 0.95), Color.TRANSPARENT, 0, 6)
	style.border_color = EditorUI.ORANGE
	style.border_width_top = 2
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -TRANSPORT_HEIGHT
	add_child(bar)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	play_button = EditorUI.button("")
	play_button.icon = EditorUI.icon("play")
	play_button.tooltip_text = "PLAY / PAUSE (SPACE)"
	play_button.pressed.connect(toggle_play)
	row.add_child(play_button)
	var stop = EditorUI.button("")
	stop.icon = EditorUI.icon("stop")
	stop.tooltip_text = "STOP: back to where the playback started"
	stop.pressed.connect(stop_playback)
	row.add_child(stop)
	var start = EditorUI.button("")
	start.icon = EditorUI.icon("start")
	start.tooltip_text = "GO TO THE START (HOME)"
	start.pressed.connect(func(): seek_beat(0.0))
	row.add_child(start)
	time_label = EditorUI.label("00:00.000")
	time_label.custom_minimum_size = Vector2(96, 0)
	row.add_child(time_label)
	seek_slider = HSlider.new()
	seek_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seek_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seek_slider.focus_mode = Control.FOCUS_NONE
	seek_slider.step = 0.001
	seek_slider.value_changed.connect(func(value): if chart: seek_beat(chart.timeToBeat(value)))
	row.add_child(seek_slider)
	remain_label = EditorUI.label("-00:00.000")
	remain_label.custom_minimum_size = Vector2(104, 0)
	remain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(remain_label)
	speed_button = EditorUI.button("x1.00")
	speed_button.custom_minimum_size = Vector2(70, 0)
	speed_button.tooltip_text = "PLAYBACK SPEED (the pitch does not change)"
	speed_button.pressed.connect(func(): set_speed((speed_index + 1) % SPEEDS.size()))
	row.add_child(speed_button)
	metronome_button = EditorUI.button("METRONOME", true)
	metronome_button.tooltip_text = "Click on each beat (M), to check the BPM and the offset."
	metronome_button.toggled.connect(func(on): set_metronome(on))
	row.add_child(metronome_button)
	hitsound_button = EditorUI.button("HITSOUND", true)
	hitsound_button.tooltip_text = "Tick on each note while playing."
	hitsound_button.toggled.connect(func(on): set_hitsounds(on))
	row.add_child(hitsound_button)

func build_menus() -> void:
	var bar_panel = PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", EditorUI.box(Color(0.02, 0.02, 0.03, 0.95), Color.TRANSPARENT, 0, 0))
	bar_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_panel.offset_bottom = MENU_HEIGHT
	add_child(bar_panel)
	var row = HBoxContainer.new()
	bar_panel.add_child(row)
	var bar = MenuBar.new()
	bar.flat = true
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	var title = EditorUI.title_label("noiseBMS EDITOR  ", 12, EditorUI.ORANGE)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var ctrl = KEY_MASK_CTRL
	add_menu(bar, "FILE", [
		["NEW CHART...", Menu.NEW, ctrl | KEY_N], ["OPEN CHART...", Menu.OPEN, ctrl | KEY_O], [],
		["SAVE", Menu.SAVE, ctrl | KEY_S], ["SAVE AS A NEW DIFFICULTY...", Menu.SAVE_DIFFICULTY, ctrl | KEY_MASK_SHIFT | KEY_S], [],
		["SONG SETUP...", Menu.SETUP, ctrl | KEY_P], ["TEST PLAY", Menu.TEST, KEY_F5], ["OPEN THE SONG FOLDER", Menu.FOLDER, 0], [],
		["BACK TO THE MENU", Menu.EXIT, 0],
	])
	add_menu(bar, "EDIT", [
		["UNDO", Menu.UNDO, ctrl | KEY_Z], ["REDO", Menu.REDO, ctrl | KEY_Y], [],
		["CUT", Menu.CUT, ctrl | KEY_X], ["COPY", Menu.COPY, ctrl | KEY_C], ["PASTE AT THE CURSOR", Menu.PASTE, ctrl | KEY_V],
		["DELETE", Menu.DELETE, KEY_DELETE], ["SELECT ALL", Menu.SELECT_ALL, ctrl | KEY_A], ["MIRROR THE SELECTION", Menu.MIRROR, ctrl | KEY_H], [],
		["MEASURE LENGTH...", Menu.MEASURE, 0],
	])
	add_menu(bar, "VIEW", [
		["ZOOM IN", Menu.ZOOM_IN, KEY_EQUAL], ["ZOOM OUT", Menu.ZOOM_OUT, KEY_MINUS], [],
		["WAVEFORM", Menu.WAVEFORM, KEY_W, true], [],
		["GO TO THE START", Menu.GO_START, KEY_HOME], ["GO TO THE END", Menu.GO_END, KEY_END],
	])
	var audio_items = [["PLAY / PAUSE", Menu.PLAY, KEY_SPACE], ["METRONOME", Menu.METRONOME, KEY_M, true], ["HITSOUNDS", Menu.HITSOUNDS, KEY_N, true], []]
	for i in SPEEDS.size():
		audio_items.append(["SPEED x%.2f" % SPEEDS[i], Menu.SPEED + i, 0, true])
	audio_items += [[], ["SLICE THE SONG INTO KEYSOUNDS...", Menu.SLICE, 0], ["ADD KEYSOUNDS...", Menu.ADD_SOUNDS, 0]]
	add_menu(bar, "AUDIO", audio_items)
	add_menu(bar, "HELP", [["HOW TO MAKE A BMS", Menu.GUIDE, KEY_F1 | KEY_MASK_SHIFT]])

# Items: [text, id, accelerator, checkable], [] for a separator
func add_menu(bar: MenuBar, title: String, items: Array) -> void:
	var popup = PopupMenu.new()
	popup.name = title
	for item in items:
		if item.is_empty():
			popup.add_separator()
		elif item.size() > 3 and item[3]:
			popup.add_check_item(item[0], item[1], item[2])
		else:
			popup.add_item(item[0], item[1], item[2])
	popup.id_pressed.connect(_on_menu)
	bar.add_child(popup)
	menus[title] = popup

func build_welcome() -> void:
	welcome = ColorRect.new()
	welcome.color = Color(0, 0, 0, 0.75)
	welcome.set_anchors_preset(Control.PRESET_FULL_RECT)
	welcome.offset_top = MENU_HEIGHT
	welcome.offset_bottom = -TRANSPORT_HEIGHT
	welcome.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(welcome)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	welcome.add_child(center)
	var panel = EditorUI.panel("BMS EDITOR")
	panel.add_theme_stylebox_override("panel", EditorUI.box(Color(0.03, 0.03, 0.04, 0.98), EditorUI.ORANGE, 1, 0))
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var body = EditorUI.body(panel)
	body.add_theme_constant_override("separation", 10)
	var title = EditorUI.title_label("MAKE YOUR OWN KEYSOUNDED CHARTS", 16, EditorUI.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	for step in [
		"1. NEW CHART: choose the song (OGG, MP3 or WAV), its title and its BPM.",
		"2. Play it with the METRONOME, adjust the BPM and the OFFSET until the clicks follow the beat.",
		"3. SLICE THE SONG: it is cut into keysounds on the beats.",
		"4. Place the notes: each one takes the sound under it, like on IIDX.",
		"5. SAVE, then TEST PLAY (F5). The chart is in the music select.",
	]:
		var label = EditorUI.label(step)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(label)
	var hint = EditorUI.label("You can also drop a song file or a BMS on this window.", EditorUI.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(hint)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for item in [["NEW CHART", func(): open_setup(true)], ["OPEN CHART", func(): open_dialog.popup_centered_ratio(0.7)], ["GUIDE", show_help], ["MAIN MENU", leave]]:
		var button = EditorUI.button(item[0])
		button.custom_minimum_size = Vector2(130, 40)
		button.pressed.connect(item[1])
		row.add_child(button)
	body.add_child(row)

func build_overlays() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", EditorUI.box(Color(0.03, 0.03, 0.04, 0.95), EditorUI.ORANGE, 1, 8))
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.offset_top = MENU_HEIGHT + 12
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.hide()
	toast_label = EditorUI.label("", EditorUI.YELLOW)
	toast_panel.add_child(toast_label)
	add_child(toast_panel)

	progress_panel = PanelContainer.new()
	progress_panel.add_theme_stylebox_override("panel", EditorUI.box(Color(0.03, 0.03, 0.04, 0.97), EditorUI.ORANGE, 2, 16))
	progress_panel.set_anchors_preset(Control.PRESET_CENTER)
	progress_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	progress_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	progress_panel.custom_minimum_size = Vector2(420, 0)
	progress_panel.hide()
	var box = VBoxContainer.new()
	progress_label = EditorUI.title_label("SLICING THE SONG...", 16, EditorUI.YELLOW)
	box.add_child(progress_label)
	progress_bar = ProgressBar.new()
	progress_bar.max_value = 1.0
	progress_bar.custom_minimum_size = Vector2(0, 16)
	progress_bar.show_percentage = false
	box.add_child(progress_bar)
	progress_panel.add_child(box)
	add_child(progress_panel)

func dialog(title: String, ok_text: String) -> AcceptDialog:
	var window = AcceptDialog.new()
	window.title = title
	window.ok_button_text = ok_text
	window.theme = theme
	window.exclusive = true
	window.unresizable = true
	add_child(window)
	return window

func dialog_grid(window: AcceptDialog) -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	window.add_child(grid)
	return grid

func build_dialogs() -> void:
	# Song setup, also the new chart
	setup_dialog = dialog("SONG SETUP", "APPLY")
	setup_dialog.add_cancel_button("CANCEL")
	setup_dialog.confirmed.connect(_on_setup_confirmed)
	setup_dialog.canceled.connect(func(): setup_preview.stop())
	var grid = dialog_grid(setup_dialog)
	setup_fields["audio_label"] = EditorUI.label("SONG FILE", EditorUI.DIM)
	grid.add_child(setup_fields["audio_label"])
	var audio_row = HBoxContainer.new()
	var choose = EditorUI.button("CHOOSE...")
	choose.pressed.connect(func(): audio_dialog.popup_centered_ratio(0.7))
	audio_row.add_child(choose)
	setup_fields["audio"] = EditorUI.label("NO FILE (KEYSOUNDS ONLY)", EditorUI.YELLOW)
	setup_fields["audio"].clip_text = true
	setup_fields["audio"].custom_minimum_size = Vector2(200, 0)
	audio_row.add_child(setup_fields["audio"])
	setup_fields["audio_row"] = audio_row
	grid.add_child(audio_row)
	for item in [["title", "TITLE"], ["artist", "ARTIST"], ["genre", "GENRE"]]:
		grid.add_child(EditorUI.label(item[1], EditorUI.DIM))
		setup_fields[item[0]] = EditorUI.line_edit(item[1].to_lower())
		grid.add_child(setup_fields[item[0]])
	grid.add_child(EditorUI.label("DIFFICULTY", EditorUI.DIM))
	setup_fields["difficulty"] = EditorUI.option_button(BmsChart.DIFFICULTIES.slice(1).map(func(d): return d.to_upper()))
	grid.add_child(setup_fields["difficulty"])
	grid.add_child(EditorUI.label("LEVEL", EditorUI.DIM))
	setup_fields["level"] = EditorUI.spin_box(1, 12, 1)
	setup_fields["level"].tooltip_text = "#PLAYLEVEL for the other BMS players. noiseBMS shows its own level, from the density of the notes."
	grid.add_child(setup_fields["level"])
	setup_fields["bpm_label"] = EditorUI.label("BPM", EditorUI.DIM)
	grid.add_child(setup_fields["bpm_label"])
	var bpm_row = HBoxContainer.new()
	setup_fields["bpm"] = EditorUI.spin_box(1, 999, 0.01)
	bpm_row.add_child(setup_fields["bpm"])
	var listen = EditorUI.button("LISTEN", true)
	listen.toggled.connect(func(on):
		if on and setup_preview.stream:
			setup_preview.play()
		else:
			setup_preview.stop())
	setup_fields["listen"] = listen
	bpm_row.add_child(listen)
	var tap = EditorUI.button("TAP")
	tap.tooltip_text = "Click on each beat while listening to the song."
	tap.pressed.connect(func(): setup_tap())
	bpm_row.add_child(tap)
	setup_fields["bpm_row"] = bpm_row
	grid.add_child(bpm_row)
	grid.add_child(EditorUI.label("STYLE", EditorUI.DIM))
	setup_fields["style"] = EditorUI.option_button(["SINGLE PLAY (7 KEYS)", "DOUBLE PLAY (14 KEYS)"])
	grid.add_child(setup_fields["style"])
	setup_preview = AudioStreamPlayer.new()
	setup_preview.finished.connect(func(): listen.button_pressed = false)
	add_child(setup_preview)

	difficulty_dialog = dialog("SAVE AS A NEW DIFFICULTY", "CREATE")
	difficulty_dialog.add_cancel_button("CANCEL")
	difficulty_dialog.confirmed.connect(_on_new_difficulty)
	grid = dialog_grid(difficulty_dialog)
	var info = EditorUI.label("A copy of this chart in the same folder, with the same keysounds.\nDeleted notes keep playing in the BGM: remove notes to make it easier.", EditorUI.DIM)
	grid.add_child(EditorUI.label("", EditorUI.DIM))
	grid.add_child(info)
	grid.add_child(EditorUI.label("DIFFICULTY", EditorUI.DIM))
	difficulty_option = EditorUI.option_button(BmsChart.DIFFICULTIES.slice(1).map(func(d): return d.to_upper()))
	grid.add_child(difficulty_option)
	grid.add_child(EditorUI.label("LEVEL", EditorUI.DIM))
	difficulty_level = EditorUI.spin_box(1, 12, 1)
	grid.add_child(difficulty_level)

	timing_dialog = dialog("TEMPO", "OK")
	timing_dialog.add_cancel_button("CANCEL")
	timing_delete = timing_dialog.add_button("DELETE", true, "delete")
	timing_dialog.custom_action.connect(func(_action): delete_timing())
	timing_dialog.confirmed.connect(_on_timing_confirmed)
	grid = dialog_grid(timing_dialog)
	grid.add_child(EditorUI.label("PLACE", EditorUI.DIM))
	timing_label = EditorUI.label("", EditorUI.YELLOW)
	grid.add_child(timing_label)
	grid.add_child(EditorUI.label("BPM", EditorUI.DIM))
	timing_bpm = EditorUI.spin_box(1, 999, 0.01)
	grid.add_child(timing_bpm)
	grid.add_child(EditorUI.label("STOP", EditorUI.DIM))
	timing_stop = EditorUI.spin_box(0, 64, 0.25, "beats")
	timing_stop.tooltip_text = "The chart stops scrolling for this long (0 = no stop)."
	grid.add_child(timing_stop)

	measure_dialog = dialog("MEASURE LENGTH", "OK")
	measure_dialog.add_cancel_button("CANCEL")
	measure_dialog.confirmed.connect(_on_measure_confirmed)
	grid = dialog_grid(measure_dialog)
	grid.add_child(EditorUI.label("MEASURE", EditorUI.DIM))
	measure_label = EditorUI.label("", EditorUI.YELLOW)
	grid.add_child(measure_label)
	grid.add_child(EditorUI.label("LENGTH", EditorUI.DIM))
	measure_spin = EditorUI.spin_box(0.0625, 16, 0.0625)
	measure_spin.tooltip_text = "1 = 4/4, 0.75 = 3/4, 0.5 = 2/4. The notes keep their time."
	grid.add_child(measure_spin)

	slice_dialog = dialog("SLICE THE SONG INTO KEYSOUNDS", "SLICE")
	slice_dialog.add_cancel_button("CANCEL")
	slice_dialog.confirmed.connect(_on_slice_confirmed)
	grid = dialog_grid(slice_dialog)
	grid.add_child(EditorUI.label("SONG", EditorUI.DIM))
	slice_source = EditorUI.option_button([])
	grid.add_child(slice_source)
	grid.add_child(EditorUI.label("CUT EVERY", EditorUI.DIM))
	slice_step = EditorUI.option_button(SLICE_STEPS.map(func(s): return s[0]))
	slice_step.selected = DEFAULT_SLICE_STEP
	grid.add_child(slice_step)
	grid.add_child(EditorUI.label("", EditorUI.DIM))
	var explanation = EditorUI.label("Set the BPM and the offset first.\nThe song is cut into WAV files (slices folder) on the beats\nand on the notes already placed. Each note takes the slice\nunder it, the other slices play as BGM. A note placed between\ntwo cuts cuts its slice again.", EditorUI.DIM)
	grid.add_child(explanation)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "UNSAVED CHANGES"
	confirm_dialog.dialog_text = "The chart has unsaved changes. Save it?"
	confirm_dialog.ok_button_text = "SAVE"
	confirm_dialog.cancel_button_text = "CANCEL"
	confirm_dialog.theme = theme
	confirm_dialog.add_button("DON'T SAVE", true, "discard")
	confirm_dialog.confirmed.connect(func():
		if save_chart() == OK:
			pending_action.call())
	confirm_dialog.custom_action.connect(func(_action):
		confirm_dialog.hide()
		pending_action.call())
	add_child(confirm_dialog)

	help_dialog = dialog("HOW TO MAKE A BMS", "OK")
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 460)
	help_dialog.add_child(scroll)
	var help = RichTextLabel.new()
	help.bbcode_enabled = true
	help.fit_content = true
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.text = HELP_TEXT
	scroll.add_child(help)

	var native = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	open_dialog = file_dialog(FileDialog.FILE_MODE_OPEN_FILE, ["*.bms, *.bme, *.bml ; BMS charts"], native)
	open_dialog.title = "OPEN A BMS CHART"
	open_dialog.current_dir = ProjectSettings.globalize_path(SONGS_DIR)
	open_dialog.file_selected.connect(func(file): guard(open_file.bind(file)))
	audio_dialog = file_dialog(FileDialog.FILE_MODE_OPEN_FILE, ["*.ogg, *.mp3, *.wav ; Songs"], native)
	audio_dialog.title = "CHOOSE THE SONG"
	audio_dialog.file_selected.connect(set_setup_audio)
	sounds_dialog = file_dialog(FileDialog.FILE_MODE_OPEN_FILES, ["*.wav, *.ogg, *.mp3 ; Sounds"], native)
	sounds_dialog.title = "ADD KEYSOUNDS"
	sounds_dialog.files_selected.connect(add_sound_files)

func file_dialog(mode: int, filters: Array, native: bool) -> FileDialog:
	var window = FileDialog.new()
	window.file_mode = mode
	window.access = FileDialog.ACCESS_FILESYSTEM
	window.filters = PackedStringArray(filters)
	window.use_native_dialog = native
	window.theme = theme
	add_child(window)
	return window

const HELP_TEXT = """[font_size=18][color=#ffd11a]MAKE A KEYSOUNDED BMS FROM AN OGG[/color][/font_size]

[color=#ff8c0d]1. NEW CHART[/color] (FILE menu, CTRL+N): choose the song file, write the title and the artist, and the BPM (TAP on each beat while listening helps). The chart is saved in songs/editor/<title>.

[color=#ff8c0d]2. TIMING[/color]: press SPACE to play and turn the METRONOME on (M). Change the BPM until the clicks keep up with the song, then the OFFSET (time of the first beat, in ms) until they fall on the beats. The waveform behind the lanes shows the hits of the song. A tempo change: click the BPM column.

[color=#ff8c0d]3. SLICE THE SONG[/color] (KEYSOUNDS panel): the song is cut into small WAV files on the beats. They play one after the other in the BGM columns: the song sounds the same.

[color=#ff8c0d]4. NOTES[/color]: with the NOTE tool (F2), click a lane: the note takes the slice under it, it is now a keysound, as on IIDX. A note between two cuts cuts the slice again. LONG NOTE (F3): drag up. The scratch is the red lane. Right click deletes, the sound goes back to the BGM. While playing, the keys 1~7 and 8 (scratch) or your controller place notes on the beat snap.

[color=#ff8c0d]5. SAVE[/color] (CTRL+S) and [color=#ff8c0d]TEST PLAY[/color] (F5). FILE > SAVE AS A NEW DIFFICULTY makes the other difficulties with the same keysounds.

[color=#ffd11a]SHORTCUTS[/color]
SPACE play / pause    MOUSE WHEEL or UP / DOWN move    SHIFT + WHEEL or PAGE UP / DOWN by measure
CTRL + WHEEL beat snap    ALT + WHEEL or + / - zoom    F1~F4 tools    T tap the BPM
CTRL+Z undo    CTRL+Y redo    CTRL+C / X / V copy, cut, paste at the cursor    DELETE    CTRL+A    CTRL+H mirror
1~7, 8 place a note at the cursor (or while playing)    ESC deselect, then back to the menu

More in BMS.md, in the folder of the game."""

# Chart files

func open_file(file: String) -> void:
	file = local_path(file)
	var loaded = EditorChart.load_file(file)
	if loaded == null:
		toast("COULD NOT READ " + file.get_file())
		return
	open_chart(loaded)
	if loaded.hadRandom:
		toast("THIS BMS HAS #RANDOM BLOCKS: ONLY THEIR FIRST BRANCH IS EDITED AND SAVED")
	else:
		toast("OPENED " + file.get_file())

func open_chart(new_chart: EditorChart) -> void:
	chart = new_chart
	player.setChart(chart)
	undo_stack.clear()
	redo_stack.clear()
	field.selection.clear()
	dirty = false
	current_sound = -1
	cursor_beat = 0.0
	listed_sounds = -1
	envelopes.clear()
	next_slice = find_next_slice()
	load_stage()
	welcome.hide()
	refresh_all()

# Files are kept under user:// as user:// paths, the music select only scans those
func local_path(file: String) -> String:
	var user = ProjectSettings.globalize_path("user://").trim_suffix("/") + "/"
	if file.begins_with(user):
		return "user://" + file.substr(user.length())
	return file

func save_chart() -> Error:
	if chart == null:
		return FAILED
	var error = chart.save()
	if error != OK:
		toast("COULD NOT SAVE: " + error_string(error))
		return error
	dirty = false
	Loader.clear_song_catalog()
	toast("SAVED " + chart.path.get_file())
	return OK

# Do an action after saving or discarding the changes
func guard(action: Callable) -> void:
	if chart != null and dirty:
		pending_action = action
		confirm_dialog.popup_centered()
	else:
		action.call()

func leave() -> void:
	guard(func():
		player.stop()
		Training.set_bus_rate(1.0)
		get_tree().change_scene_to_file(MAIN_MENU))

func test_play() -> void:
	if chart == null or save_chart() != OK:
		return
	var played = BmsChart.load_file(chart.path, false)
	if played == null or Loader.note_count(played.noteArray) == 0:
		toast("PLACE SOME NOTES FIRST")
		return
	player.stop()
	testPath = chart.path
	testBeat = cursor_beat
	testZoom = zoom
	testSnap = snap_index
	testUndo = undo_stack
	testDoublePlay = Global.double_play
	Global.double_play = chart.double
	Global.p1_joined = true
	Global.p2_joined = false
	Global.battle = false
	Loader.editor_test = true
	Loader.file_path = chart.path
	Loader.chart_difficulty = played.difficultyName
	Loader.difficulty_slot = 0
	Training.set_bus_rate(1.0)
	get_tree().change_scene_to_file(GAME_SCENE)

func open_folder() -> void:
	if chart != null:
		OS.shell_open(ProjectSettings.globalize_path(chart.folder()))

# Background picture of the chart (#STAGEFILE, #BACKBMP, #BANNER), dimmed like in Quaver
func load_stage() -> void:
	stage.texture = null
	for line in chart.extraHeader:
		var parts = line.split(" ", false, 1)
		if parts.size() == 2 and parts[0].to_upper() in ["#STAGEFILE", "#BACKBMP", "#BANNER"]:
			var image = Image.load_from_file(chart.folder().path_join(parts[1].strip_edges().replace("\\", "/")))
			if image != null:
				stage.texture = ImageTexture.create_from_image(image)
				return

func _on_files_dropped(files: PackedStringArray) -> void:
	if busy or files.is_empty():
		return
	var file = files[0]
	if EditorChart.is_editable(file):
		guard(open_file.bind(file))
	elif file.get_extension().to_lower() in AUDIO_EXTENSIONS:
		if chart == null:
			open_setup(true)
			set_setup_audio(file)
		else:
			add_sound_files(files)

# Song setup and new chart

func open_setup(new_chart: bool) -> void:
	if not new_chart and chart == null:
		return
	setup_new = new_chart
	setup_dialog.title = "NEW CHART" if new_chart else "SONG SETUP"
	setup_dialog.ok_button_text = "CREATE" if new_chart else "APPLY"
	for key in ["audio_label", "audio_row", "bpm_label", "bpm_row"]:
		setup_fields[key].visible = new_chart
	var source = chart if not new_chart else EditorChart.new()
	setup_fields["title"].text = source.title
	setup_fields["artist"].text = source.artist
	setup_fields["genre"].text = source.genre
	setup_fields["difficulty"].selected = source.difficulty - 1
	setup_fields["level"].value = source.playLevel
	setup_fields["style"].selected = 1 if source.double else 0
	if new_chart:
		setup_audio = ""
		setup_preview.stream = null
		setup_fields["audio"].text = "NO FILE (KEYSOUNDS ONLY)"
		setup_fields["bpm"].value = EditorChart.DEFAULT_BPM
		taps.clear()
	setup_dialog.popup_centered()

func set_setup_audio(file: String) -> void:
	setup_audio = file
	setup_fields["audio"].text = file.get_file()
	setup_fields["listen"].button_pressed = false
	setup_preview.stream = AudioSlicer.loadStream(file)
	if setup_fields["title"].text == "":
		setup_fields["title"].text = file.get_file().get_basename()

func setup_tap() -> void:
	var bpm = tap()
	if bpm > 0.0:
		setup_fields["bpm"].value = bpm

func _on_setup_confirmed() -> void:
	setup_preview.stop()
	var title = setup_fields["title"].text.strip_edges()
	if setup_new:
		create_chart(title if title != "" else "untitled")
		return
	var double = setup_fields["style"].selected == 1
	if not double and chart.notes.any(func(n): return n.lane >= EditorChart.SIDE_LANES):
		toast("DELETE THE NOTES OF THE 2P SIDE BEFORE GOING BACK TO SINGLE PLAY")
		double = true
	begin_change()
	chart.title = title
	chart.artist = setup_fields["artist"].text.strip_edges()
	chart.genre = setup_fields["genre"].text.strip_edges()
	chart.difficulty = setup_fields["difficulty"].selected + 1
	chart.playLevel = int(setup_fields["level"].value)
	chart.double = double
	end_change()

func create_chart(title: String) -> void:
	var folder = unique_path(EDITOR_DIR.path_join(safe_name(title)), "")
	DirAccess.make_dir_recursive_absolute(folder)
	var new_chart = EditorChart.new()
	new_chart.title = title
	new_chart.artist = setup_fields["artist"].text.strip_edges()
	new_chart.genre = setup_fields["genre"].text.strip_edges()
	new_chart.difficulty = setup_fields["difficulty"].selected + 1
	new_chart.playLevel = int(setup_fields["level"].value)
	new_chart.double = setup_fields["style"].selected == 1
	new_chart.bpm = setup_fields["bpm"].value
	new_chart.path = unique_path(folder.path_join(new_chart.difficultyName().to_lower()), ".bme")
	if setup_audio != "":
		var song = safe_name(setup_audio.get_file().get_basename()) + "." + setup_audio.get_extension().to_lower()
		if DirAccess.copy_absolute(setup_audio, folder.path_join(song)) != OK:
			toast("COULD NOT COPY " + setup_audio.get_file())
			return
		new_chart.sounds.append(song)
		new_chart.bgm.append({"beat": 0.0, "sound": 0})
	new_chart.rebuildTiming()
	if new_chart.save() != OK:
		toast("COULD NOT CREATE THE CHART IN " + folder)
		return
	Loader.clear_song_catalog()
	open_chart(new_chart)
	toast("NOW SET THE BPM AND THE OFFSET WITH THE METRONOME (M), THEN SLICE THE SONG" if setup_audio != "" else "CHART CREATED: ADD KEYSOUNDS WITH THE + BUTTON")

# File name with only safe characters, the other BMS players may not read the others
static func safe_name(text: String) -> String:
	var result = ""
	for c in text:
		result += c if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c in "-_" else "_"
	result = result.strip_edges().trim_prefix("_").trim_suffix("_")
	return result if result != "" else "song"

static func unique_path(base: String, extension: String) -> String:
	var path = base + extension
	var k = 2
	while FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		path = "%s_%d%s" % [base, k, extension]
		k += 1
	return path

func open_new_difficulty() -> void:
	if chart == null:
		return
	difficulty_option.selected = clampi(chart.difficulty, 1, BmsChart.DIFFICULTIES.size() - 1) - 1
	difficulty_level.value = chart.playLevel
	difficulty_dialog.popup_centered()

func _on_new_difficulty() -> void:
	chart.difficulty = difficulty_option.selected + 1
	chart.playLevel = int(difficulty_level.value)
	chart.path = unique_path(chart.folder().path_join(chart.difficultyName().to_lower()), "." + chart.path.get_extension())
	if save_chart() == OK:
		toast("NOW EDITING %s (%s): DELETED NOTES STAY IN THE BGM" % [chart.difficultyName().to_upper(), chart.path.get_file()])
	refresh_all()

# Undo

func begin_change() -> void:
	undo_stack.append(chart.snapshot())
	if undo_stack.size() > UNDO_LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()

func end_change() -> void:
	dirty = true
	refresh_all()

func undo() -> void:
	if chart == null or undo_stack.is_empty():
		return
	redo_stack.append(chart.snapshot())
	chart.restore(undo_stack.pop_back())
	field.selection.clear()
	dirty = true
	refresh_all()
	toast("UNDO")

func redo() -> void:
	if chart == null or redo_stack.is_empty():
		return
	undo_stack.append(chart.snapshot())
	chart.restore(redo_stack.pop_back())
	field.selection.clear()
	dirty = true
	refresh_all()
	toast("REDO")

# Everything shown follows the chart
func refresh_all() -> void:
	if chart == null:
		return
	player.loadSounds()
	player.refresh()
	song_end = maxf(player.songLength(), chart.beatToTime(chart.lastBeat())) + 2.0
	level = QuaChart.densityLevel(chart.noteTimes())
	if listed_sounds != chart.sounds.size():
		rebuild_sound_list()
	song_title.text = chart.title if chart.title != "" else "(NO TITLE)"
	song_artist.text = chart.artist
	song_difficulty.text = "%s  LV.%d" % [chart.difficultyName().to_upper(), chart.playLevel]
	song_difficulty.add_theme_color_override("font_color", EditorUI.difficulty_color(chart.difficultyName()))
	song_file.text = chart.path.trim_prefix(SONGS_DIR + "/")
	bpm_spin.set_value_no_signal(chart.bpm)
	offset_spin.set_value_no_signal(offset_ms())
	seek_slider.max_value = song_end
	request_envelopes()
	rebuild_waveform()

func rebuild_sound_list() -> void:
	listed_sounds = chart.sounds.size()
	sound_list.clear()
	sound_list.add_item("AUTO (SOUND UNDER THE NOTE)")
	sound_list.set_item_custom_fg_color(0, EditorUI.YELLOW)
	for i in chart.sounds.size():
		sound_list.add_item("%s  %s" % [EditorChart.encodeId(i + 1, false), chart.sounds[i].get_file()])
		sound_list.set_item_tooltip(i + 1, chart.sounds[i])
	if current_sound >= chart.sounds.size():
		current_sound = -1
	sound_list.select(current_sound + 1)

func sound_name(sound: int) -> String:
	if sound < 0 or sound >= chart.sounds.size():
		return "NO KEYSOUND"
	return chart.sounds[sound]

func _on_sound_selected(index: int) -> void:
	current_sound = index - 1
	if current_sound >= 0:
		player.preview(current_sound)
		toast("NEW NOTES PLAY " + chart.sounds[current_sound])
	else:
		toast("AUTO: EACH NEW NOTE TAKES THE SOUND UNDER IT")

# Notes

# Sound of a new note: the BGM sound at its beat, the slice of a note of the same chord,
# or the slice playing there, cut in two. -1 if there is none.
func grab_sound(beat: float, automatic: bool) -> int:
	if not automatic:
		return current_sound
	var found = null
	for e in chart.bgm:
		if absf(e.beat - beat) < EditorChart.EPSILON and (found == null or chart.isSlice(e.sound) and not chart.isSlice(found.sound)):
			found = e
	if found != null:
		chart.bgm.erase(found)
		return found.sound
	for n in chart.notes:
		if absf(n.beat - beat) < EditorChart.EPSILON and chart.isSlice(n.sound):
			return n.sound
	return split_slice(beat)

# Cut the slice playing at a beat: what was before keeps the first part, the new note gets the second one
func split_slice(beat: float) -> int:
	var time = chart.beatToTime(beat)
	var owner_beat = -1.0
	var owner_time = -INF
	var sound = -1
	for list in [chart.bgm, chart.notes]:
		for o in list:
			if not chart.isSlice(o.sound):
				continue
			var start = chart.beatToTime(o.beat)
			var length = player.soundLength(o.sound) - AudioSlicer.TAIL
			if start < time - 0.005 and time < start + length - 0.005 and start > owner_time:
				owner_time = start
				owner_beat = o.beat
				sound = o.sound
	if sound == -1:
		return -1
	var file = chart.sounds[sound]
	var base = file.get_file().get_basename()
	if base.length() > 5 and base[-5] == "_" and base.right(4).is_valid_int():
		base = base.left(-5)
	var first = new_slice_file(base)
	var second = new_slice_file(base)
	var folder = chart.folder()
	if not AudioSlicer.splitWav(folder.path_join(file), time - owner_time, folder.path_join(first), folder.path_join(second)):
		return -1
	var first_sound = chart.addSound(first)
	for list in [chart.bgm, chart.notes]:
		for o in list:
			if o.sound == sound and absf(o.beat - owner_beat) < EditorChart.EPSILON:
				o.sound = first_sound
	player.loadSounds()
	return chart.addSound(second)

func new_slice_file(base: String) -> String:
	var file = "%s/%s_%04d.wav" % [EditorChart.SLICE_FOLDER, base, next_slice]
	next_slice += 1
	return file

# Slices are numbered after the ones already in the folder (other difficulties use them)
func find_next_slice() -> int:
	var number = 0
	var access = DirAccess.open(chart.folder().path_join(EditorChart.SLICE_FOLDER))
	if access != null:
		for file in access.get_files():
			var base = file.get_basename()
			if base.length() > 5 and base[-5] == "_" and base.right(4).is_valid_int():
				number = maxi(number, base.right(4).to_int())
	return number + 1

# A deleted or moved note gives its sound back to the BGM, unless another note of the chord keeps it
func release_sound(n: Dictionary) -> void:
	if n.sound < 0:
		return
	for o in chart.notes:
		if o.sound == n.sound and absf(o.beat - n.beat) < EditorChart.EPSILON:
			return
	for e in chart.bgm:
		if e.sound == n.sound and absf(e.beat - n.beat) < EditorChart.EPSILON:
			return
	chart.bgm.append({"beat": n.beat, "sound": n.sound})

func place_note(lane: int, beat: float, length: float) -> bool:
	if chart == null or lane >= chart.lanes() or beat < -EditorChart.EPSILON:
		return false
	beat = maxf(beat, 0.0)
	if not chart.laneFree(lane, beat, length):
		return false
	begin_change()
	var sound = grab_sound(beat, current_sound < 0)
	chart.notes.append({"lane": lane, "beat": beat, "length": length, "sound": sound})
	end_change()
	if not player.playing and sound >= 0:
		player.preview(sound)
	return true

func delete_notes(list: Array) -> void:
	if list.is_empty():
		return
	begin_change()
	for n in list:
		chart.notes.erase(n)
		field.selection.erase(n)
	for n in list:
		if keep_in_bgm:
			release_sound(n)
	end_change()

# Move notes by columns of lanes and beats. Moved in time, a slice stays at its place in the song:
# it goes back to the BGM and the note takes the sound of its new place.
func move_notes(list: Array, columns: int, beats: float) -> void:
	var order = field.order
	var targets = []
	for n in list:
		var column = order.find(n.lane) + columns
		if column < 0 or column >= order.size() or order[column] >= chart.lanes() or n.beat + beats < -EditorChart.EPSILON:
			toast("THE NOTES CANNOT GO THERE")
			return
		targets.append([order[column], maxf(n.beat + beats, 0.0)])
	for i in list.size():
		if not chart.laneFree(targets[i][0], targets[i][1], list[i].length, list):
			toast("ANOTHER NOTE IS IN THE WAY")
			return
	begin_change()
	var moved_slices = []
	for i in list.size():
		var n = list[i]
		if absf(beats) > EditorChart.EPSILON and chart.isSlice(n.sound):
			moved_slices.append({"beat": n.beat, "sound": n.sound})
			n.sound = -1
		n.lane = targets[i][0]
		n.beat = targets[i][1]
	for old in moved_slices:
		release_sound(old)
	for n in list:
		if n.sound == -1 and moved_slices.size() > 0:
			n.sound = grab_sound(n.beat, true)
	end_change()

func place_bgm(beat: float) -> void:
	if current_sound < 0:
		toast("CHOOSE A KEYSOUND IN THE LIST FIRST")
		return
	begin_change()
	chart.bgm.append({"beat": maxf(beat, 0.0), "sound": current_sound})
	end_change()
	player.preview(current_sound)

func delete_bgm(e: Dictionary) -> void:
	begin_change()
	chart.bgm.erase(e)
	end_change()

func preview_bgm(e: Dictionary) -> void:
	player.preview(e.sound)
	toast(sound_name(e.sound))

func preview_note(n: Dictionary) -> void:
	if not player.playing and n.sound >= 0:
		player.preview(n.sound)

func assign_sound() -> void:
	if chart == null or field.selection.is_empty():
		toast("SELECT NOTES FIRST (SELECT TOOL, F1)")
		return
	begin_change()
	for n in field.selection:
		if current_sound >= 0:
			n.sound = current_sound
		elif n.sound < 0:
			n.sound = grab_sound(n.beat, true)
	end_change()

func copy_selection() -> void:
	if field.selection.is_empty():
		return
	var first = INF
	for n in field.selection:
		first = minf(first, n.beat)
	clipboard = field.selection.map(func(n): return {"column": field.order.find(n.lane), "beat": n.beat - first, "length": n.length, "sound": n.sound})
	toast("%d NOTES COPIED" % clipboard.size())

func paste() -> void:
	if chart == null or clipboard.is_empty():
		return
	var start = snap_beat(cursor_beat)
	begin_change()
	field.selection.clear()
	for c in clipboard:
		if c.column >= field.order.size() or field.order[c.column] >= chart.lanes():
			continue
		var lane = field.order[c.column]
		var beat = start + c.beat
		if not chart.laneFree(lane, beat, c.length):
			continue
		var sound = c.sound
		if sound < 0 or chart.isSlice(sound):
			sound = grab_sound(beat, true)
		var n = {"lane": lane, "beat": beat, "length": c.length, "sound": sound}
		chart.notes.append(n)
		field.selection.append(n)
	end_change()

func mirror_selection() -> void:
	if field.selection.is_empty():
		return
	var targets = []
	for n in field.selection:
		var key = n.lane % EditorChart.SIDE_LANES
		targets.append(n.lane if key == EditorChart.SCRATCH_LANE else n.lane - key + 6 - key)
	for i in targets.size():
		if not chart.laneFree(targets[i], field.selection[i].beat, field.selection[i].length, field.selection):
			toast("ANOTHER NOTE IS IN THE WAY")
			return
	begin_change()
	for i in targets.size():
		field.selection[i].lane = targets[i]
	end_change()

# A key or the controller: a note at the cursor, or where the song is while it plays
func record(lane: int) -> void:
	if chart == null or busy:
		return
	if not chart.double:
		lane %= EditorChart.SIDE_LANES
	if player.playing:
		var beat = snap_beat(chart.timeToBeat(player.heardTime() - Global.audio_offset / 1000.0))
		if chart.laneFree(lane, beat, 0.0):
			place_note(lane, beat, 0.0)
		return
	var beat = snap_beat(cursor_beat)
	var n = chart.noteAt(lane, beat)
	if n != null:
		delete_notes([n])
	else:
		place_note(lane, beat, 0.0)

# Timing

func offset_ms() -> float:
	if not chart.measureLengths.has(0):
		return 0.0
	return chart.beatToTime(chart.measureBeat(1)) * 1000.0

func _on_bpm_changed(value: float) -> void:
	if chart == null or is_equal_approx(value, chart.bpm):
		return
	begin_change()
	chart.bpm = value
	if chart.measureLengths.has(0):
		# The offset stays the same time
		chart.measureLengths[0] = offset_spin.value / 1000.0 * value / 60.0 / 4.0
	chart.rebuildTiming()
	end_change()
	warn_slices()

# Measure 000 lasts until the first beat
func _on_offset_changed(value: float) -> void:
	if chart == null:
		return
	begin_change()
	if value < 0.5:
		chart.measureLengths.erase(0)
	else:
		chart.measureLengths[0] = value / 1000.0 * chart.bpmAt(0.0) / 60.0 / 4.0
	chart.rebuildTiming()
	end_change()
	warn_slices()

func warn_slices() -> void:
	for list in [chart.bgm, chart.notes]:
		for o in list:
			if chart.isSlice(o.sound):
				toast("THE SLICES WERE CUT ON THE OLD TEMPO: UNDO (CTRL+Z) TO KEEP THEM IN TIME")
				return

# BPM from the taps, 0 until there are enough of them
func tap() -> float:
	var now = Time.get_ticks_msec() / 1000.0
	if not taps.is_empty() and now - taps[-1] > TAP_RESET:
		taps.clear()
	taps.append(now)
	if taps.size() < TAPS_NEEDED:
		tap_label.text = "%d / %d" % [taps.size(), TAPS_NEEDED]
		return 0.0
	var bpm = snappedf(60.0 * (taps.size() - 1) / (taps[-1] - taps[0]), 0.01)
	tap_label.text = "%.2f" % bpm
	return bpm

func tap_bpm() -> void:
	var bpm = tap()
	if bpm > 0.0 and chart != null:
		bpm_spin.value = bpm

func open_timing_dialog(beat: float) -> void:
	timing_dialog_beat = maxf(beat, 0.0)
	var m = chart.measureAt(timing_dialog_beat)
	timing_label.text = "MEASURE %03d  BEAT %s" % [m, EditorChart.number(snappedf(timing_dialog_beat - chart.measureBeat(m) + 1, 0.001))]
	var change = find_at(chart.bpmChanges, timing_dialog_beat)
	var stop = find_at(chart.stops, timing_dialog_beat)
	timing_bpm.value = change.bpm if change != null else chart.bpm if timing_dialog_beat < EditorChart.EPSILON else chart.bpmAt(timing_dialog_beat)
	timing_stop.value = stop.length / 48.0 if stop != null else 0.0
	timing_delete.visible = change != null or stop != null
	timing_dialog.popup_centered()

static func find_at(list: Array, beat: float):
	for o in list:
		if absf(o.beat - beat) < EditorChart.EPSILON:
			return o
	return null

func _on_timing_confirmed() -> void:
	begin_change()
	var beat = timing_dialog_beat
	var change = find_at(chart.bpmChanges, beat)
	if beat < EditorChart.EPSILON and change == null:
		chart.bpm = timing_bpm.value
	elif change != null:
		change.bpm = timing_bpm.value
	elif not is_equal_approx(timing_bpm.value, chart.bpmAt(beat)):
		chart.bpmChanges.append({"beat": beat, "bpm": timing_bpm.value})
	var stop = find_at(chart.stops, beat)
	if stop != null:
		chart.stops.erase(stop)
	if timing_stop.value > 0.0:
		chart.stops.append({"beat": beat, "length": timing_stop.value * 48.0})
	chart.rebuildTiming()
	end_change()

func delete_timing() -> void:
	timing_dialog.hide()
	begin_change()
	for list in [chart.bpmChanges, chart.stops]:
		var found = find_at(list, timing_dialog_beat)
		if found != null:
			list.erase(found)
	chart.rebuildTiming()
	end_change()

func open_measure_dialog() -> void:
	if chart == null:
		return
	var m = chart.measureAt(cursor_beat)
	measure_label.text = "%03d" % m
	measure_spin.value = chart.measureLength(m)
	measure_dialog.popup_centered()

func _on_measure_confirmed() -> void:
	var m = chart.measureAt(cursor_beat)
	begin_change()
	if is_equal_approx(measure_spin.value, 1.0):
		chart.measureLengths.erase(m)
	else:
		chart.measureLengths[m] = measure_spin.value
	chart.rebuildTiming()
	end_change()

# Keysounds

func add_sound_files(files: PackedStringArray) -> void:
	if chart == null:
		return
	var folder = ProjectSettings.globalize_path(chart.folder()).trim_suffix("/") + "/"
	var added = 0
	begin_change()
	for file in files:
		if not file.get_extension().to_lower() in AUDIO_EXTENSIONS:
			continue
		var global = ProjectSettings.globalize_path(file)
		var name = ""
		if global.begins_with(folder):
			name = global.substr(folder.length())
		else:
			name = safe_name(file.get_file().get_basename()) + "." + file.get_extension().to_lower()
			if FileAccess.file_exists(chart.folder().path_join(name)) and not name in chart.sounds:
				name = unique_path(chart.folder().path_join(name.get_basename()), "." + name.get_extension()).get_file()
			if not FileAccess.file_exists(chart.folder().path_join(name)) and DirAccess.copy_absolute(file, chart.folder().path_join(name)) != OK:
				continue
		current_sound = chart.addSound(name)
		added += 1
	end_change()
	rebuild_sound_list()
	toast("%d KEYSOUNDS ADDED: CHOOSE ONE AND PLACE IT WITH THE NOTE OR BGM TOOL" % added)

# Long sounds of the BGM: the songs that can be cut
func song_sources() -> Array:
	var sources = []
	for e in chart.bgm:
		if not chart.isSlice(e.sound) and player.soundLength(e.sound) >= SONG_MIN_LENGTH:
			sources.append(e)
	sources.sort_custom(func(a, b): return player.soundLength(a.sound) > player.soundLength(b.sound))
	return sources

func open_slice_dialog() -> void:
	if chart == null or busy:
		return
	slice_sources = song_sources()
	if slice_sources.is_empty():
		toast("NO SONG TO SLICE IN THE BGM: MAKE A NEW CHART FROM A SONG FILE, OR ADD IT AND PLACE IT IN THE BGM")
		return
	slice_source.clear()
	for e in slice_sources:
		slice_source.add_item("%s  (MEASURE %03d)" % [chart.sounds[e.sound], chart.measureAt(e.beat)])
	slice_dialog.popup_centered()

func _on_slice_confirmed() -> void:
	start_slice(slice_sources[slice_source.selected], SLICE_STEPS[slice_step.selected][1])

# Cut a song of the BGM on the beat grid and on the notes already placed, in a thread
func start_slice(e: Dictionary, step: float) -> void:
	var sound = e.sound
	var length = player.soundLength(sound)
	var start_time = chart.beatToTime(e.beat)
	var end_beat = chart.timeToBeat(start_time + length)
	var beats = [e.beat]
	var m = chart.measureAt(e.beat)
	while chart.measureBeat(m) < end_beat:
		var measure_end = chart.measureBeat(m + 1)
		var beat = chart.measureBeat(m)
		while beat < measure_end - EditorChart.EPSILON:
			if beat > e.beat + EditorChart.EPSILON and beat < end_beat - EditorChart.EPSILON:
				beats.append(beat)
			if step <= 0.0:
				break
			beat += step
		m += 1
	for n in chart.notes:
		if (n.sound == -1 or n.sound == sound) and n.beat > e.beat + EditorChart.EPSILON and n.beat < end_beat - EditorChart.EPSILON:
			beats.append(n.beat)
	beats.sort()
	var cuts = []
	for beat in beats:
		if cuts.is_empty() or beat - cuts[-1] > EditorChart.EPSILON:
			cuts.append(beat)
	var base = safe_name(chart.sounds[sound].get_file().get_basename())
	slice_job = {
		"event": e, "sound": sound, "beats": cuts, "stream": player.stream(sound), "folder": chart.folder(),
		"offsets": cuts.map(func(b): return chart.beatToTime(b) - start_time),
		"files": cuts.map(func(_b): return new_slice_file(base)),
		"envelopes": {}, "count": 0,
	}
	DirAccess.make_dir_recursive_absolute(chart.folder().path_join(EditorChart.SLICE_FOLDER))
	player.stop()
	busy = true
	slice_progress = 0.0
	progress_label.text = "SLICING %s INTO %d KEYSOUNDS..." % [chart.sounds[sound].get_file(), cuts.size()]
	progress_panel.show()
	slice_task = WorkerThreadPool.add_task(run_slice)

func run_slice() -> void:
	var frames = AudioSlicer.decode(slice_job["stream"])
	var rate = AudioSlicer.mixRate()
	var offsets = slice_job["offsets"]
	var tail = int(AudioSlicer.TAIL * rate)
	for i in offsets.size():
		var from = int(offsets[i] * rate)
		var to = int(offsets[i + 1] * rate) if i + 1 < offsets.size() else frames.size()
		to = mini(to, frames.size())
		if from >= to:
			break
		var file = slice_job["files"][i]
		if AudioSlicer.writeSlice(frames, from, to, slice_job["folder"].path_join(file), i > 0) != OK:
			break
		slice_job["envelopes"][file] = AudioSlicer.envelope(frames, from, mini(to + tail, frames.size()))
		slice_job["count"] = i + 1
		slice_progress = float(i + 1) / offsets.size()

func finish_slice() -> void:
	busy = false
	progress_panel.hide()
	var count = slice_job["count"]
	if count == 0:
		toast("COULD NOT SLICE THE SONG")
		return
	begin_change()
	chart.bgm.erase(slice_job["event"])
	for i in count:
		var index = chart.addSound(slice_job["files"][i])
		var beat = slice_job["beats"][i]
		var taken = false
		for n in chart.notes:
			if absf(n.beat - beat) < EditorChart.EPSILON and (n.sound == -1 or n.sound == slice_job["sound"]):
				n.sound = index
				taken = true
		if not taken:
			chart.bgm.append({"beat": beat, "sound": index})
	envelopes.merge(slice_job["envelopes"], true)
	current_sound = -1
	end_change()
	toast("%d KEYSOUNDS CUT: PLACE THE NOTES, EACH ONE TAKES THE SOUND UNDER IT" % count)

# Waveform

# Envelopes of the sounds placed, computed in a thread
func request_envelopes() -> void:
	if envelope_task != -1:
		return
	envelope_jobs = []
	var seen = {}
	for list in [chart.bgm, chart.notes]:
		for o in list:
			if o.sound < 0 or seen.has(o.sound):
				continue
			seen[o.sound] = true
			var file = chart.sounds[o.sound]
			var stream = player.stream(o.sound)
			if not envelopes.has(file) and stream != null:
				envelope_jobs.append([file, stream])
	if envelope_jobs.is_empty():
		return
	envelope_results = {}
	envelope_task = WorkerThreadPool.add_task(func():
		for job in envelope_jobs:
			envelope_results[job[0]] = AudioSlicer.envelope(AudioSlicer.decode(job[1])))

func rebuild_waveform() -> void:
	var bins = PackedFloat32Array()
	bins.resize(int(song_end * AudioSlicer.ENVELOPE_RATE) + 1)
	for list in [chart.bgm, chart.notes]:
		for o in list:
			if o.sound < 0:
				continue
			var envelope = envelopes.get(chart.sounds[o.sound])
			if envelope == null:
				continue
			var start = int(chart.beatToTime(o.beat) * AudioSlicer.ENVELOPE_RATE)
			for i in mini(envelope.size(), bins.size() - start):
				if start + i >= 0:
					bins[start + i] = maxf(bins[start + i], envelope[i])
	waveform = bins

# Navigation

func snap() -> int:
	return SNAPS[snap_index]

# Nearest line of the beat snap, the lines start again at each measure
func snap_beat(beat: float) -> float:
	if chart == null:
		return beat
	beat = maxf(beat, 0.0)
	var m = chart.measureAt(beat)
	var start = chart.measureBeat(m)
	var step = 1.0 / snap()
	var snapped = start + roundf((beat - start) / step) * step
	return minf(snapped, chart.measureBeat(m + 1))

# Next line of the beat snap after (1) or before (-1) a beat
func next_snap(beat: float, direction: int) -> float:
	var step = 1.0 / snap()
	var m = chart.measureAt(beat)
	var start = chart.measureBeat(m)
	if direction > 0:
		var k = floorf((beat - start) / step + EditorChart.EPSILON) + 1
		return minf(start + k * step, chart.measureBeat(m + 1))
	if beat <= start + EditorChart.EPSILON:
		if m == 0:
			return 0.0
		m -= 1
		start = chart.measureBeat(m)
	var k = ceilf((beat - start) / step - EditorChart.EPSILON) - 1
	return maxf(start + k * step, 0.0)

func seek_beat(beat: float) -> void:
	if chart == null:
		return
	cursor_beat = clampf(beat, 0.0, chart.timeToBeat(song_end))
	if player.playing:
		player.play_from(chart.beatToTime(cursor_beat), SPEEDS[speed_index])

func move_cursor(direction: int, measure: bool) -> void:
	if chart == null:
		return
	if measure:
		var m = chart.measureAt(cursor_beat + EditorChart.EPSILON)
		var start = chart.measureBeat(m)
		seek_beat(chart.measureBeat(m + 1) if direction > 0 else start if cursor_beat > start + EditorChart.EPSILON else chart.measureBeat(m - 1))
	else:
		seek_beat(next_snap(cursor_beat, direction))

func wheel(direction: int, ctrl: bool, shift: bool, alt: bool) -> void:
	if ctrl:
		change_snap(direction)
	elif alt:
		change_zoom(direction)
	else:
		move_cursor(direction, shift)

func change_snap(step: int) -> void:
	snap_index = clampi(snap_index + step, 0, SNAPS.size() - 1)

func change_zoom(step: int) -> void:
	zoom = clampf(zoom * pow(ZOOM_STEP, step), ZOOM_MIN, ZOOM_MAX)

func set_tool(index: int) -> void:
	tool = index
	field.drag = EditorField.Drag.NONE
	update_tools()

func update_tools() -> void:
	for i in tool_buttons.size():
		tool_buttons[i].set_pressed_no_signal(i == tool)
	metronome_button.set_pressed_no_signal(player.metronome)
	hitsound_button.set_pressed_no_signal(player.hitsounds)
	menus["AUDIO"].set_item_checked(menus["AUDIO"].get_item_index(Menu.METRONOME), player.metronome)
	menus["AUDIO"].set_item_checked(menus["AUDIO"].get_item_index(Menu.HITSOUNDS), player.hitsounds)
	menus["VIEW"].set_item_checked(menus["VIEW"].get_item_index(Menu.WAVEFORM), show_waveform)
	for i in SPEEDS.size():
		menus["AUDIO"].set_item_checked(menus["AUDIO"].get_item_index(Menu.SPEED + i), i == speed_index)
	speed_button.text = "x%.2f" % SPEEDS[speed_index]

func set_metronome(on: bool) -> void:
	player.metronome = on
	update_tools()

func set_hitsounds(on: bool) -> void:
	player.hitsounds = on
	update_tools()

func set_speed(index: int) -> void:
	speed_index = index
	if player.playing:
		player.play_from(player.position(), SPEEDS[speed_index])
	update_tools()

# Playback

func toggle_play() -> void:
	if chart == null or busy:
		return
	if player.playing:
		player.stop()
		play_button.icon = EditorUI.icon("play")
		return
	play_start_beat = cursor_beat
	player.play_from(chart.beatToTime(cursor_beat), SPEEDS[speed_index])
	play_button.icon = EditorUI.icon("pause")

func stop_playback() -> void:
	if chart == null:
		return
	if player.playing:
		player.stop()
		cursor_beat = play_start_beat
	else:
		cursor_beat = 0.0
	play_button.icon = EditorUI.icon("play")

func _process(_delta: float) -> void:
	if toast_panel.visible:
		toast_panel.modulate.a = clampf((toast_until - Time.get_ticks_msec()) / 500.0, 0.0, 1.0)
		toast_panel.visible = Time.get_ticks_msec() < toast_until
	if slice_task != -1:
		progress_bar.value = slice_progress
		if WorkerThreadPool.is_task_completed(slice_task):
			WorkerThreadPool.wait_for_task_completion(slice_task)
			slice_task = -1
			finish_slice()
	if envelope_task != -1 and WorkerThreadPool.is_task_completed(envelope_task):
		WorkerThreadPool.wait_for_task_completion(envelope_task)
		envelope_task = -1
		envelopes.merge(envelope_results, true)
		if chart != null:
			rebuild_waveform()
			request_envelopes()
	if chart == null:
		return
	if player.playing:
		cursor_beat = chart.timeToBeat(player.heardTime())
		if player.position() > song_end:
			player.stop()
			play_button.icon = EditorUI.icon("play")
	poll_controller()
	update_details()

func update_details() -> void:
	var time = chart.beatToTime(cursor_beat)
	time_label.text = EditorUI.time_text(time)
	remain_label.text = EditorUI.time_text(time - song_end)
	seek_slider.set_value_no_signal(time)
	var keys = chart.notes.filter(func(n): return n.lane < chart.lanes()).size()
	details["notes"].text = str(keys)
	details["bgm"].text = str(chart.bgm.size())
	details["level"].text = "%d / %d" % [level, QuaChart.MAX_LEVEL]
	details["bpm"].text = EditorChart.number(snappedf(chart.bpmAt(cursor_beat), 0.01))
	var m = chart.measureAt(cursor_beat)
	details["position"].text = "%03d : %s" % [m, EditorChart.number(snappedf(cursor_beat - chart.measureBeat(m) + 1, 0.01))]
	details["speed"].text = "x%.2f" % SPEEDS[speed_index]
	details["snap"].text = "1/%d" % snap()

# Notes from the controller, while nothing else uses the keys
func poll_controller() -> void:
	if busy or get_viewport().gui_get_focus_owner() is LineEdit or has_dialog():
		return
	for player_index in [1, 2]:
		var side = EditorChart.SIDE_LANES if player_index == 2 else 0
		var prefix = "p%d_" % player_index
		for key in 7:
			if Input.is_action_just_pressed(prefix + "key%d" % (key + 1)):
				record(side + key)
		var scratch = Input.is_action_just_pressed(prefix + "digital_turntable_fwd") or Input.is_action_just_pressed(prefix + "digital_turntable_rew")
		var analog = Input.get_action_strength(prefix + "analog_turntable_fwd") - Input.get_action_strength(prefix + "analog_turntable_rew")
		var motion = absf(wrapf(analog - analog_previous[player_index - 1], -1.0, 1.0))
		analog_previous[player_index - 1] = analog
		if motion > ANALOG_SCRATCH and Time.get_ticks_msec() - last_scratch[player_index - 1] > SCRATCH_REPEAT_MSEC:
			scratch = true
		if scratch:
			last_scratch[player_index - 1] = Time.get_ticks_msec()
			record(side + EditorChart.SCRATCH_LANE)
		if Input.is_action_just_pressed(prefix + "start"):
			toggle_play()

func has_dialog() -> bool:
	for window in [setup_dialog, difficulty_dialog, timing_dialog, measure_dialog, slice_dialog, confirm_dialog, help_dialog, open_dialog, audio_dialog, sounds_dialog]:
		if window.visible:
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or busy:
		return
	if event.ctrl_pressed or event.meta_pressed:
		return
	var handled = true
	match event.keycode:
		KEY_ESCAPE:
			if field.drag != EditorField.Drag.NONE:
				field.drag = EditorField.Drag.NONE
			elif not field.selection.is_empty():
				field.selection.clear()
			else:
				leave()
		KEY_F1, KEY_F2, KEY_F3, KEY_F4:
			if not event.shift_pressed:
				set_tool(event.keycode - KEY_F1)
		KEY_UP:
			move_cursor(1, event.shift_pressed)
		KEY_DOWN:
			move_cursor(-1, event.shift_pressed)
		KEY_PAGEUP:
			move_cursor(1, true)
		KEY_PAGEDOWN:
			move_cursor(-1, true)
		KEY_PLUS, KEY_KP_ADD:
			change_zoom(1)
		KEY_KP_SUBTRACT:
			change_zoom(-1)
		KEY_T:
			tap_bpm()
		_:
			if RECORD_KEYS.has(event.keycode) and not event.echo:
				record(RECORD_KEYS[event.keycode])
			else:
				handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _on_menu(id: int) -> void:
	if busy:
		return
	if id >= Menu.SPEED and id < Menu.SPEED + SPEEDS.size():
		set_speed(id - Menu.SPEED)
		return
	match id:
		Menu.NEW: guard(open_setup.bind(true))
		Menu.OPEN: open_dialog.popup_centered_ratio(0.7)
		Menu.GUIDE: show_help()
		Menu.EXIT: leave()
		Menu.ZOOM_IN: change_zoom(1)
		Menu.ZOOM_OUT: change_zoom(-1)
		Menu.WAVEFORM:
			show_waveform = not show_waveform
			update_tools()
		Menu.METRONOME: set_metronome(not player.metronome)
		Menu.HITSOUNDS: set_hitsounds(not player.hitsounds)
	if chart == null:
		return
	match id:
		Menu.SAVE: save_chart()
		Menu.SAVE_DIFFICULTY: open_new_difficulty()
		Menu.SETUP: open_setup(false)
		Menu.TEST: test_play()
		Menu.FOLDER: open_folder()
		Menu.UNDO: undo()
		Menu.REDO: redo()
		Menu.CUT:
			copy_selection()
			delete_notes(field.selection.duplicate())
		Menu.COPY: copy_selection()
		Menu.PASTE: paste()
		Menu.DELETE: delete_notes(field.selection.duplicate())
		Menu.SELECT_ALL:
			field.selection = chart.notes.filter(func(n): return n.lane < chart.lanes())
			set_tool(Tool.SELECT)
		Menu.MIRROR: mirror_selection()
		Menu.MEASURE: open_measure_dialog()
		Menu.GO_START: seek_beat(0.0)
		Menu.GO_END: seek_beat(chart.lastBeat())
		Menu.PLAY: toggle_play()
		Menu.SLICE: open_slice_dialog()
		Menu.ADD_SOUNDS: sounds_dialog.popup_centered_ratio(0.7)

func show_help() -> void:
	help_dialog.popup_centered()

func toast(text: String) -> void:
	toast_label.text = text
	toast_panel.show()
	toast_panel.reset_size()
	toast_panel.offset_left = -toast_panel.size.x / 2
	toast_panel.offset_right = toast_panel.size.x / 2
	toast_until = Time.get_ticks_msec() + int(TOAST_TIME * 1000)
