extends Control

# Controller Setup: test and remap the inputs of both players (see controller_panel.gd)

func _process(_delta: float) -> void:
	# E1+E2 of either player goes back, unless an input is being assigned or a name typed
	if ControllerPanel.listener != null or Time.get_ticks_msec() - ControllerPanel.last_assign_msec < 500:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	for p in ["p1_", "p2_"]:
		if Input.is_action_pressed(p + "start") and Input.is_action_pressed(p + "effect"):
			back()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		back()

func back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")
