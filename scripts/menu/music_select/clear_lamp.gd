class_name ClearLamp
extends Control

# Clear lamp painted over the grey bracket at the left of a song wheel row
const GLOW_SIZE = 8
const GLOW_ALPHA = 0.8
# Light added over the lamp color so it looks lit
const CORE_ALPHA = 0.3
# Wheel lamp colors like in IIDX, in the order of Scores.LAMPS
const COLORS = [Color(1, 0.2, 0.05), Color(0.85, 0.45, 1), Color(0.2, 1, 0.2), Color(0.1, 0.75, 1), Color(1, 1, 1), Color(1, 1, 0.1), Color(1, 1, 1)]
# Grey level of the lamp in the textures, kept as the lamp's shading
const BASE_GREY = 81.0
const LAMP_LIMIT = 40

# Index in Scores.LAMPS, -1 when not played. Exported so duplicated rows keep it.
@export var lamp := -1

# Lamp body and glow textures of each row texture
static var shapes := {}

# Add a lamp under the labels of a row
static func attach(row: Control, value: int) -> void:
	var clear_lamp = ClearLamp.new()
	clear_lamp.name = "ClearLamp"
	clear_lamp.lamp = value
	row.add_child(clear_lamp)
	row.move_child(clear_lamp, 0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(lamp == 0 or lamp >= 5)

func set_lamp(value: int) -> void:
	lamp = value
	set_process(lamp == 0 or lamp >= 5)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

# Color of the lamp now: FAILED blinks slowly, FULL COMBO flashes, PERFECT cycles colors
func lamp_color() -> Color:
	var time = Time.get_ticks_msec() / 1000.0
	var color: Color = COLORS[lamp]
	match lamp:
		0:
			color.a = 0.4 + 0.6 * float(fmod(time, 1.0) < 0.5)
		5:
			color = color.lerp(Color.WHITE, 0.5 + 0.5 * sin(time * TAU * 4.0))
		6:
			color = Color.from_hsv(fmod(time * 0.8, 1.0), 0.6, 1.0)
	return color

func _draw() -> void:
	var row = get_parent() as TextureButton
	if lamp < 0 or row == null or row.texture_normal == null:
		return
	var shape = get_shape(row.texture_normal)
	if shape.is_empty():
		return
	var color = lamp_color()
	draw_texture(shape["glow"], shape["origin"] - Vector2(GLOW_SIZE, GLOW_SIZE), Color(color, color.a * GLOW_ALPHA))
	draw_texture(shape["body"], shape["origin"], color)
	draw_texture(shape["body"], shape["origin"], Color(1, 1, 1, color.a * CORE_ALPHA))

# Find the lamp by filling the light pixels from the middle of the bracket
static func get_shape(texture: Texture2D) -> Dictionary:
	if shapes.has(texture):
		return shapes[texture]
	var image = texture.get_image()
	if image.is_compressed():
		image.decompress()
	var seed = Vector2i(5, image.get_height() / 2)
	var mask := {}
	var stack: Array[Vector2i] = [seed]
	var rect = Rect2i(seed, Vector2i.ONE)
	while not stack.is_empty():
		var pixel = stack.pop_back()
		if mask.has(pixel) or not Rect2i(Vector2i.ZERO, image.get_size()).has_point(pixel):
			continue
		var source = image.get_pixelv(pixel)
		if source.a < 0.5 or maxf(source.r, maxf(source.g, source.b)) * 255.0 < LAMP_LIMIT:
			continue
		mask[pixel] = source.get_luminance() * 255.0 / BASE_GREY
		rect = rect.expand(pixel).expand(pixel + Vector2i.ONE)
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			stack.append(pixel + step)
	if mask.size() < 2:
		shapes[texture] = {}
		return {}
	var body = Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	for pixel in mask:
		var shade = minf(mask[pixel], 1.3)
		body.set_pixelv(pixel - rect.position, Color(shade, shade, shade))
	# Soft halo fading out GLOW_SIZE pixels around the lamp
	var glow = Image.create_empty(rect.size.x + GLOW_SIZE * 2, rect.size.y + GLOW_SIZE * 2, false, Image.FORMAT_RGBA8)
	var strengths = PackedFloat32Array()
	strengths.resize(glow.get_width() * glow.get_height())
	for pixel in mask:
		var center = pixel - rect.position + Vector2i(GLOW_SIZE, GLOW_SIZE)
		for dy in range(-GLOW_SIZE, GLOW_SIZE + 1):
			for dx in range(-GLOW_SIZE, GLOW_SIZE + 1):
				var strength = 1.0 - Vector2(dx, dy).length() / (GLOW_SIZE + 1.0)
				var index = (center.y + dy) * glow.get_width() + center.x + dx
				if strength > strengths[index]:
					strengths[index] = strength
	for index in strengths.size():
		glow.set_pixel(index % glow.get_width(), index / glow.get_width(), Color(1, 1, 1, strengths[index] * strengths[index]))
	shapes[texture] = {
		"origin": Vector2(rect.position),
		"body": ImageTexture.create_from_image(body),
		"glow": ImageTexture.create_from_image(glow),
	}
	return shapes[texture]
