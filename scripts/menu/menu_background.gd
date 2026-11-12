extends TextureRect
class_name MenuBackground

# Animated background of the menus, chosen in the CUSTOMIZE menu (Global.menu_background):
# GRID is grid.png scrolling with scroll.gdshader (set in the scenes), CUBE the inside of an orange
# wireframe cube turning slowly, TUNNEL a red wireframe of the xscreensaver hack "atunnel", both drawn in _draw().
# It follows the setting while the scene is open.

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

# TUNNEL, after "atunnel" of xscreensaver (tunnel_draw.c):
#   Copyright (c) E. Lassauge, 2002-2004. Original code by Roman Podobedov.
#   Permission to use, copy, modify, and distribute this software and its documentation for any purpose
#   and without fee is hereby granted, provided that the above copyright notice appear in all copies and
#   that both that copyright notice and this permission notice appear in supporting documentation.
#   This file is provided AS IS with no warranties of any kind.
# Rings of 10 sides around a Catmull-Rom curve through these points. Unlike the hack, the path repeats
# without end (each copy TUNNEL_REPEAT further on x), the camera goes at a steady speed along it and
# looks at a point well ahead, so that it turns smoothly.
const TUNNEL_PATH = [
	Vector3(0, 0, 0), Vector3(2, 1, 0), Vector3(4, 0, 0), Vector3(6, 1, 0), Vector3(8, 0, 1), Vector3(10, 1, 1),
	Vector3(12, 1.5, 0), Vector3(14, 0, 0), Vector3(16, 1, 0), Vector3(18, 0, 0), Vector3(20, 0, 1), Vector3(22, 1, 0),
	Vector3(24, 0, 1), Vector3(26, 0, 1), Vector3(28, 1, 0), Vector3(30, 0, 2), Vector3(32, 1, 0), Vector3(34, 0, 2),
]
const TUNNEL_REPEAT = Vector3(36, 0, 0)
const TUNNEL_RADIUS = 0.25
const TUNNEL_SIDES = 10
# Rings on each curve, curves drawn from the camera on
const TUNNEL_RINGS = 10
const TUNNEL_AHEAD = 3
# Speed along the path in units per second, roll in radians per second
const TUNNEL_SPEED = 0.9
const TUNNEL_ROLL = 0.25
# The camera looks at the mean of points from TUNNEL_LOOK_FROM to TUNNEL_LOOK_TO units ahead
const TUNNEL_LOOK_FROM = 0.4
const TUNNEL_LOOK_TO = 1.6
const TUNNEL_LOOK_SAMPLES = 6
# Samples of each curve for the length of the path
const TUNNEL_SAMPLES = 32
# Vertical field of view of 90 degrees (glFrustum of the hack), exponential fog of density 0.3
const TUNNEL_NEAR = 0.1
const TUNNEL_FOG = 0.3
const RED = Color(1, 0.08, 0.06)
const PALE_RED = Color(1, 0.55, 0.5)

# KLEIN, after "klein" of xscreensaver (klein.c), in red wireframe:
#   Copyright (c) 2005-2026 Carsten Steger <carsten@mirsanmir.org>.
#   Permission to use, copy, modify, and distribute this software and its documentation for any purpose
#   and without fee is hereby granted, provided that the above copyright notice appear in all copies and
#   that both that copyright notice and this permission notice appear in supporting documentation.
#   This file is provided AS IS with no warranties of any kind.
# The figure-8 Klein bottle of the hack (projected from 4d orthographically: the classic figure-8 bottle).
# Its tube has a figure-8 cross-section that turns half a turn around the ring, and goes through itself
# along the middle of the 8. The camera flies inside one loop of the 8, drawn bright ahead of it; the other
# loop is drawn dim. After one turn of the ring the camera is in the other loop, after two at its start.
# Lines of the mesh around the tube (u, even) and along the ring (v, per turn)
const KLEIN_LINES_U = 24
const KLEIN_LINES_V = 64
# Turns of the ring drawn ahead of the camera (radians of v), and behind it
const KLEIN_AHEAD = 2.6
const KLEIN_BEHIND = 0.15
# Brightness of the other loop of the 8
const KLEIN_OTHER_LOOP = 0.18
# v in radians per second, roll of the camera in radians per second
const KLEIN_SPEED = 0.22
const KLEIN_ROLL = 0.12
# The camera looks at the middle of its loop this far ahead on the ring (radians of v)
const KLEIN_LOOK_AHEAD = 0.3
# Middle of a loop of the 8 in its own coordinates (sin u, sin 2u): the farthest point from its sides
const KLEIN_LOOP_CENTER = 0.53
const KLEIN_FOV = 70.0
const KLEIN_NEAR = 0.01
const KLEIN_FOG = 1.3

