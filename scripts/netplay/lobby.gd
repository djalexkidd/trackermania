extends Control

# Netplay lobby. Without a room: the DJ name, the rooms found on the LAN, host a room or join one by address.
# In a room: the song chosen by the host, the DJs with their state, the chat, READY and START.
# The controller works like in the music select: turntable to move, white keys to confirm,
# black keys to go back, START held for the game options like in the music select.

const ANALOG_STEP = 0.08
const OPTIONS_SLIDE_TIME = 0.15
const STATE_NAMES = {"lobby": "LOBBY", "loading": "LOADING", "playing": "PLAYING"}

var browser: Control
var room_view: Control
# Browser
var name_edit: LineEdit
var room_list: VBoxContainer
var no_room_label: Label
var address_edit: LineEdit
var status_label: Label
var host_button: Button
var join_button: Button
var back_button: Button
# Room
var room_title: Label
var room_address: Label
var song_title: Label
var song_artist: Label
var song_difficulty: Label
var song_level: Label
var song_type: Label
var song_status: Label
var download_bar: ProgressBar
var player_count: Label
var player_grid: GridContainer
var chat_log: RichTextLabel
var chat_edit: LineEdit
var select_button: Button
var ready_button: Button
var start_button: Button
var leave_button: Button
var room_hint: Label

var analog_previous := 0.0
var analog_remainder := 0.0
var blink := 0.0
# OPTION SETTING panel of P1, over the right column
var options_x := 0.0
var options_tween: Tween

func _ready() -> void:
	# BGM disabled for now
	#if Global.custom_music_select_bgm != "":
	#	$BGM.stream = AudioStreamOggVorbis.load_from_file(Global.custom_music_select_bgm)
	#$BGM.play()
	build_browser()
	build_room()
	# The panel goes over the views built above
	move_child($GameOptionSettings, -1)
	options_x = $GameOptionSettings.position.x
	Netplay.opened.connect(show_view)
	Netplay.closed.connect(_on_closed)
	Netplay.players_changed.connect(refresh_room)
	Netplay.room_changed.connect(refresh_room)
	Netplay.chat_received.connect(_on_chat)
	Netplay.rooms_changed.connect(refresh_rooms)
	if Netplay.active:
		Netplay.update_me({"where": "lobby", "ready": false})
	elif Netplay.last_reason != "":
		set_status(Netplay.last_reason, NetplayUI.ERROR)
	if not Netplay.supported():
		set_status("Netplay is not available in the web version", NetplayUI.ERROR)
	analog_previous = analog_value()
	show_view()

func _exit_tree() -> void:
	if not Netplay.active:
		Netplay.stop_discovery()

#region Building

func content_box() -> HBoxContainer:
	var box = HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 32
	box.offset_right = -32
	box.offset_top = 124
	box.offset_bottom = -104
	box.add_theme_constant_override("separation", 28)
	return box

func column(stretch: float) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = stretch
	box.add_theme_constant_override("separation", 10)
	return box

func bottom_buttons(view: Control) -> HBoxContainer:
	var box = HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 32
	box.offset_right = -32
	box.offset_top = -66
	box.offset_bottom = -22
	box.add_theme_constant_override("separation", 18)
	view.add_child(box)
	return box

