extends Control

# Title screen, the first scene: the noiseBMS logo over the scrolling grid and PRESS START BUTTON.
# START, a white key, Enter or a click opens the main menu; Esc quits (not on the web).

const LOGO_FONT = preload("res://assets/font/ABSTRACT.TTF")
const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const LOGO_TEXT = "NOISEBMS"
# Red copy behind the white text, like the old TrackerMania logo (3 px at size 32)
const LOGO_SHADOW = Vector2(-3, 3) / 32.0
const LOGO_RED = Color(1, 0, 0)

const PANEL = Color(0, 0, 0, 0.7)
const TAG_BORDER = Color(0.45, 0.45, 0.45)
const ORANGE = Color(1, 0.55, 0.05)
const YELLOW = Color(1, 0.82, 0.1)

const LOGO_SIZE = 52
const INTRO_TIME = 0.6
const LEAVE_TIME = 0.35
const SOUND_VOLUME_DB = -10.0

# 0 -> 1 while the logo comes in, the red copy slides into place
var intro = 0.0
var leaving = false
var decide_sound: AudioStreamPlayer

# The logo centered on `center`, shared with the welcome screen
# The size goes down until the logo fits max_width.
static func draw_logo(canvas: CanvasItem, center: Vector2, font_size: int, max_width := INF, shadow_slide := 1.0, alpha := 1.0) -> void:
	while font_size > 8 and LOGO_FONT.get_string_size(LOGO_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		font_size -= 1
	var text_size = LOGO_FONT.get_string_size(LOGO_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent = LOGO_FONT.get_ascent(font_size)
	var descent = LOGO_FONT.get_descent(font_size)
	var at = Vector2(center.x - text_size.x / 2, center.y + (ascent - descent) / 2)
	var shadow = LOGO_SHADOW * font_size * shadow_slide
	canvas.draw_string(LOGO_FONT, at + shadow, LOGO_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(LOGO_RED, alpha))
	canvas.draw_string(LOGO_FONT, at, LOGO_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, alpha))

func _ready() -> void:
	decide_sound = AudioStreamPlayer.new()
	decide_sound.stream = preload("res://assets/music_select/decide.wav")
	decide_sound.volume_db = SOUND_VOLUME_DB
	add_child(decide_sound)
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(self, "intro", 1.0, INTRO_TIME)

func _process(_delta: float) -> void:
	queue_redraw()
	if leaving:
		return
	for player in [1, 2]:
		for action in ["start", "key1", "key3", "key5", "key7"]:
			if Input.is_action_just_pressed("p%d_%s" % [player, action]):
				start()
				return

func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: start()
			KEY_ESCAPE:
				if not OS.has_feature("web"):
					get_tree().quit()

func start() -> void:
	leaving = true
	decide_sound.play()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, LEAVE_TIME)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func draw_text(position_: Vector2, text: String, font_size: int, text_color: Color, outline := 0) -> void:
	var width = TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at = Vector2(position_.x - width / 2, position_.y)
	if outline > 0:
		draw_string_outline(TITLE_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color.BLACK)
	draw_string(TITLE_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func _draw() -> void:
	var center_x = size.x / 2
	# Dark band behind the logo
	var band = Rect2(0, size.y * 0.5 - 150, size.x, 220)
	draw_rect(band, PANEL)
	draw_rect(Rect2(0, band.position.y, size.x, 3), ORANGE)
	draw_rect(Rect2(0, band.end.y - 3, size.x, 3), ORANGE)

	var logo_y = band.get_center().y + (1.0 - intro) * 40
	draw_logo(self, Vector2(center_x, logo_y), LOGO_SIZE, size.x - 80, intro, intro)

	# PRESS START BUTTON, faster blink once pressed
	var period = 120 if leaving else 1000
	if intro >= 1.0 and Time.get_ticks_msec() % period < period * 0.65:
		draw_text(Vector2(center_x, size.y * 0.5 + 150), "PRESS START BUTTON", 28, YELLOW, 6)

	draw_text(Vector2(center_x, size.y - 28), "2024-2026 DJALEXKIDD", 12, TAG_BORDER)
