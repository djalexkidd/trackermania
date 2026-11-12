class_name Skins

# Customizations chosen in the CUSTOMIZE menu (customization_menu.gd), saved in Global:
# the frame of the playfield (colors of the lanes and of the metal), the turntable disc,
# the animated background of the menus and the BGM of the music select.

# Frames: colors of the lanes, the rails and the plate; "keys" tints the key and scratch frames
const FRAMES = [
	{"id": "standard", "name": "STANDARD",
		"lane": Color(0, 0, 0), "lane_black": Color(0.035, 0.035, 0.045), "lane_gap": Color(0.1, 0.1, 0.11), "separator": Color(0.22, 0.22, 0.25),
		"beam": Color(0.25, 0.55, 1.0), "burst": Color(0.6, 0.85, 1.0),
		"metal_light": Color(0.8, 0.82, 0.86), "metal_dark": Color(0.36, 0.38, 0.43), "metal_edge": Color(0.1, 0.1, 0.12),
		"screen": Color(0.02, 0.025, 0.035), "screen_glow": Color(0.2, 0.75, 1.0, 0.35),
		"cover_top": Color(0.2, 0.21, 0.24), "cover_bottom": Color(0.09, 0.09, 0.11), "keys": Color(1, 1, 1)},
	{"id": "carbon", "name": "CARBON",
		"lane": Color(0, 0, 0), "lane_black": Color(0.05, 0.05, 0.05), "lane_gap": Color(0.14, 0.14, 0.14), "separator": Color(0.28, 0.28, 0.28),
		"beam": Color(1.0, 0.5, 0.08), "burst": Color(1.0, 0.8, 0.5),
		"metal_light": Color(0.34, 0.34, 0.36), "metal_dark": Color(0.1, 0.1, 0.11), "metal_edge": Color(0, 0, 0),
		"screen": Color(0.01, 0.01, 0.01), "screen_glow": Color(1.0, 0.55, 0.1, 0.35),
		"cover_top": Color(0.16, 0.16, 0.17), "cover_bottom": Color(0.06, 0.06, 0.06), "keys": Color(0.55, 0.55, 0.58)},
	{"id": "blaze", "name": "BLAZE",
		"lane": Color(0.03, 0.01, 0), "lane_black": Color(0.08, 0.03, 0), "lane_gap": Color(0.22, 0.08, 0), "separator": Color(0.42, 0.18, 0.04),
		"beam": Color(1.0, 0.45, 0.05), "burst": Color(1.0, 0.85, 0.4),
		"metal_light": Color(1.0, 0.62, 0.2), "metal_dark": Color(0.55, 0.2, 0.02), "metal_edge": Color(0.15, 0.05, 0),
		"screen": Color(0.04, 0.015, 0), "screen_glow": Color(1.0, 0.6, 0.1, 0.4),
		"cover_top": Color(0.35, 0.14, 0.03), "cover_bottom": Color(0.15, 0.05, 0), "keys": Color(1.0, 0.75, 0.5)},
	{"id": "neon", "name": "NEON",
		"lane": Color(0.02, 0, 0.04), "lane_black": Color(0.05, 0, 0.09), "lane_gap": Color(0.15, 0, 0.25), "separator": Color(0.45, 0.1, 0.6),
		"beam": Color(1.0, 0.2, 0.8), "burst": Color(1.0, 0.6, 1.0),
		"metal_light": Color(0.95, 0.4, 1.0), "metal_dark": Color(0.25, 0.05, 0.4), "metal_edge": Color(0.05, 0, 0.1),
		"screen": Color(0.02, 0, 0.05), "screen_glow": Color(0.3, 1.0, 1.0, 0.45),
		"cover_top": Color(0.2, 0.05, 0.3), "cover_bottom": Color(0.08, 0, 0.14), "keys": Color(0.85, 0.65, 1.0)},
	{"id": "gold", "name": "GOLD",
		"lane": Color(0, 0, 0), "lane_black": Color(0.05, 0.04, 0.02), "lane_gap": Color(0.2, 0.16, 0.05), "separator": Color(0.4, 0.33, 0.12),
		"beam": Color(1.0, 0.85, 0.3), "burst": Color(1.0, 0.95, 0.6),
		"metal_light": Color(1.0, 0.9, 0.5), "metal_dark": Color(0.55, 0.4, 0.1), "metal_edge": Color(0.18, 0.12, 0),
		"screen": Color(0.03, 0.025, 0.01), "screen_glow": Color(1.0, 0.85, 0.3, 0.35),
		"cover_top": Color(0.3, 0.25, 0.1), "cover_bottom": Color(0.12, 0.1, 0.04), "keys": Color(1.0, 0.92, 0.65)},
	{"id": "frost", "name": "FROST",
		"lane": Color(0, 0.02, 0.04), "lane_black": Color(0.02, 0.05, 0.09), "lane_gap": Color(0.1, 0.18, 0.25), "separator": Color(0.3, 0.45, 0.55),
		"beam": Color(0.5, 0.9, 1.0), "burst": Color(0.8, 0.95, 1.0),
		"metal_light": Color(0.9, 0.97, 1.0), "metal_dark": Color(0.4, 0.6, 0.75), "metal_edge": Color(0.05, 0.1, 0.15),
		"screen": Color(0.01, 0.03, 0.05), "screen_glow": Color(0.5, 0.9, 1.0, 0.4),
		"cover_top": Color(0.25, 0.35, 0.42), "cover_bottom": Color(0.1, 0.15, 0.2), "keys": Color(0.8, 0.92, 1.0)},
]

