extends Control

func _ready() -> void:
	$P1Container/LineEdit.text = Global.p1_name

func _process(delta: float) -> void:
	$P1Container/P1AnalogValues.text = str(Input.get_action_strength("p1_analog_turntable_fwd") - Input.get_action_strength("p1_analog_turntable_rew"))

func _on_remap_keys_button_pressed() -> void:
	$P1Container.hide()
	$P1Container/P1RemapKeysButton.hide()
	$P1RemapKeys.show()
	$P1RemapFinish.show()

func _on_p_1_remap_finish_pressed() -> void:
	$P1Container.show()
	$P1Container/P1RemapKeysButton.show()
	$P1RemapKeys.hide()
	$P1RemapFinish.hide()

func _on_line_edit_text_changed(new_text: String) -> void:
	Global.p1_name = new_text


func _on_p_2_remap_keys_button_pressed() -> void:
	$P2Container.hide()
	$P2Container/P2RemapKeysButton.hide()
	$P2RemapKeys.show()
	$P2RemapFinish.show()

func _on_p_2_remap_finish_pressed() -> void:
	$P2Container.show()
	$P2Container/P2RemapKeysButton.show()
	$P2RemapKeys.hide()
	$P2RemapFinish.hide()

func _on_line_edit_p2_text_changed(new_text: String) -> void:
	Global.p2_name = new_text
