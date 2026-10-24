extends Node

# Autoload: online play. The host keeps the room (players, song, round) and sends it to everyone.
# - LAN discovery: the host broadcasts a beacon over UDP, the room browser listens for it.
# - A player missing the song downloads it from the host (chart file and its sounds).
# - Everyone loads the chart, the round begins when all players are ready to play.
# - Live scores during the round, final results at the end of it.

const PORT = 47800
const DISCOVERY_PORT = 47801
# Bump when the messages change, a client of another version is refused
const PROTOCOL = 1
const MAX_PLAYERS = 8
const NAME_LENGTH = 6
const CHAT_LINES = 100
const BEACON_INTERVAL = 1.0
# A LAN room disappears from the browser after this long without a beacon (seconds)
const ROOM_TIMEOUT = 3.5
# Song transfer: chunks of this size, at most TRANSFER_WINDOW of them not acknowledged per client
const CHUNK_SIZE = 65536
const TRANSFER_WINDOW = 16
const MAX_TRANSFER_SIZE = 1 << 30
const DOWNLOAD_DIR = "user://songs/netplay/"
const SONGS_DIR = "user://songs/"
# The round begins without the players still loading after this long (seconds)
const LOAD_TIMEOUT = 20.0
const LIVE_INTERVAL_MS = 200
const PROGRESS_INTERVAL_MS = 250
const CONFIG_PATH = "user://netplay.cfg"
# Player colors by slot, the first two are the 1P and 2P colors
const SLOT_COLORS = [
	Color(0, 0.686, 1), Color(1, 0.157, 0), Color(1, 0.85, 0), Color(0.3, 1, 0.3),
	Color(0.75, 0.35, 1), Color(1, 0.5, 0.1), Color(0.2, 1, 0.9), Color(1, 0.4, 0.75),
]

signal players_changed
signal room_changed
signal chat_received(entry: Dictionary)
signal rooms_changed
signal live_changed
signal results_changed
signal round_began
# Connected to a room (joined or hosting)
signal opened
# Left the room: by the player, refused, host gone...
signal closed(reason: String)

var active := false
var is_host := false
var connecting := false
var peer: ENetMultiplayerPeer
# Room state sent by the host: name, state ("lobby", "loading" or "playing"), song, seed and players of the round
var room := {}
# id -> {name, slot, ready, where ("lobby", "select", "game", "result"), song_state ("none", "ok", "missing", "downloading"), progress, ping}
var players := {}
var chat: Array[Dictionary] = []
# Song of the room on this machine, "" if it is missing, and the md5 it was looked for
var local_song_path := ""
var local_song_md5 := ""
# Live scores of the round: id -> {ex, max_ex, gauge, combo}
var live := {}
# Results of the round: id -> {name, slot, ex, max_ex, rate, lamp, failed, gauge, combo_max, counts}
var results := {}
var began := false
var last_reason := ""
var dj_name := ""
var last_address := ""

# Host side
var loaded := {}
var load_timer: SceneTreeTimer
var transfers := {}
var next_transfer_id := 1
var beacon: PacketPeerUDP
var beacon_time := 0.0
# Client side
var download := {}
var progress_msec := 0
var live_msec := 0
# LAN rooms: "ip:port" -> {name, address, port, players, max, state, song, time}
var rooms := {}
var listener: PacketPeerUDP

func _ready() -> void:
	var config = ConfigFile.new()
	config.load(CONFIG_PATH)
	dj_name = clean_name(config.get_value("netplay", "name", ""))
	Global.p1_name = dj_name
	last_address = config.get_value("netplay", "address", "")
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ENet is not available in the web export
func supported() -> bool:
	return not OS.has_feature("web")

# DJ names like IIDX: 6 characters, upper case
static func clean_name(text: String) -> String:
	return text.strip_edges().to_upper().left(NAME_LENGTH)

func set_dj_name(text: String) -> void:
	dj_name = clean_name(text)
	Global.p1_name = dj_name
	save_config()

func save_config() -> void:
	var config = ConfigFile.new()
	config.set_value("netplay", "name", dj_name)
	config.set_value("netplay", "address", last_address)
	config.save(CONFIG_PATH)

func my_id() -> int:
	return multiplayer.get_unique_id() if active else 0

func me() -> Dictionary:
	return players.get(my_id(), {})

