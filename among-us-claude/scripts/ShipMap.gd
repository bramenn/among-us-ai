class_name ShipMap
extends Node2D
## Construye la nave: suelo, paredes con colisión y oclusores, navegación, estaciones y ductos.

const CELL := 40
const GRID := Vector2i(60, 43)
const WALL_LAYER := 1

const ROOMS := [
	{"name": "Cafetería", "rect": Rect2i(22, 2, 16, 12), "tint": Color(0.36, 0.38, 0.45)},
	{"name": "Enfermería", "rect": Rect2i(44, 3, 11, 9), "tint": Color(0.32, 0.45, 0.45)},
	{"name": "Reactor", "rect": Rect2i(2, 16, 12, 11), "tint": Color(0.45, 0.33, 0.3)},
	{"name": "Navegación", "rect": Rect2i(47, 17, 11, 11), "tint": Color(0.3, 0.36, 0.5)},
	{"name": "Electricidad", "rect": Rect2i(8, 32, 13, 9), "tint": Color(0.45, 0.43, 0.28)},
	{"name": "Almacén", "rect": Rect2i(26, 30, 13, 11), "tint": Color(0.38, 0.34, 0.3)},
]
const CORRIDORS := [
	Rect2i(38, 6, 6, 3), Rect2i(7, 10, 15, 3), Rect2i(7, 13, 3, 3), Rect2i(30, 14, 3, 16),
	Rect2i(10, 27, 3, 5), Rect2i(21, 35, 5, 3), Rect2i(49, 12, 3, 5), Rect2i(39, 35, 13, 3),
	Rect2i(49, 28, 3, 7),
]
# [celda, tipo de tarea] 0 = cables, 1 = código, 2 = calibrar
const STATIONS := [
	[Vector2i(9, 33), 0], [Vector2i(3, 18), 0], [Vector2i(37, 31), 0],
	[Vector2i(3, 25), 1], [Vector2i(56, 22), 1], [Vector2i(53, 4), 1],
	[Vector2i(19, 33), 2], [Vector2i(56, 18), 2], [Vector2i(23, 3), 2],
]
const VENTS := [Vector2i(18, 39), Vector2i(45, 10)]
const TABLE_RADIUS := 64.0

var walkable := {}   # Vector2i -> true
var walls := {}      # Vector2i -> true
var stations: Array[TaskStation] = []
var vents: Array[Vent] = []
var nav_region: NavigationRegion2D


func _ready() -> void:
	_build_grid()
	_build_walls()
	_build_navigation()
	_build_props()
	queue_redraw()


func _build_grid() -> void:
	var rects: Array[Rect2i] = []
	for r: Dictionary in ROOMS:
		rects.append(r.rect)
	for c: Rect2i in CORRIDORS:
		rects.append(c)
	for r in rects:
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				walkable[Vector2i(x, y)] = true
	for cell: Vector2i in walkable:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := cell + Vector2i(dx, dy)
				if not walkable.has(n):
					walls[n] = true


## Paredes agrupadas por filas para tener pocos shapes/oclusores.
func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = WALL_LAYER
	body.collision_mask = 0
	add_child(body)
	for y in range(-1, GRID.y + 1):
		var x := -1
		while x <= GRID.x:
			if not walls.has(Vector2i(x, y)):
				x += 1
				continue
			var start := x
			while walls.has(Vector2i(x, y)):
				x += 1
			var rect := Rect2(start * CELL, y * CELL, (x - start) * CELL, CELL)
			var shape := CollisionShape2D.new()
			var rs := RectangleShape2D.new()
			rs.size = rect.size
			shape.shape = rs
			shape.position = rect.get_center()
			body.add_child(shape)
			var occ := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			poly.polygon = _rect_points(rect)
			occ.occluder = poly
			add_child(occ)
	# Mesa central: colisión circular.
	var table := StaticBody2D.new()
	table.collision_layer = WALL_LAYER
	table.position = table_position()
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = TABLE_RADIUS
	cs.shape = circle
	table.add_child(cs)
	add_child(table)


func _build_navigation() -> void:
	var np := NavigationPolygon.new()
	np.agent_radius = 18.0
	var src := NavigationMeshSourceGeometryData2D.new()
	for r: Dictionary in ROOMS:
		src.add_traversable_outline(_rect_points(_cell_rect(r.rect)))
	for c: Rect2i in CORRIDORS:
		src.add_traversable_outline(_rect_points(_cell_rect(c)))
	var table_poly := PackedVector2Array()
	for i in 16:
		table_poly.append(table_position() + Vector2.from_angle(TAU * i / 16.0) * TABLE_RADIUS)
	src.add_obstruction_outline(table_poly)
	NavigationServer2D.bake_from_source_geometry_data(np, src)
	nav_region = NavigationRegion2D.new()
	nav_region.navigation_polygon = np
	add_child(nav_region)


func _build_props() -> void:
	for i in STATIONS.size():
		var s := TaskStation.new()
		s.task_type = STATIONS[i][1]
		s.index = i
		s.position = cell_center(STATIONS[i][0])
		s.room_name = room_name_at(s.position)
		add_child(s)
		stations.append(s)
	for v: Vector2i in VENTS:
		var vent := Vent.new()
		vent.position = cell_center(v)
		vent.room_name = room_name_at(vent.position)
		add_child(vent)
		vents.append(vent)
	vents[0].partner = vents[1]
	vents[1].partner = vents[0]


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL + Vector2(CELL, CELL) * 0.5