func build_browser() -> void:
	browser = Control.new()
	browser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	browser.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(browser)
	var content = content_box()
	browser.add_child(content)

	var left = column(1.4)
	content.add_child(left)
	left.add_child(NetplayUI.heading("DJ NAME"))
	name_edit = NetplayUI.line_edit("DJ NAME")
	name_edit.max_length = Netplay.NAME_LENGTH
	name_edit.text = Netplay.dj_name
	name_edit.add_theme_font_override("font", NetplayUI.TITLE_FONT)
	name_edit.add_theme_font_size_override("font_size", 28)
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.text_submitted.connect(func(_text): name_edit.unedit())
	left.add_child(name_edit)
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	left.add_child(gap)
	left.add_child(NetplayUI.heading("ROOMS ON THE LAN"))
	var rooms_panel = NetplayUI.panel()
	rooms_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(rooms_panel)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rooms_panel.add_child(scroll)
	room_list = VBoxContainer.new()
	room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_list.add_theme_constant_override("separation", 10)
	scroll.add_child(room_list)
	no_room_label = NetplayUI.label("", NetplayUI.TEXT_FONT, 24, NetplayUI.DIM)
	no_room_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	no_room_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_list.add_child(no_room_label)

	var right = column(1.0)
	content.add_child(right)
	right.add_child(NetplayUI.heading("HOST", NetplayUI.WARNING))
	var host_text = NetplayUI.label("Open a room on this machine. Players on the LAN see it in their list, the others join with your address.", NetplayUI.TEXT_FONT, 20, NetplayUI.DIM)
	host_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(host_text)
	host_button = NetplayUI.button("HOST A ROOM", NetplayUI.WARNING)
	host_button.pressed.connect(_on_host_pressed)
	right.add_child(host_button)
	var gap2 = Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	right.add_child(gap2)
	right.add_child(NetplayUI.heading("JOIN BY ADDRESS"))
	address_edit = NetplayUI.line_edit("192.168.1.10")
	address_edit.text = Netplay.last_address
	address_edit.text_submitted.connect(func(_text): _on_join_pressed())
	right.add_child(address_edit)
	join_button = NetplayUI.button("JOIN")
	join_button.pressed.connect(_on_join_pressed)
	right.add_child(join_button)
	status_label = NetplayUI.label("", NetplayUI.TEXT_FONT, 22, NetplayUI.ERROR)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(status_label)

	var buttons = bottom_buttons(browser)
	back_button = NetplayUI.button("BACK", NetplayUI.DIM, 160)
	back_button.pressed.connect(go_back)
	buttons.add_child(back_button)
	buttons.add_child(hint())