func color_of(id: int) -> Color:
	return SLOT_COLORS[players.get(id, results.get(id, {})).get("slot", 0) % SLOT_COLORS.size()]

# Sender of the current RPC, this machine when called directly
func _sender() -> int:
	var id = multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()

# Run a method on the host, directly when this machine is the host
func _to_host(method: StringName, args: Array = []) -> void:
	if is_host:
		callv(method, args)
	elif active:
		callv("rpc_id", [1, method] + args)

#region Connection

func host() -> String:
	if not supported():
		return "Netplay is not available in the web version"
	close_quietly()
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 32)
	if error != OK:
		return "Could not open port %d (%s)" % [PORT, error_string(error)]
	multiplayer.multiplayer_peer = peer
	is_host = true
	active = true
	_reset_room()
	room = {"name": "%s'S ROOM" % dj_name, "state": "lobby", "song": {}, "seed": 0, "round": []}
	players[1] = _new_player(dj_name, 0)
	beacon = PacketPeerUDP.new()
	beacon.set_broadcast_enabled(true)
	stop_discovery()
	_system("Room opened, port %d" % PORT)
	opened.emit()
	room_changed.emit()
	players_changed.emit()
	return ""

# Address "ip" or "ip:port"
func join(address: String) -> String:
	if not supported():
		return "Netplay is not available in the web version"
	address = address.strip_edges()
	var port = PORT
	if address.count(":") == 1:
		port = address.get_slice(":", 1).to_int()
		address = address.get_slice(":", 0)
	if address == "":
		return "Enter the address of the host"
	close_quietly()
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		return "Could not connect (%s)" % error_string(error)
	multiplayer.multiplayer_peer = peer
	connecting = true
	last_reason = ""
	last_address = address if port == PORT else "%s:%d" % [address, port]
	save_config()
	return ""

func leave() -> void:
	close("")

func close(reason: String) -> void:
	var was_open = active or connecting
	close_quietly()
	last_reason = reason
	if was_open:
		closed.emit(reason)

# Close the connection, the results of the round stay for the result screen
func close_quietly() -> void:
	for id in transfers:
		_end_transfer(id)
	_abort_download()
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	is_host = false
	connecting = false
	beacon = null
	loaded.clear()
	# A playfield waiting for the other players starts alone
	if not began:
		began = true
		round_began.emit()

func _reset_room() -> void:
	players.clear()
	chat.clear()
	room = {}
	local_song_path = ""
	local_song_md5 = ""
	live.clear()
	results.clear()
	began = false
	last_reason = ""

func _new_player(player_name: String, slot: int) -> Dictionary:
	return {"name": player_name, "slot": slot, "ready": false, "where": "lobby",
		"song_state": "ok" if room.get("song", {}).is_empty() else "missing", "progress": 0.0, "ping": 0}

func _on_connected() -> void:
	_hello.rpc_id(1, dj_name, PROTOCOL)

# Deferred: the peer can't be replaced while it is being polled
func _on_connection_failed() -> void:
	close.call_deferred("Could not reach the host")

func _on_server_disconnected() -> void:
	close.call_deferred(last_reason if last_reason != "" else "The host closed the room")

func _on_peer_disconnected(id: int) -> void:
	if not is_host or not players.has(id):
		return
	_end_transfer(id)
	var player_name = players[id]["name"]
	players.erase(id)
	_sync_players.rpc(players)
	_system("%s left" % player_name)
	_check_loaded()
	_check_round_over()

# A new player introduces itself to the host
@rpc("any_peer", "reliable")
func _hello(player_name: String, protocol: int) -> void:
	if not is_host:
		return
	var id = _sender()
	if protocol != PROTOCOL:
		_refuse(id, "Different game version")
		return
	if players.size() >= MAX_PLAYERS:
		_refuse(id, "The room is full")
		return
	var used = players.values().map(func(player): return player["slot"])
	var slot = 0
	while slot in used:
		slot += 1
	players[id] = _new_player(clean_name(player_name), slot)
	_welcome.rpc_id(id, room, chat)
	_sync_players.rpc(players)
	_system("%s joined" % players[id]["name"])

func _refuse(id: int, reason: String) -> void:
	_refused.rpc_id(id, reason)
	# Let the message go before the disconnection
	get_tree().create_timer(0.5).timeout.connect(func(): if peer: peer.disconnect_peer(id))

@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	last_reason = reason

