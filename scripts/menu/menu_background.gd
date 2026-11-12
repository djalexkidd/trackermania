extends TextureRect
class_name MenuBackground

# Animated background of the menus, chosen in the CUSTOMIZE menu (Global.menu_background):
# GRID is grid.png scrolling with scroll.gdshader (set in the scenes), CUBE the inside of an orange
# wireframe cube turning slowly, drawn in _draw(). It follows the setting while the scene is open.

const GRID = preload("res://assets/backgrounds/grid.png")
# UV per second of scroll.gdshader
const GRID_SPEED = 0.1
# The grid fills the 1280 px of the screen, as in the scenes
const SCREEN_WIDTH = 1280.0

# Cube: cells of a face, dotted lines in a cell, dots on a line, pieces of a solid line (for the fading)
const CUBE_CELLS = 6
const CUBE_SUBDIVISIONS = 2
const CUBE_DOTS = 30
const CUBE_PIECES = 8
# Turns of the camera in radians per second around x, y and z, and its starting angle
const CUBE_SPIN = Vector3(0.045, 0.08, 0.025)
const CUBE_START = Vector3(0.5, 0.3, 0.2)
# Focal length in screen widths, near plane of the camera
const CUBE_FOCAL = 0.5
const CUBE_NEAR = 0.05
# Lines fade from the nearest wall (distance 1) to the corners (distance sqrt(3))
const CUBE_FAR_ALPHA = 0.3
const ORANGE = Color(1, 0.5, 0.05)
const BRIGHT = Color(1, 0.75, 0.25)

var mode := ""
var grid_material: Material

func _ready() -> void:
	grid_material = material
	apply(Global.menu_background)

func _process(_delta: float) -> void:
	if Global.menu_background != mode:
		apply(Global.menu_background)
	if mode == "cube":
		queue_redraw()

func apply(id: String) -> void:
	mode = Skins.find(Skins.BACKGROUNDS, id)["id"]
	var cube = mode == "cube"
	texture = null if cube else GRID
	material = null if cube else grid_material
	queue_redraw()

func _draw() -> void:
	if mode == "cube":
		draw_cube(self, Rect2(Vector2.ZERO, size), Time.get_ticks_msec() / 1000.0)

# A background drawn in a rectangle (preview of the CUSTOMIZE menu)
static func draw_background(canvas: CanvasItem, id: String, rect: Rect2, time: float) -> void:
	if Skins.find(Skins.BACKGROUNDS, id)["id"] == "cube":
		draw_cube(canvas, rect, time)
	else:
		draw_grid(canvas, rect, time)

# grid.png scrolling up and left like scroll.gdshader, at the scale of the rectangle (to clip)
static func draw_grid(canvas: CanvasItem, rect: Rect2, time: float) -> void:
	canvas.draw_rect(rect, Color.BLACK)
	var tile := GRID.get_size() * rect.size.x / SCREEN_WIDTH
	var offset := Vector2(fposmod(time * GRID_SPEED, 1.0), fposmod(time * GRID_SPEED, 1.0)) * tile
	var rows := ceili(rect.size.y / tile.y) + 1
	var columns := ceili(rect.size.x / tile.x) + 1
	var scale := GRID.get_size() / tile
	for row in rows:
		for column in columns:
			var tile_rect := Rect2(rect.position - offset + Vector2(column, row) * tile, tile)
			var shown := tile_rect.intersection(rect)
			if shown.has_area():
				canvas.draw_texture_rect_region(GRID, shown, Rect2((shown.position - tile_rect.position) * scale, shown.size * scale))

# Inside of a cube whose walls are orange grids: solid lines on the cells, dotted ones between them,
# some cells lit, everything fading with the distance. The camera turns at the center.
static func draw_cube(canvas: CanvasItem, rect: Rect2, time: float) -> void:
	canvas.draw_rect(rect, Color.BLACK)
	var basis := Basis.from_euler(CUBE_START + CUBE_SPIN * time)
	var view := CubeView.new(basis, rect, rect.size.x * CUBE_FOCAL)
	var solid := PackedVector2Array()
	var solid_colors := PackedColorArray()
	var dots := PackedVector2Array()
	var dot_colors := PackedColorArray()
	var lines := CUBE_CELLS * CUBE_SUBDIVISIONS
	for axis in 3:
		var u := Vector3.ZERO
		var v := Vector3.ZERO
		u[(axis + 1) % 3] = 1.0
		v[(axis + 2) % 3] = 1.0
		for side in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			draw_cells(canvas, view, normal, u, v, time)
			for i in lines + 1:
				var c := -1.0 + 2.0 * i / lines
				for direction in [[u, v], [v, u]]:
					var a: Vector3 = normal + direction[0] * c - direction[1]
					var b: Vector3 = normal + direction[0] * c + direction[1]
					if i % CUBE_SUBDIVISIONS == 0:
						view.add_line(a, b, CUBE_PIECES, solid, solid_colors, 1.0)
					else:
						view.add_dots(a, b, CUBE_DOTS, dots, dot_colors, 0.7)
	if not dots.is_empty():
		canvas.draw_multiline_colors(dots, dot_colors, 1.5)
	if not solid.is_empty():
		# A wide glow, then the line
		var glow := PackedColorArray()
		for color in solid_colors:
			glow.append(Color(color, color.a * 0.18))
		canvas.draw_multiline_colors(solid, glow, 7.0)
		canvas.draw_multiline_colors(solid, solid_colors, 2.0)

