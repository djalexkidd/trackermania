extends Control

const DEF_PORT = 8080
const PROTO_NAME = "ludus"

var peer = null

@onready var _host_btn = $Panel/VBoxContainer/HBoxContainer2/HBoxContainer/Host
@onready var _connect_btn = $Panel/VBoxContainer/HBoxContainer2/HBoxContainer/Connect
@onready var _disconnect_btn = $Panel/VBoxContainer/HBoxContainer2/HBoxContainer/Disconnect
@onready var _exit_btn = $Panel/VBoxContainer/HBoxContainer/ReturnToMenu
@onready var _music_select_btn = $Panel/VBoxContainer/HBoxContainer2/HBoxContainer/MusicSelect
@onready var _start_game_btn = $Panel/VBoxContainer/HBoxContainer2/HBoxContainer/StartGame
@onready var _name_edit = $Panel/VBoxContainer/HBoxContainer/NameEdit
@onready var _host_edit = $Panel/VBoxContainer/HBoxContainer2/Hostname
@onready var _game = $Panel/VBoxContainer/Game
@onready var multiplayerPeer = ENetMultiplayerPeer.new()

var path

func _ready():
	#warning-ignore-all:return_value_discarded
	multiplayer.connect("peer_disconnected",Callable(self,"_peer_disconnected"))
	multiplayer.connect("peer_connected",Callable(self,"_peer_connected"))
	
	$AcceptDialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$AcceptDialog.get_label().vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Set the player name according to the system username. Fallback to the path.
	if OS.has_environment("USERNAME"):
		_name_edit.text = OS.get_environment("USERNAME")
	else:
		var desktop_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).replace("\\", "/").split("/")
		_name_edit.text = desktop_path[desktop_path.size() - 2]

func start_game():
	_host_btn.disabled = true
	_exit_btn.disabled = true
	_name_edit.editable = false
	_host_edit.editable = false
	_game.senderName = _name_edit.text
	_connect_btn.hide()
	_disconnect_btn.show()
	if multiplayer.is_server():
		_music_select_btn.show()
	_game.start()

func stop_game():
	_host_btn.disabled = false
	_exit_btn.disabled = false
	_name_edit.editable = true
	_host_edit.editable = true
	_disconnect_btn.hide()
	_music_select_btn.hide()
	_connect_btn.show()
	_game.stop()

func _close_network():
	
	if multiplayer.is_connected("server_disconnected",Callable(self,"_close_network")):
		multiplayer.disconnect("server_disconnected",Callable(self,"_close_network"))
	if multiplayer.is_connected("connection_failed",Callable(self,"_close_network")):
		multiplayer.disconnect("connection_failed",Callable(self,"_close_network"))
	if multiplayer.is_connected("connected_to_server",Callable(self,"_connected")):
		multiplayer.disconnect("connected_to_server",Callable(self,"_connected"))
	
	multiplayerPeer.close()
	multiplayerPeer = ENetMultiplayerPeer.new()

	stop_game()
	$AcceptDialog.show()
	$AcceptDialog.get_ok_button().grab_focus()
	

func _connected():
	_game.rpc("set_player_name", _name_edit.text)

func _peer_connected(id):
	_game.on_peer_add(id)
	

func _peer_disconnected(id):
	_game.on_peer_del(id)
	if id==1:
		_close_network()

func _on_Host_pressed():
	
	multiplayerPeer.create_server(DEF_PORT)
	
	if multiplayerPeer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Connection Failed")
		return
	
	multiplayer.connect("server_disconnected",Callable(self,"_close_network"))
	multiplayer.set_multiplayer_peer(multiplayerPeer)
	
	_game.add_player(1, _name_edit.text)
	
	start_game()

func _on_Disconnect_pressed():
	_close_network()

func _on_Connect_pressed():
	var txt=$Panel/VBoxContainer/HBoxContainer2/Hostname.text
	if txt=="":
		OS.alert("Needs host to connect to")
		return
	multiplayerPeer.create_client(txt,DEF_PORT)
	multiplayer.connect("connection_failed",Callable(self,"_close_network"))
	multiplayer.connect("connected_to_server",Callable(self,"_connected"))

	multiplayer.set_multiplayer_peer(multiplayerPeer)
	start_game()

func _on_music_select_pressed() -> void:
	change_level.call_deferred(load("res://scenes/menu/music_select.tscn"))

# Call this function deferred and only on the main authority (server).
func change_level(scene: PackedScene):
	add_child(scene.instantiate())

func music_selected():
	_game.onTextSubmitted("Selected: " + Loader.load_json_file(Loader.file_path)["Title"])
	_start_game_btn.show()

func game_finished(score):
	$Panel.show()
	_game.onTextSubmitted(str(score))

func _on_start_game_pressed() -> void:
	if multiplayer.is_server():
		rpc("level_play", Loader.file_path)

@rpc("any_peer", "call_local")
func level_play(test):
	Loader.file_path = test
	$Panel.hide()
	change_level.call_deferred(load("res://scenes/game/main_netplay.tscn"))

func _on_return_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")
