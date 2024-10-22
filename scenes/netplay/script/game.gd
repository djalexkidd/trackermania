extends Control


const _crown = preload("res://scenes/netplay/img/crown.png")

var _players = []

@onready var _list = $HBoxContainer/VBoxContainer/ItemList
@onready var _action = $HBoxContainer/VBoxContainer/Action

var senderName: String = "no name Set"

#The master and mastersync rpc behavior is not officially supported anymore. Try using another keyword or making custom logic using get_multiplayer().get_remote_sender_id()
@rpc("any_peer", "call_local")
func set_player_name(_name):
	var sender = multiplayer.get_remote_sender_id()
	rpc("update_player_name", sender, _name)


@rpc("any_peer", "call_local") func update_player_name(player, _name):
	var pos = _players.find(player)
	if pos != -1:
		_list.set_item_text(pos, _name)
	
	if get_multiplayer_authority() == pos:
		_list.set_item_icon(0, _crown)


func onTextSubmitted(_string: String):
	if _string.length() <= 0:
		return
	$HBoxContainer/VBoxContainer/Chat.text = ""
	sendText.rpc(senderName, _string)


@rpc("any_peer", "call_local", "reliable")
func sendText(user, _string):
	_log(user, _string)


@rpc("any_peer", "call_local") func del_player(id):
	var pos = _players.find(id)
	if pos == -1:
		return
	_players.remove_at(pos)
	_list.remove_item(pos)


@rpc("any_peer", "call_local") func add_player(id, _name=""):
	_players.append(id)
	if _name == "":
		_list.add_item("... connecting ...", null, false)
	else:
		_list.add_item(_name, null, false)


func get_player_name(pos):
	if pos < _list.get_item_count():
		return _list.get_item_text(pos)
	else:
		return "Error!"


func start():
	_action.disabled = false


func stop():
	_players.clear()
	_list.clear()
	_action.disabled = true


func on_peer_add(id):
	if not multiplayer.is_server():
		return
	for i in range(0, _players.size()):
		rpc_id(id, "add_player", _players[i], get_player_name(i))
	rpc("add_player", id)


func on_peer_del(id):
	if not multiplayer.is_server():
		return
	rpc("del_player", id)

@rpc("any_peer", "call_local") func _log(username, message):
	$HBoxContainer/RichTextLabel.append_text("%s: %s\n" % [username, message])


func _on_Action_pressed():
	onTextSubmitted($HBoxContainer/VBoxContainer/Chat.text)


func _on_chat_text_submitted(new_text: String) -> void:
	onTextSubmitted($HBoxContainer/VBoxContainer/Chat.text)
