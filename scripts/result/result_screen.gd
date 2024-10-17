extends Control

func _ready() -> void:
	$ScoreLabel.text = "Accuracy: " + str(Global.score) + "%"
	$ComboLabel.text = "Max combo: " + str(Global.combo_max)

func _on_button_pressed() -> void:
	Global.score = 0
	Global.combo_max = 0
	get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")