@rpc("authority", "reliable")
func _welcome(room_state: Dictionary, history: Array) -> void:
	_reset_room()
	connecting = false
	active = true
	chat.assign(history)
	opened.emit()
	_sync_room(room_state)

@rpc("authority", "call_local", "reliable")
func _sync_players(state: Dictionary) -> void:
	players = state
	players_changed.emit()

@rpc("authority", "call_local", "reliable")
func _sync_room(state: Dictionary) -> void:
	room = state
	# The host changes its room in place, the md5 of the last search tells a new song
	if room["song"].get("md5", "") != local_song_md5:
		_song_changed()
	room_changed.emit()

func _broadcast_room() -> void:
	_sync_room.rpc(room)

# This player's state in the room: ready, where, song_state, progress
func update_me(fields: Dictionary) -> void:
	if active:
		_to_host(&"_update_player", [fields])

@rpc("any_peer", "reliable")
func _update_player(fields: Dictionary) -> void:
	var id = _sender()
	if not is_host or not players.has(id):
		return
	for key in ["ready", "where", "song_state", "progress"]:
		if fields.has(key):
			players[id][key] = fields[key]
	if players[id]["where"] != "lobby" or players[id]["song_state"] != "ok":
		players[id]["ready"] = false
	_sync_players.rpc(players)

func _process(delta: float) -> void:
	_poll_discovery()
	if not is_host:
		return
	_send_chunks()
	beacon_time -= delta
	if beacon_time <= 0.0:
		beacon_time = BEACON_INTERVAL
		_send_beacon()
		_update_pings()

func _update_pings() -> void:
	var changed = false
	for id in players:
		if id == 1:
			continue
		var packet_peer = peer.get_peer(id)
		if packet_peer:
			var ping = int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
			changed = changed or ping != players[id]["ping"]
			players[id]["ping"] = ping
	if changed:
		_sync_players.rpc(players)

#endregion

#region Chat

func say(text: String) -> void:
	text = text.strip_edges().left(200)
	if text != "":
		_to_host(&"_say", [text])

@rpc("any_peer", "reliable")
func _say(text: String) -> void:
	var id = _sender()
	if is_host and players.has(id):
		_chat.rpc({"name": players[id]["name"], "slot": players[id]["slot"], "text": text.left(200)})

func _system(text: String) -> void:
	if is_host:
		_chat.rpc({"name": "", "slot": 0, "text": text})

# Message shown on this machine only
func _local_system(text: String) -> void:
	_chat({"name": "", "slot": 0, "text": text})

@rpc("authority", "call_local", "reliable")
func _chat(entry: Dictionary) -> void:
	chat.append(entry)
	if chat.size() > CHAT_LINES:
		chat.pop_front()
	chat_received.emit(entry)

#endregion

#region Song

# The host picks the song of the room in the music select
func choose_song(path: String, difficulty: String, title: String, artist: String, level: int) -> void:
	if not is_host or not path.begins_with(SONGS_DIR):
		return
	var type = "QUAVER"
	if ModModule.is_module(path):
		type = "MODULE"
	elif BmsChart.is_bms(path):
		type = "BMS"
	room["song"] = {"path": path.trim_prefix(SONGS_DIR), "md5": FileAccess.get_md5(path), "difficulty": difficulty,
		"title": title, "artist": artist, "level": level, "type": type}
	for id in players:
		players[id]["ready"] = false
		players[id]["song_state"] = "ok" if id == 1 else "missing"
		players[id]["progress"] = 0.0
	_sync_players.rpc(players)
	_broadcast_room()
	_system("Song: %s [%s]" % [title, difficulty])

# Song suggested by a player in its music select
func suggest_song(title: String, difficulty: String) -> void:
	say("suggests %s [%s]" % [title, difficulty])

func _song_changed() -> void:
	_abort_download()
	var song = room["song"]
	local_song_md5 = song.get("md5", "")
	if song.is_empty():
		local_song_path = ""
		return
	local_song_path = find_song(song)
	if is_host:
		return
	if local_song_path != "":
		update_me({"song_state": "ok", "progress": 1.0})
	else:
		update_me({"song_state": "downloading", "progress": 0.0})
		_request_song.rpc_id(1, song["md5"])

