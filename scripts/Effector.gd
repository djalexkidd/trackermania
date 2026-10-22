extends Node

# The effector, like the EFFECT button of IIDX: one preset at a time on the Master bus,
# so it applies to the music select, its preview and the game (keysounds and BGM).
# It survives scene changes; the main menu turns it off.

const NAMES : Array[String] = [
	"EFFECTOR OFF", "CHORUS", "PHASER", "FLANGER", "REVERB", "ECHO", "STADIUM", "COMPRESSOR",
	"FILTER SWEEP", "WOBBLE", "RADIO", "UNDERWATER", "BITCRUSH", "MEGA BASS",
	"GARGLE", "8D AUDIO", "CHIPMUNK", "MONSTER", "DRUNK",
]
# Small FFT for the pitch shifters: it delays the sound by about 8 ms, a bigger one would be off beat
const PITCH_FFT : int = AudioEffectPitchShift.FFT_SIZE_512
# Gargle like the DirectX one of IIDX: the volume goes up and down along a triangle.
# The gain only changes at each frame, so it cannot go as fast as the 20 Hz of the original
const GARGLE_HZ : float = 12.0
# Holding EFFECT this long turns the effector off (ms)
const OFF_HOLD_MS : int = 1000

signal changed(index : int)

var index : int = 0
# EFFECT action being held and when it was pressed
var held_action : String = ""
var held_ms : int = 0
# Effects added by the current preset, from the first one on the bus
var effects : Array[AudioEffect] = []
var bus : int = 0
var start_ms : int = 0

func _ready() -> void:
	bus = AudioServer.get_bus_index("Master")

func current_name() -> String:
	return NAMES[index]

func next() -> void:
	set_effect((index + 1) % NAMES.size())

# Called each frame with the EFFECT actions of the players: a press goes to the next preset,
# holding the button turns the effector off. Returns true when the preset changed
func update_button(actions : Array) -> bool:
	for action in actions:
		if Input.is_action_just_pressed(action):
			held_action = action
			held_ms = Time.get_ticks_msec()
			next()
			return true
	if held_action == "":
		return false
	if not Input.is_action_pressed(held_action):
		held_action = ""
	elif Time.get_ticks_msec() - held_ms >= OFF_HOLD_MS:
		held_action = ""
		set_effect(0)
		return true
	return false

func set_effect(new_index : int) -> void:
	for i in range(effects.size()):
		AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	index = new_index
	effects = build(NAMES[index])
	# Some presets get louder than the music: a limiter keeps them from clipping
	if not effects.is_empty():
		effects.append(AudioEffectHardLimiter.new())
	for effect in effects:
		AudioServer.add_bus_effect(bus, effect)
	start_ms = Time.get_ticks_msec()
	changed.emit(index)