func hint() -> Label:
	var label = NetplayUI.label("", NetplayUI.TEXT_FONT, 20, NetplayUI.DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "TURNTABLE: MOVE   WHITE KEYS: OK   BLACK KEYS: BACK"
	return label

func build_room() -> void:
	room_view = Control.new()
	room_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room_view)
	var content = content_box()
	room_view.add_child(content)

	var left = column(1.45)
	content.add_child(left)
	left.add_child(NetplayUI.heading("MUSIC"))
	var song_panel = NetplayUI.panel()
	left.add_child(song_panel)
	var song_box = VBoxContainer.new()
	song_box.add_theme_constant_override("separation", 2)
	song_panel.add_child(song_box)
	song_title = NetplayUI.label("", NetplayUI.NAME_FONT, 40)
	song_title.clip_text = true
	song_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	song_box.add_child(song_title)
	song_artist = NetplayUI.label("", NetplayUI.NAME_FONT, 24, NetplayUI.DIM)
	song_artist.clip_text = true
	song_artist.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	song_box.add_child(song_artist)
	var song_line = HBoxContainer.new()
	song_line.add_theme_constant_override("separation", 18)
	song_box.add_child(song_line)
	song_difficulty = NetplayUI.label("", NetplayUI.TITLE_FONT, 24)
	song_line.add_child(song_difficulty)
	song_level = NetplayUI.label("", NetplayUI.TITLE_FONT, 24)
	song_line.add_child(song_level)
	song_type = NetplayUI.label("", NetplayUI.TITLE_FONT, 16, NetplayUI.DIM)
	song_type.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	song_line.add_child(song_type)
	song_status = NetplayUI.label("", NetplayUI.TITLE_FONT, 16, NetplayUI.WARNING)
	song_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	song_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	song_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	song_line.add_child(song_status)
	download_bar = NetplayUI.progress_bar()
	song_box.add_child(download_bar)

	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	left.add_child(gap)
	var djs_heading = NetplayUI.heading("DJS")
	player_count = NetplayUI.label("", NetplayUI.TITLE_FONT, 20, NetplayUI.DIM)
	djs_heading.add_child(player_count)
	left.add_child(djs_heading)
	player_grid = GridContainer.new()
	player_grid.columns = 2
	player_grid.add_theme_constant_override("h_separation", 16)
	player_grid.add_theme_constant_override("v_separation", 10)
	left.add_child(player_grid)

	var right = column(1.0)
	content.add_child(right)
	right.add_child(NetplayUI.heading("ROOM", NetplayUI.WARNING))
	room_title = NetplayUI.label("", NetplayUI.TITLE_FONT, 24)
	room_title.clip_text = true
	right.add_child(room_title)
	room_address = NetplayUI.label("", NetplayUI.TEXT_FONT, 20, NetplayUI.DIM)
	room_address.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(room_address)
	right.add_child(NetplayUI.heading("CHAT"))
	var chat_panel = NetplayUI.panel()
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(chat_panel)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.focus_mode = Control.FOCUS_NONE
	chat_log.add_theme_font_override("normal_font", NetplayUI.TEXT_FONT)
	chat_log.add_theme_font_size_override("normal_font_size", 20)
	chat_panel.add_child(chat_log)
	chat_edit = NetplayUI.line_edit("Message… (Enter)")
	chat_edit.max_length = 200
	chat_edit.keep_editing_on_text_submit = true
	chat_edit.text_submitted.connect(_on_chat_submitted)
	right.add_child(chat_edit)

	var buttons = bottom_buttons(room_view)
	select_button = NetplayUI.button("MUSIC SELECT", NetplayUI.ACCENT, 210)
	select_button.pressed.connect(_on_select_pressed)
	ready_button = NetplayUI.button("READY", NetplayUI.READY, 170)
	ready_button.pressed.connect(toggle_ready)
	start_button = NetplayUI.button("START", NetplayUI.WARNING, 150)
	start_button.pressed.connect(Netplay.start_round)
	leave_button = NetplayUI.button("LEAVE", NetplayUI.DIM, 150)
	leave_button.pressed.connect(go_back)
	for button in [select_button, ready_button, start_button, leave_button]:
		buttons.add_child(button)
	room_hint = hint()
	buttons.add_child(room_hint)

#endregion

#region Views

func show_view() -> void:
	if not Netplay.active and $GameOptionSettings.open:
		close_game_options()
	browser.visible = not Netplay.active
	room_view.visible = Netplay.active
	if Netplay.active:
		Netplay.stop_discovery()
		chat_log.clear()
		for entry in Netplay.chat:
			_on_chat(entry)
		refresh_room()
		$TitleLabel.text = "netplay room"
		(ready_button if not Netplay.is_host else select_button).grab_focus()
	else:
		Netplay.start_discovery()
		refresh_rooms()
		$TitleLabel.text = "netplay"
		host_button.disabled = not Netplay.supported()
		join_button.disabled = not Netplay.supported()
		host_button.grab_focus()

func set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)

func _on_closed(reason: String) -> void:
	set_status(reason, NetplayUI.ERROR)
	show_view()

func refresh_rooms() -> void:
	if not browser.visible:
		return
	var focused = get_viewport().gui_get_focus_owner()
	var focused_key = focused.get_meta("room", "") if focused != null and focused.has_meta("room") else ""
	for child in room_list.get_children():
		if child != no_room_label:
			child.queue_free()
	no_room_label.visible = Netplay.rooms.is_empty()
	if Netplay.listener == null:
		no_room_label.text = "The LAN search is used by another game on this machine. Join by address."
	else:
		no_room_label.text = "Searching for rooms" + ".".repeat(1 + int(blink * 2) % 3)
	for key in Netplay.rooms:
		var info = Netplay.rooms[key]
		var button = room_button(key, info)
		room_list.add_child(button)
		if key == focused_key:
			button.grab_focus.call_deferred()