# The song on this machine: same place as the host, or downloaded before
func find_song(song: Dictionary) -> String:
	for path in [SONGS_DIR + song["path"], DOWNLOAD_DIR + song["path"]]:
		if FileAccess.file_exists(path) and FileAccess.get_md5(path) == song["md5"]:
			return path
	return ""

func has_song() -> bool:
	return local_song_path != ""

# Files sent with a chart, the chart last so that it only exists once everything arrived
func song_files(path: String) -> Array:
	var files = []
	var dir = path.get_base_dir()
	if BmsChart.is_bms(path) and dir + "/" != SONGS_DIR:
		# The keysounds can be anywhere in the folder of the chart
		for file in Loader.get_all_files(dir):
			if file != path and file.get_extension() != "part":
				files.append(file)
	elif path.get_extension().to_lower() == "qua":
		var chart = QuaChart.load_file(path)
		if chart and FileAccess.file_exists(dir.path_join(chart.audioFile)):
			files.append(dir.path_join(chart.audioFile))
	files.append(path)
	return files

@rpc("any_peer", "reliable")
func _request_song(md5: String) -> void:
	var id = _sender()
	if not is_host or not players.has(id) or room["song"].get("md5", "") != md5:
		return
	_end_transfer(id)
	var list = []
	var total = 0
	for file in song_files(SONGS_DIR + room["song"]["path"]):
		var size = FileAccess.open(file, FileAccess.READ).get_length() if FileAccess.file_exists(file) else 0
		list.append({"path": file, "rel": file.trim_prefix(SONGS_DIR), "size": size})
		total += size
	if total > MAX_TRANSFER_SIZE:
		_transfer_failed.rpc_id(id, "The song is too big to be sent")
		return
	var transfer_id = next_transfer_id
	next_transfer_id += 1
	transfers[id] = {"id": transfer_id, "files": list, "index": 0, "file": null, "left": 0, "sent": 0, "acked": 0}
	_transfer_begin.rpc_id(id, transfer_id, md5, list.map(func(file): return {"rel": file["rel"], "size": file["size"]}))

func _end_transfer(id: int) -> void:
	if transfers.has(id) and transfers[id]["file"]:
		transfers[id]["file"].close()
	transfers.erase(id)

# Send the chunks of each transfer, no more than TRANSFER_WINDOW waiting for their acknowledgement
func _send_chunks() -> void:
	for id in transfers.keys():
		var transfer = transfers[id]
		while transfer["sent"] - transfer["acked"] < TRANSFER_WINDOW and transfer["index"] < transfer["files"].size():
			var info = transfer["files"][transfer["index"]]
			if transfer["file"] == null:
				transfer["file"] = FileAccess.open(info["path"], FileAccess.READ)
				transfer["left"] = info["size"]
			var data = PackedByteArray()
			if transfer["file"]:
				data = transfer["file"].get_buffer(mini(CHUNK_SIZE, transfer["left"]))
			# A file shorter than announced is padded, the client then sees a wrong chart and drops it
			if data.size() < mini(CHUNK_SIZE, transfer["left"]):
				data.resize(mini(CHUNK_SIZE, transfer["left"]))
			transfer["left"] -= data.size()
			_transfer_chunk.rpc_id(id, transfer["id"], transfer["index"], data)
			transfer["sent"] += 1
			if transfer["left"] <= 0:
				if transfer["file"]:
					transfer["file"].close()
				transfer["file"] = null
				transfer["index"] += 1
		if transfer["index"] >= transfer["files"].size() and transfer["acked"] >= transfer["sent"]:
			transfers.erase(id)

@rpc("any_peer", "reliable")
func _transfer_ack(transfer_id: int, chunks: int) -> void:
	var id = _sender()
	if is_host and transfers.has(id) and transfers[id]["id"] == transfer_id:
		transfers[id]["acked"] = chunks

# A downloaded file must stay inside the download folder
static func safe_path(rel: String) -> bool:
	if rel == "" or rel.contains("\\") or rel.contains(":") or rel.begins_with("/"):
		return false
	for part in rel.split("/"):
		if part == ".." or part == ".":
			return false
	return true