func build(preset : String) -> Array[AudioEffect]:
	match preset:
		"CHORUS":
			var chorus := AudioEffectChorus.new()
			chorus.dry = 0.5
			chorus.set_voice_delay_ms(1, 25.0)
			return [chorus]
		"PHASER":
			var phaser := AudioEffectPhaser.new()
			phaser.depth = 1.5
			phaser.feedback = 0.6
			return [phaser]
		"FLANGER":
			# One short voice swinging slowly: the comb filter goes up and down
			var flanger := AudioEffectChorus.new()
			flanger.voice_count = 1
			flanger.dry = 1.0
			flanger.wet = 0.8
			flanger.set_voice_delay_ms(0, 3.0)
			flanger.set_voice_depth_ms(0, 2.5)
			flanger.set_voice_rate_hz(0, 0.25)
			flanger.set_voice_cutoff_hz(0, 16000.0)
			return [flanger]
		"REVERB":
			return [AudioEffectReverb.new()]
		"ECHO":
			var echo := AudioEffectDelay.new()
			echo.tap1_delay_ms = 250.0
			echo.tap1_level_db = -6.0
			echo.tap1_pan = -0.4
			echo.tap2_delay_ms = 500.0
			echo.tap2_level_db = -10.0
			echo.tap2_pan = 0.4
			echo.feedback_active = true
			echo.feedback_delay_ms = 750.0
			echo.feedback_level_db = -12.0
			return [echo]
		"STADIUM":
			var reverb := AudioEffectReverb.new()
			reverb.room_size = 1.0
			reverb.damping = 0.15
			reverb.spread = 1.0
			reverb.predelay_msec = 80.0
			reverb.wet = 0.6
			reverb.dry = 0.8
			var slap := AudioEffectDelay.new()
			slap.tap1_delay_ms = 180.0
			slap.tap1_level_db = -14.0
			slap.tap2_active = false
			return [slap, reverb]
		"COMPRESSOR":
			# Hard and loud: the quiet parts come up, the drums make the rest pump
			var compressor := AudioEffectCompressor.new()
			compressor.threshold = -30.0
			compressor.ratio = 10.0
			compressor.attack_us = 500.0
			compressor.release_ms = 300.0
			compressor.gain = 14.0
			return [compressor]
		"FILTER SWEEP", "WOBBLE":
			var lowpass := AudioEffectLowPassFilter.new()
			lowpass.resonance = 0.75 if preset == "WOBBLE" else 0.6
			return [lowpass]
		"RADIO":
			# Small speaker: no bass, no treble, a bit of crunch
			var highpass := AudioEffectHighPassFilter.new()
			highpass.cutoff_hz = 500.0
			var lowpass := AudioEffectLowPassFilter.new()
			lowpass.cutoff_hz = 3000.0
			var crunch := AudioEffectDistortion.new()
			crunch.mode = AudioEffectDistortion.MODE_OVERDRIVE
			crunch.drive = 0.4
			crunch.post_gain = -6.0
			return [highpass, lowpass, crunch]
		"UNDERWATER":
			var lowpass := AudioEffectLowPassFilter.new()
			lowpass.cutoff_hz = 450.0
			lowpass.resonance = 0.7
			# A slow wide chorus makes the pitch float
			var wave := AudioEffectChorus.new()
			wave.voice_count = 2
			wave.dry = 0.3
			wave.set_voice_rate_hz(0, 0.4)
			wave.set_voice_depth_ms(0, 6.0)
			wave.set_voice_rate_hz(1, 0.55)
			wave.set_voice_depth_ms(1, 8.0)
			var reverb := AudioEffectReverb.new()
			reverb.room_size = 0.6
			reverb.wet = 0.4
			return [lowpass, wave, reverb]
		"BITCRUSH":
			# About 3 bits left, on the whole spectrum (keep_hf_hz at the top spares nothing)
			var crush := AudioEffectDistortion.new()
			crush.mode = AudioEffectDistortion.MODE_LOFI
			crush.drive = 0.92
			crush.keep_hf_hz = 20000.0
			crush.post_gain = -6.0
			return [crush]
		"MEGA BASS":
			var shelf := AudioEffectLowShelfFilter.new()
			shelf.cutoff_hz = 160.0
			shelf.gain = 3.5
			var fat := AudioEffectDistortion.new()
			fat.mode = AudioEffectDistortion.MODE_ATAN
			fat.drive = 0.25
			fat.post_gain = -8.0
			return [shelf, fat]
		"GARGLE":
			return [AudioEffectAmplify.new()]
		"8D AUDIO":
			var reverb := AudioEffectReverb.new()
			reverb.room_size = 0.5
			reverb.wet = 0.25
			return [AudioEffectPanner.new(), reverb]
		"CHIPMUNK", "MONSTER", "DRUNK":
			var shift := AudioEffectPitchShift.new()
			shift.fft_size = PITCH_FFT
			shift.pitch_scale = {"CHIPMUNK": 1.6, "MONSTER": 0.6, "DRUNK": 1.0}[preset]
			return [shift]
	return []

# The moving presets follow a clock started when they are chosen
func _process(_delta : float) -> void:
	if effects.is_empty():
		return
	var t : float = (Time.get_ticks_msec() - start_ms) / 1000.0
	match NAMES[index]:
		"FILTER SWEEP":
			# Closed to open and back in 8 s, on a log scale like a filter knob
			effects[0].cutoff_hz = 250.0 * pow(64.0, 0.5 - 0.5 * cos(TAU * t / 8.0))
		"WOBBLE":
			effects[0].cutoff_hz = 180.0 * pow(18.0, 0.5 - 0.5 * cos(TAU * t * 2.5))
		"GARGLE":
			var triangle : float = absf(fmod(t * GARGLE_HZ, 1.0) * 2.0 - 1.0)
			effects[0].volume_db = linear_to_db(maxf(triangle, 0.001))
		"8D AUDIO":
			effects[0].pan = sin(TAU * t / 4.0)
		"DRUNK":
			effects[0].pitch_scale = 1.0 + 0.06 * sin(TAU * t / 2.3) + 0.03 * sin(TAU * t / 0.9)