var mode := ""
var grid_material: Material

func _ready() -> void:
	grid_material = material
	apply(Global.menu_background)

func _process(_delta: float) -> void:
	if Global.menu_background != mode:
		apply(Global.menu_background)
	if mode != "grid":
		queue_redraw()

func apply(id: String) -> void:
	mode = Skins.find(Skins.BACKGROUNDS, id)["id"]
	var drawn = mode != "grid"
	texture = null if drawn else GRID
	material = null if drawn else grid_material
	queue_redraw()

func _draw() -> void:
	if mode != "grid":
		draw_background(self, mode, Rect2(Vector2.ZERO, size), Time.get_ticks_msec() / 1000.0)

# A background drawn in a rectangle (preview of the CUSTOMIZE menu)
static func draw_background(canvas: CanvasItem, id: String, rect: Rect2, time: float) -> void:
	match Skins.find(Skins.BACKGROUNDS, id)["id"]:
		"cube": draw_cube(canvas, rect, time)
		"tunnel": draw_tunnel(canvas, rect, time)
		"klein": draw_klein(canvas, rect, time)
		_: draw_grid(canvas, rect, time)

# Distance along the path at the end of each sample of a repeat of it, built once
static var tunnel_lengths := PackedFloat32Array()

# Control point i of the endless path
static func tunnel_control(i: int) -> Vector3:
	var n := TUNNEL_PATH.size()
	return TUNNEL_PATH[posmod(i, n)] + TUNNEL_REPEAT * floori(float(i) / n)

# Point of curve "curve" of the path (between its control points curve + 1 and curve + 2), t from 0 to 1
static func tunnel_point(curve: int, t: float) -> Vector3:
	var p0 := tunnel_control(curve)
	var p1 := tunnel_control(curve + 1)
	var p2 := tunnel_control(curve + 2)
	var p3 := tunnel_control(curve + 3)
	var t2 := t * t
	var t3 := t2 * t
	var t1 := (1.0 - t) * (1.0 - t)
	return (-t * t1 * p0 + (2.0 - 5.0 * t2 + 3.0 * t3) * p1 + t * (1.0 + 4.0 * t - 3.0 * t2) * p2 - t2 * (1.0 - t) * p3) / 2.0

static func tunnel_length() -> float:
	if tunnel_lengths.is_empty():
		var total := 0.0
		var previous := tunnel_point(0, 0.0)
		for k in TUNNEL_PATH.size() * TUNNEL_SAMPLES:
			var point := tunnel_point(k / TUNNEL_SAMPLES, float(k % TUNNEL_SAMPLES + 1) / TUNNEL_SAMPLES)
			total += point.distance_to(previous)
			previous = point
			tunnel_lengths.append(total)
	return tunnel_lengths[-1]

# Curve and t at a distance along the endless path, as a float: curve + t
static func tunnel_at(distance: float) -> float:
	var length := tunnel_length()
	var repeats := floorf(distance / length)
	distance -= repeats * length
	var k := tunnel_lengths.bsearch(distance)
	var start := tunnel_lengths[k - 1] if k > 0 else 0.0
	var fraction := (distance - start) / maxf(tunnel_lengths[k] - start, 1e-6)
	return repeats * TUNNEL_PATH.size() + (k + fraction) / TUNNEL_SAMPLES

static func tunnel_point_at(position: float) -> Vector3:
	var curve := floori(position)
	return tunnel_point(curve, position - curve)