@rpc("authority", "reliable")
func _transfer_begin(transfer_id: int, md5: String, files: Array) -> void:
	_abort_download()
	if room.get("song", {}).get("md5", "") != md5:
		return
	var total = 0
	for file in files:
		if not file is Dictionary or not safe_path(str(file.get("rel", ""))):
			_download_failed("Invalid file in the song")
			return
		total += int(file.get("size", 0))
	if total > MAX_TRANSFER_SIZE:
		_download_failed("The song is too big")
		return
	# A song the host downloaded before keeps its place in the download folder
	var root = SONGS_DIR if room["song"]["path"].begins_with("netplay/") else DOWNLOAD_DIR
	download = {"id": transfer_id, "files": files, "root": root, "index": 0, "received": 0,
		"done": 0, "total": total, "chunks": 0, "file": null}
	_local_system("Downloading %s…" % room["song"]["title"])

@rpc("authority", "reliable")
func _transfer_chunk(transfer_id: int, index: int, data: PackedByteArray) -> void:
	if download.is_empty() or download["id"] != transfer_id or index != download["index"]:
		return
	var info = download["files"][index]
	var path = download["root"] + info["rel"]
	if download["file"] == null:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		download["file"] = FileAccess.open(path + ".part", FileAccess.WRITE)
		if download["file"] == null:
			_download_failed("Could not write %s" % info["rel"])
			return
	download["file"].store_buffer(data)
	download["received"] += data.size()
	download["done"] += data.size()
	download["chunks"] += 1
	_transfer_ack.rpc_id(1, transfer_id, download["chunks"])
	if download["received"] >= int(info["size"]):
		download["file"].close()
		download["file"] = null
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		DirAccess.rename_absolute(path + ".part", path)
		download["index"] += 1
		download["received"] = 0
	if download["index"] >= download["files"].size():
		_download_finished()
	elif Time.get_ticks_msec() - progress_msec >= PROGRESS_INTERVAL_MS:
		progress_msec = Time.get_ticks_msec()
		update_me({"progress": download_progress()})

func download_progress() -> float:
	if download.is_empty():
		return 0.0
	return float(download["done"]) / maxf(download["total"], 1)

func _download_finished() -> void:
	download = {}
	local_song_path = find_song(room["song"])
	if local_song_path == "":
		_download_failed("The downloaded song is different from the host's")
		return
	# The music select scans the songs again to show it
	Loader.clear_song_catalog()
	_local_system("Downloaded %s" % room["song"]["title"])
	update_me({"song_state": "ok", "progress": 1.0})

@rpc("authority", "reliable")
func _transfer_failed(reason: String) -> void:
	_download_failed(reason)

func _download_failed(reason: String) -> void:
	_abort_download()
	_local_system("Download failed: " + reason)
	update_me({"song_state": "missing", "progress": 0.0})

func _abort_download() -> void:
	if not download.is_empty() and download["file"]:
		download["file"].close()
	download = {}

#endregion

#region Round

# The host can start when everyone in the lobby has the song and is ready
func can_start() -> bool:
	if not is_host or room["state"] != "lobby" or room["song"].is_empty():
		return false
	# A player who could not get the song does not hold the others
	for id in players:
		var player = players[id]
		if player["where"] == "lobby" and not player["ready"] and id != 1 and player["song_state"] != "missing":
			return false
	return round_players().size() > 0

# Players of the next round: the ready ones in the lobby, the host always
func round_players() -> Array:
	return players.keys().filter(func(id): return players[id]["where"] == "lobby" \
		and players[id]["song_state"] == "ok" and (players[id]["ready"] or id == 1))

func start_round() -> void:
	if not can_start():
		return
	room["state"] = "loading"
	room["seed"] = randi()
	room["round"] = round_players()
	loaded.clear()
	_broadcast_room()
	_start_round.rpc()
	load_timer = get_tree().create_timer(LOAD_TIMEOUT)
	var timer = load_timer
	timer.timeout.connect(func(): if timer == load_timer and room.get("state") == "loading": _begin_round())

@rpc("authority", "call_local", "reliable")
func _start_round() -> void:
	live.clear()
	results.clear()
	began = false
	if not my_id() in room["round"] or local_song_path == "":
		return
	Loader.file_path = local_song_path
	Loader.chart_difficulty = room["song"]["difficulty"]
	# Netplay is player 1 on each machine
	Global.p1_joined = true
	Global.p2_joined = false
	update_me({"where": "game", "ready": false})
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")

func in_round() -> bool:
	return active and my_id() in room.get("round", [])

# Called by the playfield once the chart is loaded
func mark_loaded() -> void:
	_to_host(&"_player_loaded")

func wait_begin() -> void:
	if not began:
		await round_began

