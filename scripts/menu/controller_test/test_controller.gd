extends Control

func _process(delta: float) -> void:
	$P1Container/P1AnalogValues.text = str(Input.get_action_strength("p1_analog_turntable_fwd") - Input.get_action_strength("p1_analog_turntable_rew"))

func _on_remap_keys_button_pressed() -> void:
	$P1Container.hide()
	$P1RemapKeysButton.hide()
	$P1RemapKeys.show()
	$P1RemapFinish.show()

func _on_p_1_remap_finish_pressed() -> void:
	$P1Container.show()
	$P1RemapKeysButton.show()
	$P1RemapKeys.hide()
	$P1RemapFinish.hide()