# Red wireframe of the tunnel: the rings and the lines between them, fading in the fog
static func draw_tunnel(canvas: CanvasItem, rect: Rect2, time: float) -> void:
	canvas.draw_rect(rect, Color.BLACK)
	# Wrapped to one repeat of the path: everything is drawn from the camera, the same in each repeat
	var distance := fposmod(time * TUNNEL_SPEED, tunnel_length())
	var position := tunnel_at(distance)
	var eye := tunnel_point_at(position)
	var target := Vector3.ZERO
	for k in TUNNEL_LOOK_SAMPLES:
		var ahead := lerpf(TUNNEL_LOOK_FROM, TUNNEL_LOOK_TO, float(k) / (TUNNEL_LOOK_SAMPLES - 1))
		target += tunnel_point_at(tunnel_at(distance + ahead)) / TUNNEL_LOOK_SAMPLES
	# Camera space: x right, y up, z forward, rolling slowly around the view
	var look := Basis.looking_at(target - eye, Vector3.UP)
	var view := Basis(Vector3.BACK, time * TUNNEL_ROLL) * Basis.from_scale(Vector3(1, 1, -1)) * look.transposed()
	var projector := CubeView.new(Basis.IDENTITY, rect, rect.size.y / 2.0)

	# Rings fixed on the path, from the start of the curve of the camera
	var curve := floori(position)
	var rings: Array[PackedVector3Array] = []
	for k in TUNNEL_AHEAD * TUNNEL_RINGS + 1:
		var c := curve + k / TUNNEL_RINGS
		var t := float(k % TUNNEL_RINGS) / TUNNEL_RINGS
		var center := tunnel_point(c, t)
		var tangent := (tunnel_point(c, t + 0.1) - center).normalized()
		var ring := PackedVector3Array()
		for i in TUNNEL_SIDES:
			# Like the hack: a point above the center, turned around the tangent
			ring.append(view * (center + Vector3(0, 0, TUNNEL_RADIUS).rotated(tangent, i * TAU / TUNNEL_SIDES) - eye))
		rings.append(ring)

	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for k in rings.size():
		for i in TUNNEL_SIDES:
			var a := rings[k][i]
			red_segment(projector, a, rings[k][(i + 1) % TUNNEL_SIDES], TUNNEL_NEAR, TUNNEL_FOG, points, colors)
			if k > 0:
				red_segment(projector, rings[k - 1][i], a, TUNNEL_NEAR, TUNNEL_FOG, points, colors)
	draw_red_lines(canvas, points, colors)

# A red line in camera space (tunnel, Klein bottle), cut at the near plane, darker in the fog
static func red_segment(projector: CubeView, a: Vector3, b: Vector3, near: float, fog_density: float, points: PackedVector2Array, colors: PackedColorArray) -> void:
	if a.z < near and b.z < near:
		return
	if a.z < near:
		a = a.lerp(b, (near - a.z) / (b.z - a.z))
	elif b.z < near:
		b = b.lerp(a, (near - b.z) / (a.z - b.z))
	if not projector.add_segment(projector.project_camera(a), projector.project_camera(b), points):
		return
	var fog := exp(-fog_density * (a.length() + b.length()) / 2.0)
	colors.append(Color(RED.lerp(PALE_RED, fog * fog), fog))

# Lines of the glow then the lines themselves
static func draw_red_lines(canvas: CanvasItem, points: PackedVector2Array, colors: PackedColorArray) -> void:
	if points.is_empty():
		return
	var glow := PackedColorArray()
	for color in colors:
		glow.append(Color(color, color.a * 0.2))
	canvas.draw_multiline_colors(points, glow, 6.0)
	canvas.draw_multiline_colors(points, colors, 1.5)

# Mesh of the Klein bottle in 3d over two turns of the ring (v from 0 to 4 pi), built once:
# 2 * KLEIN_LINES_V rows, KLEIN_LINES_U + 1 points each; u from 0 to pi is the loop of the camera
static var klein_mesh := PackedVector3Array()

# Point of the figure-8 Klein bottle, scaled like in the hack (radius 2, plus 1.25). The bottle is the same
# after a turn of v, with its two loops swapped; it is back after two.
static func klein_point(u: float, v: float) -> Vector3:
	return klein_section(sin(u), sin(2.0 * u), v)