func room_button(key: String, info: Dictionary) -> Button:
	var button = NetplayUI.button("", NetplayUI.ACCENT)
	button.custom_minimum_size = Vector2(0, 68)
	button.set_meta("room", key)
	var full = info["players"] >= info["max"]
	var other_version = info["protocol"] != Netplay.PROTOCOL
	button.disabled = full or other_version
	button.pressed.connect(func(): join_address("%s:%d" % [info["address"], info["port"]]))
	var box = HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 26
	box.offset_right = -26
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 16)
	button.add_child(box)
	var names = VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(names)
	var room_name = NetplayUI.label(info["name"], NetplayUI.TITLE_FONT, 22)
	room_name.clip_text = true
	names.add_child(room_name)
	var detail = info["address"]
	if info["song"] != "":
		detail += "  ♪ " + info["song"]
	var detail_label = NetplayUI.label(detail, NetplayUI.TEXT_FONT, 18, NetplayUI.DIM)
	detail_label.clip_text = true
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(detail_label)
	var state = "OTHER VERSION" if other_version else ("FULL" if full else STATE_NAMES.get(info["state"], ""))
	var state_label = NetplayUI.label(state, NetplayUI.TITLE_FONT, 16, NetplayUI.READY if state == "LOBBY" else NetplayUI.WARNING)
	state_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(state_label)
	var count = NetplayUI.label("%d/%d" % [info["players"], info["max"]], NetplayUI.TITLE_FONT, 24)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(count)
	return button

func refresh_room() -> void:
	if not room_view.visible:
		return
	var room = Netplay.room
	room_title.text = room.get("name", "")
	if Netplay.is_host:
		var addresses = Netplay.local_addresses()
		room_address.text = "Address: %s  (port %d)" % [", ".join(addresses) if addresses else "127.0.0.1", Netplay.PORT]
	else:
		room_address.text = "Host: " + Netplay.last_address
	refresh_song()
	refresh_players()
	refresh_buttons()

func refresh_song() -> void:
	var song = Netplay.room.get("song", {})
	download_bar.hide()
	if song.is_empty():
		song_title.text = "NO SONG"
		song_artist.text = "The host selects the song" if not Netplay.is_host else "Choose a song in MUSIC SELECT"
		song_difficulty.text = ""
		song_level.text = ""
		song_type.text = ""
		song_status.text = ""
		return
	song_title.text = song["title"]
	song_artist.text = song["artist"]
	song_difficulty.text = song["difficulty"].to_upper()
	song_difficulty.add_theme_color_override("font_color", NetplayUI.difficulty_color(song["difficulty"]))
	song_level.text = "LV.%d" % song["level"]
	song_type.text = song["type"]
	var state = Netplay.me().get("song_state", "ok")
	if Netplay.room.get("state") != "lobby":
		song_status.text = "ROUND IN PROGRESS"
		song_status.add_theme_color_override("font_color", NetplayUI.WARNING)
	elif state == "downloading":
		song_status.text = "DOWNLOADING"
		song_status.add_theme_color_override("font_color", NetplayUI.WARNING)
		download_bar.show()
	elif state == "missing" or not Netplay.has_song():
		song_status.text = "NOT AVAILABLE"
		song_status.add_theme_color_override("font_color", NetplayUI.ERROR)
	else:
		song_status.text = "OK"
		song_status.add_theme_color_override("font_color", NetplayUI.READY)

func refresh_players() -> void:
	for child in player_grid.get_children():
		child.queue_free()
	var ids = Netplay.players.keys()
	ids.sort_custom(func(a, b): return Netplay.players[a]["slot"] < Netplay.players[b]["slot"])
	for id in ids:
		player_grid.add_child(player_card(id, Netplay.players[id]))
	player_count.text = "%d/%d" % [ids.size(), Netplay.MAX_PLAYERS]