# Turntable discs: the game art, then discs drawn by make_disc()
const TURNTABLES = [
	{"id": "standard", "name": "STANDARD"},
	{"id": "vinyl", "name": "VINYL"},
	{"id": "hazard", "name": "HAZARD"},
	{"id": "spiral", "name": "SPIRAL"},
	{"id": "chrome", "name": "CHROME"},
	{"id": "pixel", "name": "8-BIT"},
]
const DISC_ART = preload("res://assets/play/p1_turntable_disc.png")
# Size of the drawn discs, the same as the art so that they take its place
const DISC_SIZE = 104

# Animated backgrounds of the menus (menu_background.gd)
const BACKGROUNDS = [
	{"id": "grid", "name": "GRID"},
	{"id": "cube", "name": "CUBE"},
	{"id": "tunnel", "name": "TUNNEL"},
	{"id": "klein", "name": "KLEIN"},
	{"id": "warp", "name": "WARP"},
	{"id": "horizon", "name": "HORIZON"},
]

# Colors of the game
const ORANGE = Color(1, 0.55, 0.05)
const DARK_ORANGE = Color(0.45, 0.18, 0)
const YELLOW = Color(1, 0.82, 0.1)

static var discs := {}

static func find(list: Array, id: String) -> Dictionary:
	for entry in list:
		if entry["id"] == id:
			return entry
	return list[0]

# Frame chosen in the CUSTOMIZE menu
static func frame() -> Dictionary:
	return find(FRAMES, Global.frame_skin)

static func disc_texture(id: String) -> Texture2D:
	id = find(TURNTABLES, id)["id"]
	if id == "standard":
		return DISC_ART
	if not discs.has(id):
		discs[id] = make_disc(id)
	return discs[id]

# A disc drawn pixel by pixel, its marker at the top like the game art
static func make_disc(id: String) -> ImageTexture:
	var image := Image.create(DISC_SIZE, DISC_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(DISC_SIZE, DISC_SIZE) / 2.0
	var radius := DISC_SIZE / 2.0 - 1.0
	for y in DISC_SIZE:
		for x in DISC_SIZE:
			var at := Vector2(x + 0.5, y + 0.5)
			# The 8-bit disc is made of big square pixels
			if id == "pixel":
				at = (at / 8.0).floor() * 8.0 + Vector2(4, 4)
			var offset := at - center
			var r := offset.length()
			var coverage := clampf(radius - r + 0.5, 0.0, 1.0)
			if id == "pixel":
				coverage = 1.0 if r <= radius else 0.0
			if coverage <= 0.0:
				continue
			# Angle from the top, clockwise
			var angle := fposmod(atan2(offset.x, -offset.y), TAU)
			var color := disc_color(id, offset, r, angle, radius)
			color.a *= coverage
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

static func disc_color(id: String, offset: Vector2, r: float, angle: float, radius: float) -> Color:
	match id:
		"vinyl":
			# Grooves with a light sheen, an orange label and a white marker
			if r > radius - 3:
				return Color(0.18, 0.18, 0.2)
			if absf(offset.x) < 1.5 and offset.y < 0 and r > radius - 10:
				return Color.WHITE
			if r < 3:
				return Color(0.05, 0.05, 0.05)
			if r < 19:
				if absf(offset.x) < 1.5 and offset.y < -5:
					return Color.WHITE
				return ORANGE if r < 17 else DARK_ORANGE
			var groove := 0.05 + 0.04 * (int(r) % 2)
			var sheen := 0.12 * pow(absf(cos(angle - 0.7)), 24.0)
			return Color(groove + sheen, groove + sheen, groove + sheen * 1.1)
		"hazard":
			# Yellow and black slanted stripes around a dark plate
			if r > radius - 12:
				var stripe := fposmod(angle / TAU * 20.0 + r * 0.12, 1.0)
				return YELLOW if stripe < 0.5 else Color(0.06, 0.06, 0.06)
			if r > radius - 15:
				return Color(0.02, 0.02, 0.02)
			if r < 13:
				if absf(offset.x) < 2.5 and offset.y < -3:
					return Color(0.06, 0.06, 0.06)
				return YELLOW
			var plate := 0.13 + 0.05 * offset.y / radius
			return Color(plate, plate, plate * 1.05)
		"spiral":
			# Two orange arms turning to the center
			if r > radius - 3:
				return Color(0.3, 0.3, 0.33)
			if r < 8:
				return Color.WHITE if r > 3 else Color(0.05, 0.05, 0.05)
			var arm := fposmod(angle / TAU * 2.0 - r / 26.0, 1.0)
			if arm < 0.28:
				return ORANGE.lerp(YELLOW, arm / 0.28)
			return Color(0.06, 0.03, 0.02).lerp(DARK_ORANGE, maxf(0.0, 1.0 - (arm - 0.28) * 4.0))
		"chrome":
			# Brushed silver with a red pointer
			if absf(offset.x) < 2.5 and offset.y < -10 and r < radius - 5:
				return Color(0.95, 0.12, 0.1)
			if r < 6:
				return Color(0.1, 0.1, 0.12)
			if absf(r - radius * 0.62) < 1.0 or r > radius - 2:
				return Color(0.25, 0.26, 0.3)
			var light := 0.6 + 0.25 * cos(angle * 2.0 + 0.6) + 0.04 * sin(r * 1.7)
			return Color(light, light * 1.01, light * 1.06)
		"pixel":
			# Amstrad CPC colors, like the loading screen
			var ring := int(r / 8.0)
			if offset.y < -24 and absf(offset.x) < 5:
				return Color.WHITE
			if ring >= 5:
				return Color(1, 1, 0.2)
			if ring == 0:
				return Color(1, 1, 0.2)
			if ring == 3:
				return Color(0.0, 0.5, 1.0) if int((angle / TAU) * 12.0) % 2 == 0 else Color(0, 0, 0.5)
			return Color(0, 0, 0.5)
	return Color.BLACK