# Point of the cross-section in its own coordinates (the 8 is (sin u, sin 2u)), turned by v / 2 around the ring
static func klein_section(a: float, b: float, v: float) -> Vector3:
	var cv2 := cos(0.5 * v)
	var sv2 := sin(0.5 * v)
	var r := a * cv2 - b * sv2 + 2.0
	return Vector3(r * cos(v), r * sin(v), a * sv2 + b * cv2) / 3.25

static func build_klein_mesh() -> void:
	for i in 2 * KLEIN_LINES_V:
		for j in KLEIN_LINES_U + 1:
			klein_mesh.append(klein_point(TAU * j / KLEIN_LINES_U, TAU * i / KLEIN_LINES_V))

# Red wireframe of the Klein bottle, seen from inside its tube
static func draw_klein(canvas: CanvasItem, rect: Rect2, time: float) -> void:
	canvas.draw_rect(rect, Color.BLACK)
	if klein_mesh.is_empty():
		build_klein_mesh()
	var v := fposmod(time * KLEIN_SPEED, 2.0 * TAU)
	var eye := klein_section(KLEIN_LOOP_CENTER, 0.0, v)
	var forward := (klein_section(KLEIN_LOOP_CENTER, 0.0, v + KLEIN_LOOK_AHEAD) - eye).normalized()
	# The ring lies flat: its axis is up, the camera rolls slowly around its view
	var up := (Vector3.BACK - forward * forward.z).normalized()
	var right := forward.cross(up).normalized()
	var view := Basis(Vector3.BACK, time * KLEIN_ROLL) * Basis(right, up, forward).transposed()
	var projector := CubeView.new(Basis.IDENTITY, rect, rect.size.y / 2.0 / tan(deg_to_rad(KLEIN_FOV / 2.0)))

	# Rows of the mesh around the camera, wrapped over the two turns
	var rows := 2 * KLEIN_LINES_V
	var columns := KLEIN_LINES_U + 1
	var first := floori((v - KLEIN_BEHIND) / TAU * KLEIN_LINES_V)
	var row_count := ceili((KLEIN_AHEAD + KLEIN_BEHIND) / TAU * KLEIN_LINES_V) + 1
	# Each point once: camera space, screen, inside the rectangle (2 behind the camera), fog
	var count := row_count * columns
	var camera := PackedVector3Array()
	var screen := PackedVector2Array()
	var fogs := PackedFloat32Array()
	var inside := PackedByteArray()
	camera.resize(count)
	screen.resize(count)
	fogs.resize(count)
	inside.resize(count)
	for i in row_count:
		var row := posmod(first + i, rows) * columns
		for j in columns:
			var k := i * columns + j
			var c := view * (klein_mesh[row + j] - eye)
			camera[k] = c
			if c.z >= KLEIN_NEAR:
				var at := projector.project_camera(c)
				screen[k] = at
				inside[k] = 1 if rect.has_point(at) else 0
				# The other loop of the 8 (u past pi) is dim
				fogs[k] = exp(-KLEIN_FOG * c.length()) * (1.0 if j <= KLEIN_LINES_U / 2 else KLEIN_OTHER_LOOP)
			else:
				inside[k] = 2
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in row_count:
		for j in columns:
			var a := i * columns + j
			for b in [a + 1 if j < KLEIN_LINES_U else -1, a + columns if i < row_count - 1 else -1]:
				if b < 0:
					continue
				var fog := minf(fogs[a], fogs[b])
				# Both ends on the screen: no clipping needed
				if inside[a] == 1 and inside[b] == 1:
					points.append(screen[a])
					points.append(screen[b])
					colors.append(Color(RED.lerp(PALE_RED, fog * fog), fog))
				elif inside[a] != 2 or inside[b] != 2:
					var before := points.size()
					red_segment(projector, camera[a], camera[b], KLEIN_NEAR, KLEIN_FOG, points, colors)
					# Clipped lines of the other loop stay dim
					if points.size() > before and (j >= KLEIN_LINES_U / 2 and (b == a + columns or j + 1 > KLEIN_LINES_U / 2)):
						colors[-1] = Color(colors[-1], colors[-1].a * KLEIN_OTHER_LOOP)
	draw_red_lines(canvas, points, colors)

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
