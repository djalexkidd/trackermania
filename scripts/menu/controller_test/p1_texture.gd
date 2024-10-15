extends TextureRect

# Rotation speed factor
var rotation_speed := 100.0

# Variable to track the previous analog value
var previous_value := 0.0

func _process(delta: float) -> void:
	if Input.is_action_pressed("p1_key1"):
		$B1Pressed.show()
	
	if Input.is_action_pressed("p1_key2"):
		$B2Pressed.show()
	
	if Input.is_action_pressed("p1_key3"):
		$B3Pressed.show()
	
	if Input.is_action_pressed("p1_key4"):
		$B4Pressed.show()
	
	if Input.is_action_pressed("p1_key5"):
		$B5Pressed.show()
	
	if Input.is_action_pressed("p1_key6"):
		$B6Pressed.show()
	
	if Input.is_action_pressed("p1_key7"):
		$B7Pressed.show()
	
	if Input.is_action_pressed("p1_start"):
		$E1Pressed.show()
	
	if Input.is_action_pressed("p1_effect"):
		$E2Pressed.show()
	
	if Input.is_action_pressed("p1_vefx"):
		$E3Pressed.show()
	
	if Input.is_action_pressed("p1_meta"):
		$E4Pressed.show()
	
	if Input.is_action_pressed("p1_digital_turntable_fwd"):
		$Turntable3.show()
	
	if Input.is_action_pressed("p1_digital_turntable_rew"):
		$Turntable2.show()
	
	
	if Input.is_action_just_released("p1_key1"):
		$B1Pressed.hide()
	
	if Input.is_action_just_released("p1_key2"):
		$B2Pressed.hide()
	
	if Input.is_action_just_released("p1_key3"):
		$B3Pressed.hide()
	
	if Input.is_action_just_released("p1_key4"):
		$B4Pressed.hide()
	
	if Input.is_action_just_released("p1_key5"):
		$B5Pressed.hide()
	
	if Input.is_action_just_released("p1_key6"):
		$B6Pressed.hide()
	
	if Input.is_action_just_released("p1_key7"):
		$B7Pressed.hide()
	
	if Input.is_action_just_released("p1_start"):
		$E1Pressed.hide()
	
	if Input.is_action_just_released("p1_effect"):
		$E2Pressed.hide()
	
	if Input.is_action_just_released("p1_vefx"):
		$E3Pressed.hide()
	
	if Input.is_action_just_released("p1_meta"):
		$E4Pressed.hide()
	
	if Input.is_action_just_released("p1_digital_turntable_fwd"):
		$Turntable3.hide()
	
	if Input.is_action_just_released("p1_digital_turntable_rew"):
		$Turntable2.hide()
	
	if Input.is_action_pressed("p1_start") and Input.is_action_pressed("p1_effect"):
		get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")
	
	# Get the current analog value from the turntable
	var current_value := Input.get_action_strength("p1_analog_turntable_fwd") - Input.get_action_strength("p1_analog_turntable_rew")

	# Check if the analog value has changed since the last frame
	if current_value != previous_value:
		# Calculate the rotation difference
		var rotation_difference := (current_value - previous_value) * rotation_speed
		# Apply the rotation difference
		$Turntable.rotation_degrees += rotation_difference

		# Update the previous value to the current one
		previous_value = current_value
