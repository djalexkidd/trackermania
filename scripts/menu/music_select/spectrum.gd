extends Control

# Bar visualizer of the song preview, like the lock screen of CyanogenMod: plain pale bars
# rising from the bottom bar, behind the song info, from the left edge to the song wheel.
# Reads the spectrum analyzer of the Preview bus.

const BARS = 32
const MIN_HZ = 40.0
const MAX_HZ = 16000.0
# Magnitudes from MIN_DB (empty bar) to 0 dB (full bar)
const MIN_DB = -60.0
# The high bars are raised up to this, the treble is much quieter than the bass (dB)
const TREBLE_BOOST = 12.0
const BAR_GAP = 3.0
# The bars follow the sound smoothly, up and down (higher = faster)
const RISE_SPEED = 18.0
const FALL_SPEED = 8.0
# The whole visualizer fades in and out with the preview
const SHOW_SPEED = 4.0

const COLOR = Color(0.72, 0.78, 0.86, 0.35)

var song_preview: Node
# Hidden with the song info (under the P2 game options)
var song_info: Control
var analyzer: AudioEffectSpectrumAnalyzerInstance
var levels := PackedFloat32Array()
var shown = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	levels.resize(BARS)

func _process(delta: float) -> void:
	if analyzer == null:
		analyzer = song_preview.analyzer()
	var playing = song_preview.player != null and analyzer != null
	shown = move_toward(shown, 1.0 if playing else 0.0, SHOW_SPEED * delta)
	modulate.a = shown
	for i in BARS:
		var target = bar_level(i) * song_preview.fade if playing else 0.0
		var speed = RISE_SPEED if target > levels[i] else FALL_SPEED
		levels[i] = lerpf(levels[i], target, 1.0 - exp(-speed * delta))
	queue_redraw()

# Level 0~1 of a bar, its frequencies are spaced logarithmically
func bar_level(i: int) -> float:
	var from = MIN_HZ * pow(MAX_HZ / MIN_HZ, float(i) / BARS)
	var to = MIN_HZ * pow(MAX_HZ / MIN_HZ, float(i + 1) / BARS)
	var magnitude = analyzer.get_magnitude_for_frequency_range(from, to, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX)
	var db = linear_to_db(maxf(magnitude.length(), 0.00001)) + TREBLE_BOOST * i / (BARS - 1)
	return clampf((db - MIN_DB) / -MIN_DB, 0.0, 1.0)

func _draw() -> void:
	if shown <= 0.0 or not song_info.visible:
		return
	var bar_width = (size.x - BAR_GAP * (BARS - 1)) / BARS
	for i in BARS:
		var height = roundf(levels[i] * size.y)
		if height >= 1.0:
			draw_rect(Rect2(i * (bar_width + BAR_GAP), size.y - height, bar_width, height), COLOR)
