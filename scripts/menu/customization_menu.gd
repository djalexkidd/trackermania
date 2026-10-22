extends Control

# Latency calibration: clicks played at a steady beat, the player presses a key on each click
const CALIBRATION_CLICKS = 12
const CALIBRATION_INTERVAL = 0.6
# The first clicks only give the beat and are not measured
const CALIBRATION_IGNORED = 2
const CALIBRATION_MIN_PRESSES = 4

var json_files = Loader.get_all_files("user://music_select_bgm", "ogg")

var calibrating = false
# Time (usec) of each click played, and of the next one to play
var click_times = []
var next_click_usec = 0
# Delay of each press after its click (seconds)
var press_delays = []

func _ready() -> void:
	if Global.custom_music_select_bgm == "":
		$OptionButton.selected = 0
	$TimingCheck.button_pressed = Global.show_timing
	$AudioOffset.value = Global.audio_offset
	$ClickPlayer.stream = make_click()

	for item in json_files:
		$OptionButton.add_item(item)

func _on_option_button_item_selected(index: int) -> void:
	var selected_value = json_files[index-1]
	Global.custom_music_select_bgm = selected_value
	Global.save_settings()

func _on_timing_check_toggled(toggled_on: bool) -> void:
	Global.show_timing = toggled_on
	Global.save_settings()

func _on_audio_offset_value_changed(value: float) -> void:
	Global.audio_offset = int(value)
	Global.save_settings()

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/test_menu.tscn")

# Short 1 kHz beep with a fast decay
func make_click() -> AudioStreamWAV:
	var rate = 44100
	var data = PackedByteArray()
	data.resize(rate / 20 * 2)
	for i in rate / 20:
		var t = float(i) / rate
		data.encode_s16(i * 2, int(sin(TAU * 1000.0 * t) * exp(-t * 60.0) * 30000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func _on_calibrate_button_pressed() -> void:
	calibrating = true
	click_times = []
	press_delays = []
	next_click_usec = Time.get_ticks_usec() + int(CALIBRATION_INTERVAL * 1e6)
	$CalibrateButton.disabled = true
	$CalibrateStatus.text = "Press any key on each click"

func _process(_delta: float) -> void:
	if not calibrating:
		return
	var now = Time.get_ticks_usec()
	if len(click_times) < CALIBRATION_CLICKS:
		if now >= next_click_usec:
			$ClickPlayer.play()
			click_times.append(now)
			next_click_usec += int(CALIBRATION_INTERVAL * 1e6)
	elif now >= click_times[-1] + int(CALIBRATION_INTERVAL * 1e6):
		finish_calibration()

func _input(event: InputEvent) -> void:
	if not calibrating:
		return
	var is_press = (event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch) \
		and event.is_pressed() and not event.is_echo()
	if not is_press:
		return
	# The key must not trigger the focused button
	get_viewport().set_input_as_handled()
	if len(click_times) <= CALIBRATION_IGNORED:
		return
	# Delay after the nearest click
	var now = Time.get_ticks_usec()
	var nearest = click_times[-1]
	if len(click_times) < CALIBRATION_CLICKS and next_click_usec - now < now - nearest:
		nearest = next_click_usec
	if abs(now - nearest) < CALIBRATION_INTERVAL * 0.5e6:
		press_delays.append((now - nearest) / 1e6)
	$CalibrateStatus.text = "Press any key on each click (%d)" % len(press_delays)

func finish_calibration() -> void:
	calibrating = false
	$CalibrateButton.disabled = false
	if len(press_delays) < CALIBRATION_MIN_PRESSES:
		$CalibrateStatus.text = "Not enough presses, try again"
		return
	# Median delay, minus the latency the game already compensates
	press_delays.sort()
	var delay = press_delays[len(press_delays) / 2] - AudioServer.get_output_latency()
	$AudioOffset.value = snapped(delay * 1000.0, $AudioOffset.step)
	$CalibrateStatus.text = "Audio offset set to %d ms" % Global.audio_offset