@rpc("any_peer", "reliable")
func _player_loaded() -> void:
	if is_host:
		loaded[_sender()] = true
		_check_loaded()

func _check_loaded() -> void:
	if room.get("state") != "loading":
		return
	for id in room["round"]:
		if players.has(id) and not loaded.has(id):
			return
	_begin_round()

func _begin_round() -> void:
	room["state"] = "playing"
	_broadcast_room()
	_begin.rpc()

@rpc("authority", "call_local", "reliable")
func _begin() -> void:
	began = true
	round_began.emit()

# Score of this player during the round, sent a few times per second
func send_live(ex: int, max_ex: int, gauge: int, combo: int) -> void:
	if not active or Time.get_ticks_msec() - live_msec < LIVE_INTERVAL_MS:
		return
	live_msec = Time.get_ticks_msec()
	_live.rpc({"ex": ex, "max_ex": max_ex, "gauge": gauge, "combo": combo})

@rpc("any_peer", "call_local", "unreliable_ordered")
func _live(data: Dictionary) -> void:
	live[_sender()] = data
	live_changed.emit()

func send_result(result: Dictionary) -> void:
	result["name"] = dj_name
	if active:
		result["slot"] = me().get("slot", 0)
		update_me({"where": "result"})
		_result.rpc(result)
	else:
		_result(result)

@rpc("any_peer", "call_local", "reliable")
func _result(result: Dictionary) -> void:
	var id = _sender()
	results[id] = result
	live[id] = {"ex": result.get("ex", 0), "max_ex": result.get("max_ex", 0), "gauge": result.get("gauge", 0), "combo": 0}
	results_changed.emit()
	_check_round_over()

func _check_round_over() -> void:
	if not is_host or room.get("state") == "lobby":
		return
	for id in room["round"]:
		if players.has(id) and not results.has(id):
			return
	room["state"] = "lobby"
	_broadcast_room()

func round_over() -> bool:
	for id in room.get("round", []):
		if (players.has(id) or not active) and not results.has(id):
			return false
	return true

#endregion

#region LAN discovery

func start_discovery() -> void:
	if listener or not supported():
		return
	listener = PacketPeerUDP.new()
	# Only one game per machine can listen, the others can still join by address
	if listener.bind(DISCOVERY_PORT) != OK:
		listener = null

func stop_discovery() -> void:
	if listener:
		listener.close()
	listener = null
	rooms.clear()

func _send_beacon() -> void:
	if beacon == null:
		return
	var data = JSON.stringify({
		"game": "trackermania", "protocol": PROTOCOL, "name": room["name"], "port": PORT,
		"players": players.size(), "max": MAX_PLAYERS, "state": room["state"],
		"song": room["song"].get("title", ""),
	}).to_utf8_buffer()
	for address in broadcast_addresses():
		beacon.set_dest_address(address, DISCOVERY_PORT)
		beacon.put_packet(data)

# The global broadcast, and the /24 broadcast of each LAN address (Windows only sends the first one on one interface)
func broadcast_addresses() -> Array:
	var addresses = ["255.255.255.255"]
	for address in local_addresses():
		var parts = address.split(".")
		addresses.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	return addresses

# LAN IPv4 addresses of this machine, shown to the players joining by address
func local_addresses() -> Array:
	var result = []
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			result.append(address)
	return result

func _poll_discovery() -> void:
	if listener == null:
		return
	var changed = false
	while listener.get_available_packet_count() > 0:
		var packet = listener.get_packet()
		var address = listener.get_packet_ip()
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if not data is Dictionary or data.get("game") != "trackermania":
			continue
		var key = "%s:%d" % [address, int(data.get("port", PORT))]
		changed = changed or not rooms.has(key)
		rooms[key] = {
			"address": address, "port": int(data.get("port", PORT)), "name": str(data.get("name", "")),
			"players": int(data.get("players", 0)), "max": int(data.get("max", MAX_PLAYERS)),
			"state": str(data.get("state", "")), "song": str(data.get("song", "")),
			"protocol": int(data.get("protocol", 0)), "time": Time.get_ticks_msec(),
		}
		changed = true
	for key in rooms.keys():
		if Time.get_ticks_msec() - rooms[key]["time"] > ROOM_TIMEOUT * 1000:
			rooms.erase(key)
			changed = true
	if changed:
		rooms_changed.emit()

#endregion