static func _cell_rect(r: Rect2i) -> Rect2:
	return Rect2(Vector2(r.position) * CELL, Vector2(r.size) * CELL)


static func _rect_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func table_position() -> Vector2:
	return _cell_rect(ROOMS[0].rect).get_center()


static func room_count() -> int:
	return ROOMS.size()


static func room_center(i: int) -> Vector2:
	return _cell_rect(ROOMS[i].rect).get_center()


static func random_point_in_room(i: int, rng: RandomNumberGenerator) -> Vector2:
	var r := _cell_rect(ROOMS[i].rect).grow(-CELL * 1.5)
	return Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))


static func room_name_at(p: Vector2) -> String:
	for r: Dictionary in ROOMS:
		if _cell_rect(r.rect).has_point(p):
			return r.name
	return "Pasillo"


func meeting_spots(n: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for i in n:
		spots.append(table_position() + Vector2.from_angle(TAU * i / float(n) - PI / 2.0) * 150.0)
	return spots


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var world := Rect2(-CELL * 10, -CELL * 10, (GRID.x + 20) * CELL, (GRID.y + 20) * CELL)
	draw_rect(world, Color(0.02, 0.02, 0.06))
	for i in 400:
		var p := Vector2(rng.randf_range(world.position.x, world.end.x), rng.randf_range(world.position.y, world.end.y))
		draw_circle(p, rng.randf_range(0.8, 2.2), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
	# Suelo
	for cell: Vector2i in walkable:
		var tint := Color(0.26, 0.27, 0.3)
		var name_here := room_name_at(cell_center(cell))
		for r: Dictionary in ROOMS:
			if r.name == name_here:
				tint = r.tint
		if (cell.x + cell.y) % 2 == 0:
			tint = tint.darkened(0.06)
		draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), tint)
		draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), Color(0, 0, 0, 0.12), false, 1.0)
	# Paredes
	for cell: Vector2i in walls:
		var r := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
		draw_rect(r, Color(0.12, 0.13, 0.2))
		if walkable.has(cell + Vector2i(0, 1)):
			draw_rect(Rect2(r.position + Vector2(0, CELL - 10), Vector2(CELL, 10)), Color(0.3, 0.32, 0.42))
	# Decoración por sala
	_draw_decor()
	# Mesa de emergencia
	var tp := table_position()
	draw_circle(tp, TABLE_RADIUS + 6, Color(0.1, 0.1, 0.14))
	draw_circle(tp, TABLE_RADIUS, Color(0.55, 0.6, 0.68))
	draw_circle(tp, 22, Color(0.25, 0.25, 0.3))
	draw_circle(tp, 16, Color(0.9, 0.1, 0.1))
	draw_circle(tp + Vector2(-4, -4), 5, Color(1, 0.6, 0.6))
	# Nombres de salas
	for r: Dictionary in ROOMS:
		var rect := _cell_rect(r.rect)
		draw_string(font, rect.position + Vector2(18, 34), String(r.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.35))


func _draw_decor() -> void:
	# Reactor: núcleo
	var rc := room_center(2)
	draw_circle(rc, 56, Color(0.2, 0.1, 0.1))
	draw_circle(rc, 40, Color(0.9, 0.35, 0.15))
	draw_circle(rc, 20, Color(1, 0.85, 0.4))
	# Enfermería: camillas
	var mr := _cell_rect(ROOMS[1].rect)
	for i in 3:
		draw_rect(Rect2(mr.position + Vector2(130 + i * 90, mr.size.y - 110), Vector2(70, 50)), Color(0.8, 0.85, 0.9))
		draw_rect(Rect2(mr.position + Vector2(130 + i * 90, mr.size.y - 110), Vector2(20, 50)), Color(0.5, 0.75, 0.9))
	# Almacén: cajas
	var sr := _cell_rect(ROOMS[5].rect)
	for p: Vector2 in [Vector2(120, 260), Vector2(170, 300), Vector2(380, 150), Vector2(420, 330)]:
		draw_rect(Rect2(sr.position + p, Vector2(46, 46)), Color(0.55, 0.4, 0.22))
		draw_rect(Rect2(sr.position + p, Vector2(46, 46)), Color(0.3, 0.2, 0.1), false, 3.0)
	# Navegación: ventana al espacio
	var nr := _cell_rect(ROOMS[3].rect)
	draw_rect(Rect2(Vector2(nr.end.x - 30, nr.position.y + 80), Vector2(22, nr.size.y - 160)), Color(0.1, 0.2, 0.45))
	# Electricidad: paneles
	var er := _cell_rect(ROOMS[4].rect)
	for i in 4:
		draw_rect(Rect2(er.position + Vector2(140 + i * 60, 6), Vector2(40, 26)), Color(0.25, 0.28, 0.25))
		draw_circle(er.position + Vector2(160 + i * 60, 19), 4, Color(0.2, 1, 0.3) if i % 2 == 0 else Color(1, 0.8, 0.2))