func player_card(id: int, player: Dictionary) -> PanelContainer:
	var color = Netplay.color_of(id)
	var mine = id == Netplay.my_id()
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 64)
	card.add_theme_stylebox_override("panel", NetplayUI.panel_style(color if mine else Color(color, 0.55), NetplayUI.SKEW,
		Color(color.darkened(0.7), 0.9) if mine else NetplayUI.PANEL, 3 if mine else 2))
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var slot = NetplayUI.label("%dP" % (player["slot"] + 1), NetplayUI.TITLE_FONT, 20, color)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(slot)
	if id == 1:
		var crown = TextureRect.new()
		crown.texture = preload("res://scenes/netplay/img/crown.png")
		crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crown.custom_minimum_size = Vector2(22, 22)
		crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(crown)
	# Name above, state under it
	var lines = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 2)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(lines)
	var dj = NetplayUI.label(player["name"], NetplayUI.TITLE_FONT, 20)
	dj.clip_text = true
	lines.add_child(dj)
	var status = player_status(id, player)
	lines.add_child(NetplayUI.label(status[0], NetplayUI.TITLE_FONT, 14, status[1]))
	if id != Netplay.my_id() and player["ping"] > 0:
		var ping = NetplayUI.label("%dms" % player["ping"], NetplayUI.TEXT_FONT, 16, NetplayUI.DIM)
		ping.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(ping)
	return card

# [text, color] of a player's state
func player_status(id: int, player: Dictionary) -> Array:
	match player["where"]:
		"game":
			return ["PLAYING", NetplayUI.ACCENT]
		"result":
			return ["RESULT", Color(0.75, 0.35, 1)]
		"select":
			return ["MUSIC SELECT", NetplayUI.WARNING]
	match player["song_state"]:
		"downloading":
			return ["DOWNLOAD %d%%" % int(player["progress"] * 100), NetplayUI.WARNING]
		"missing":
			return ["NO SONG", NetplayUI.ERROR]
	if id == 1:
		return ["HOST", NetplayUI.WARNING]
	if player["ready"]:
		return ["READY", NetplayUI.READY]
	return ["NOT READY", NetplayUI.DIM]

func refresh_buttons() -> void:
	var me = Netplay.me()
	var in_lobby = Netplay.room.get("state") == "lobby"
	select_button.text = "MUSIC SELECT" if Netplay.is_host else "SUGGEST"
	select_button.disabled = Netplay.is_host and not in_lobby
	ready_button.visible = not Netplay.is_host
	ready_button.disabled = not Netplay.has_song() or me.get("song_state") != "ok"
	ready_button.text = "CANCEL" if me.get("ready", false) else "READY"
	start_button.visible = Netplay.is_host
	start_button.disabled = not Netplay.can_start()
	room_hint.text = "HOLD START: OPTIONS   BLACK KEYS: LEAVE"

func _on_chat(entry: Dictionary) -> void:
	if not room_view.visible:
		return
	if entry["name"] == "":
		chat_log.append_text("[color=#8c9bb3]» %s[/color]\n" % NetplayUI.escape(entry["text"]))
	else:
		var color = Netplay.SLOT_COLORS[entry["slot"] % Netplay.SLOT_COLORS.size()]
		chat_log.append_text("[color=#%s]%s[/color]  %s\n" % [color.to_html(false), NetplayUI.escape(entry["name"]), NetplayUI.escape(entry["text"])])

#endregion

#region Actions

func _on_name_changed(text: String) -> void:
	var caret = name_edit.caret_column
	name_edit.text = Netplay.clean_name(text)
	name_edit.caret_column = caret
	Netplay.set_dj_name(name_edit.text)

func check_name() -> bool:
	if Netplay.dj_name == "":
		set_status("Enter your DJ name first", NetplayUI.ERROR)
		name_edit.grab_focus()
		return false
	return true

func _on_host_pressed() -> void:
	if not check_name():
		return
	var error = Netplay.host()
	if error != "":
		set_status(error, NetplayUI.ERROR)