# Some cells of a wall lit in dark orange, pulsing slowly
static func draw_cells(canvas: CanvasItem, view: CubeView, normal: Vector3, u: Vector3, v: Vector3, time: float) -> void:
	var cell := 2.0 / CUBE_CELLS
	for i in CUBE_CELLS:
		for j in CUBE_CELLS:
			var hash_ := absi(hash(Vector3(normal) * 7.0 + Vector3(i, j, 0)))
			if hash_ % 7 != 0:
				continue
			var corner := normal - u - v + u * (i * cell) + v * (j * cell)
			var points := PackedVector2Array()
			var depth := 0.0
			for k in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var p: Vector3 = corner + u * (k.x * cell) + v * (k.y * cell)
				var projected = view.project(p)
				if projected == null:
					break
				points.append(projected)
				depth += p.length() / 4.0
			# Only the cells entirely in front of the camera
			if points.size() < 4:
				continue
			var shown := Geometry2D.intersect_polygons(points, view.clip_polygon)
			if shown.is_empty():
				continue
			points = shown[0]
			var pulse := 0.6 + 0.4 * sin(time * 1.3 + hash_ % 100)
			var alpha := 0.35 * pulse * view.fade(depth)
			canvas.draw_colored_polygon(points, Color(Skins.DARK_ORANGE.lerp(ORANGE, 0.4), alpha))

# Camera of the cube: rotation, center of the screen and focal length in px
class CubeView:
	var basis: Basis
	var center: Vector2
	var focal: float
	# Everything is clipped to the rectangle of the background
	var clip: Rect2
	var clip_polygon: PackedVector2Array

	func _init(basis_: Basis, rect: Rect2, focal_: float) -> void:
		basis = basis_
		center = rect.get_center()
		focal = focal_
		clip = rect
		clip_polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

	# Adds the part of a segment inside the rectangle (Liang-Barsky), false if none
	func add_segment(a: Vector2, b: Vector2, points: PackedVector2Array) -> bool:
		var d := b - a
		var t0 := 0.0
		var t1 := 1.0
		for edge in [[-d.x, a.x - clip.position.x], [d.x, clip.end.x - a.x], [-d.y, a.y - clip.position.y], [d.y, clip.end.y - a.y]]:
			if edge[0] == 0.0:
				if edge[1] < 0.0:
					return false
				continue
			var t: float = edge[1] / edge[0]
			if edge[0] < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
		if t0 > t1:
			return false
		points.append(a + d * t0)
		points.append(a + d * t1)
		return true

	# A point on the screen, null behind the camera
	func project(world: Vector3):
		var p := basis * world
		if p.z < CUBE_NEAR:
			return null
		return center + Vector2(p.x, -p.y) / p.z * focal

	func project_camera(p: Vector3) -> Vector2:
		return center + Vector2(p.x, -p.y) / p.z * focal

	func fade(distance: float) -> float:
		return lerpf(1.0, CUBE_FAR_ALPHA, clampf((distance - 1.0) / (sqrt(3.0) - 1.0), 0.0, 1.0))

	# A solid line cut in pieces, each with the brightness of its distance, clipped at the near plane
	func add_line(a: Vector3, b: Vector3, pieces: int, points: PackedVector2Array, colors: PackedColorArray, alpha: float) -> void:
		for k in pieces:
			var p1 := a.lerp(b, float(k) / pieces)
			var p2 := a.lerp(b, float(k + 1) / pieces)
			var c1 := basis * p1
			var c2 := basis * p2
			if c1.z < CUBE_NEAR and c2.z < CUBE_NEAR:
				continue
			if c1.z < CUBE_NEAR:
				c1 = c1.lerp(c2, (CUBE_NEAR - c1.z) / (c2.z - c1.z))
			elif c2.z < CUBE_NEAR:
				c2 = c2.lerp(c1, (CUBE_NEAR - c2.z) / (c1.z - c2.z))
			if not add_segment(project_camera(c1), project_camera(c2), points):
				continue
			var f := fade((p1.length() + p2.length()) / 2.0)
			colors.append(Color(ORANGE.lerp(BRIGHT, f * f), alpha * f))

	# A dotted line: short dashes that shrink with the perspective
	func add_dots(a: Vector3, b: Vector3, count: int, points: PackedVector2Array, colors: PackedColorArray, alpha: float) -> void:
		for k in count:
			var p1 := a.lerp(b, (k + 0.3) / count)
			var p2 := a.lerp(b, (k + 0.6) / count)
			var c1 := basis * p1
			var c2 := basis * p2
			if c1.z < CUBE_NEAR or c2.z < CUBE_NEAR:
				continue
			if not add_segment(project_camera(c1), project_camera(c2), points):
				continue
			colors.append(Color(ORANGE, alpha * fade(p1.length())))
