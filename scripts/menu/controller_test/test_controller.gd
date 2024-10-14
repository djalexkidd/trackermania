extends Control

func _process(delta: float) -> void:
	$P1Container/P1AnalogValues.text = str(Input.get_action_strength("p1_analog_turntable_fwd") - Input.get_action_strength("p1_analog_turntable_rew"))