func _on_join_pressed() -> void:
	join_address(address_edit.text)

func join_address(address: String) -> void:
	if not check_name():
		return
	var error = Netplay.join(address)
	if error != "":
		set_status(error, NetplayUI.ERROR)
		return
	set_status("Connecting to %s…" % address, NetplayUI.WARNING)

func toggle_ready() -> void:
	if not ready_button.disabled:
		Netplay.update_me({"ready": not Netplay.me().get("ready", false)})

func _on_select_pressed() -> void:
	Netplay.update_me({"where": "select", "ready": false})
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")

func _on_chat_submitted(text: String) -> void:
	Netplay.say(text)
	chat_edit.clear()

func go_back() -> void:
	if Netplay.active or Netplay.connecting:
		Netplay.leave()
		set_status("", NetplayUI.ERROR)
		return
	Netplay.stop_discovery()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

#endregion

#region Controller

func _process(delta: float) -> void:
	blink += delta
	if download_bar.visible:
		download_bar.value = Netplay.download_progress()
	if browser.visible and Netplay.rooms.is_empty() and Netplay.listener != null:
		no_room_label.text = "Searching for rooms" + ".".repeat(1 + int(blink * 2) % 3)
	var focused = get_viewport().gui_get_focus_owner()
	# Typing: the keys mapped on the keyboard write in the field
	if focused is LineEdit and focused.is_editing():
		return
	# START held: the game options, the panel takes the keys and the turntable
	if Input.is_action_just_pressed("p1_start") and room_view.visible:
		open_game_options()
	if Input.is_action_just_released("p1_start") and $GameOptionSettings.open:
		close_game_options()
	if $GameOptionSettings.open:
		analog_previous = analog_value()
		return
	for key in ["key2", "key4", "key6"]:
		if Input.is_action_just_pressed("p1_" + key):
			go_back()
			return
	for key in ["key1", "key3", "key5", "key7"]:
		if Input.is_action_just_pressed("p1_" + key) and focused != null:
			if focused is LineEdit:
				focused.edit()
			elif focused is BaseButton and not focused.disabled:
				focused.pressed.emit()
			return
	var steps = 0
	if Input.is_action_just_pressed("p1_digital_turntable_fwd"):
		steps += 1
	if Input.is_action_just_pressed("p1_digital_turntable_rew"):
		steps -= 1
	var value = analog_value()
	var motion = wrapf(value - analog_previous, -1.0, 1.0)
	analog_previous = value
	analog_remainder += motion
	var analog_steps = int(analog_remainder / ANALOG_STEP)
	analog_remainder -= analog_steps * ANALOG_STEP
	steps += analog_steps
	if steps != 0:
		move_focus(signi(steps))

func open_game_options() -> void:
	var panel = $GameOptionSettings
	panel.open = true
	panel.get_node("OpenAudio").play()
	if not panel.visible:
		panel.position.x = size.x
		panel.show()
	slide_game_options(options_x, Tween.EASE_OUT)

func close_game_options() -> void:
	var panel = $GameOptionSettings
	panel.open = false
	panel.get_node("CloseAudio").play()
	slide_game_options(size.x, Tween.EASE_IN).tween_callback(panel.hide)

# A new slide replaces the one running, from where it stopped
func slide_game_options(x: float, ease_type: Tween.EaseType) -> Tween:
	if options_tween:
		options_tween.kill()
	options_tween = create_tween()
	options_tween.tween_property($GameOptionSettings, "position:x", x, OPTIONS_SLIDE_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	return options_tween

func analog_value() -> float:
	return Input.get_action_strength("p1_analog_turntable_fwd") - Input.get_action_strength("p1_analog_turntable_rew")

func move_focus(direction: int) -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null:
		(host_button if browser.visible else leave_button).grab_focus()
		return
	var next = focused.find_next_valid_focus() if direction > 0 else focused.find_prev_valid_focus()
	if next:
		next.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

#endregion
