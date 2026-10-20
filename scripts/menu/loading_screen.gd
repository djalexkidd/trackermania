extends CanvasLayer
# Amstrad CPC "NOW LOADING..." screen shown over a scene while it loads.
# finish() makes the character run to the right, erasing the text, then the
# blue screen leaves in horizontal bands to the right like an IIDX wipe.

const BACKGROUND = Color8(0, 0, 100)
const YELLOW = Color8(255, 255, 0)
const TEXT = "NOW LOADING..."
const FONT_SIZE = 32
# Every sprite and font pixel is 4x4 screen pixels, like the CPC text mode
const PIXEL = 4
const MARGIN = Vector2(64, 64)
const GAP = 16
const CURSOR_BLINK = 0.4
const WALK_FPS = 6.0
const RUN_FPS = 16.0
const RUN_SPEED = 1100.0
# Shown at least this long, so a quick load does not just flash
const MIN_TIME = 0.8
const BANDS = 12
const BAND_DELAY = 0.025
const BAND_TIME = 0.3

signal finished

var frames: Array[Texture2D] = [
	preload("res://assets/loading/walk.0.png"),
	preload("res://assets/loading/walk.1.png"),
	preload("res://assets/loading/walk.2.png"),
]
var font: Font = preload("res://assets/font/amstrad_cpc464.ttf")
var canvas := Control.new()
var time := 0.0
var running := false
var run_x := 0.0
var run_frame := 0.0
var wipe_time := -1.0

func _ready() -> void:
	layer = 100
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_screen)
	add_child(canvas)

# Runs out once the loading is done, returns when the screen starts to leave
func finish() -> void:
	while time < MIN_TIME:
		await get_tree().process_frame
	running = true
	run_x = character_position().x
	while run_x < canvas.size.x:
		await get_tree().process_frame
	wipe_time = 0.0
	# The scene behind takes input again while the bands leave
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	time += delta
	if running:
		run_x += RUN_SPEED * delta
		run_frame += RUN_FPS * delta
	if wipe_time >= 0.0:
		wipe_time += delta
		if wipe_time > BAND_TIME + BAND_DELAY * BANDS:
			finished.emit()
			queue_free()
	canvas.queue_redraw()

func sprite_size() -> Vector2:
	return frames[0].get_size() * PIXEL

# Bottom right: the character, then the text and its cursor
func character_position() -> Vector2:
	var text_width = (TEXT.length() + 1) * FONT_SIZE
	var width = sprite_size().x + GAP + text_width
	return (canvas.size - MARGIN - Vector2(width, sprite_size().y)).snapped(Vector2(PIXEL, PIXEL))

func _draw_screen() -> void:
	draw_background()
	if wipe_time >= 0.0:
		return
	var origin = character_position()
	# Text baseline on the character's feet
	var baseline = origin.y + sprite_size().y
	var text_x = origin.x + sprite_size().x + GAP
	# The running character erases each letter it passes over
	var erased_x = run_x + sprite_size().x * 0.5 if running else -INF
	for i in TEXT.length():
		var x = text_x + i * FONT_SIZE
		if x + FONT_SIZE * 0.5 > erased_x:
			canvas.draw_string(font, Vector2(x, baseline), TEXT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, YELLOW)
	var cursor_x = text_x + TEXT.length() * FONT_SIZE
	if cursor_x + FONT_SIZE * 0.5 > erased_x and (running or fmod(time, CURSOR_BLINK * 2) < CURSOR_BLINK):
		canvas.draw_rect(Rect2(cursor_x, baseline - FONT_SIZE, FONT_SIZE, FONT_SIZE), YELLOW)
	# Walk in place (0 1 2 1), then run
	var step = int(run_frame) if running else int(time * WALK_FPS)
	var frame = [0, 1, 2, 1][step % 4]
	var sprite_position = Vector2(run_x, origin.y) if running else origin
	canvas.draw_texture_rect(frames[frame], Rect2(sprite_position, sprite_size()), false)

# Each band slides out to the right, the ones near the character first
func draw_background() -> void:
	if wipe_time < 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), BACKGROUND)
		return
	var band_height = ceilf(canvas.size.y / BANDS)
	var start_band = int(character_position().y / band_height)
	for band in BANDS:
		var t = clampf((wipe_time - absi(band - start_band) * BAND_DELAY) / BAND_TIME, 0.0, 1.0)
		var x = canvas.size.x * t * t * t
		if x >= canvas.size.x:
			continue
		var rect = Rect2(x, band * band_height, canvas.size.x - x, band_height)
		canvas.draw_rect(rect, BACKGROUND)
		# Yellow leading edge while the band moves
		if t > 0.0:
			canvas.draw_rect(Rect2(x, rect.position.y, PIXEL * 2, band_height), YELLOW)
