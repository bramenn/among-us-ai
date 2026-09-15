extends Node2D
## Construye la nave: 6 salas + pasillos, muros, mesa central,
## 2 ductos, 9 estaciones de tarea y la region de navegacion.

const BOUNDS := Rect2(-1100, -700, 2200, 1400)
const WALK := Rect2(-1050, -650, 2100, 1300)

const ROOMS := [
	{"name": "CAFETERIA", "rect": [320, 360], "pos": [-320, -360], "color": [0.24, 0.26, 0.30]},
	{"name": "ELECTRICA", "rect": [560, 320], "pos": [-1020, -620], "color": [0.30, 0.24, 0.20]},
	{"name": "MOTORES", "rect": [560, 320], "pos": [460, -620], "color": [0.28, 0.22, 0.24]},
	{"name": "MEDICA", "rect": [560, 320], "pos": [-1020, 300], "color": [0.20, 0.28, 0.28]},
	{"name": "ARMERIA", "rect": [560, 320], "pos": [460, 300], "color": [0.26, 0.26, 0.22]},
	{"name": "PUENTE", "rect": [520, 240], "pos": [-260, -660], "color": [0.20, 0.24, 0.32]},
]

const CORRIDORS := [
	{"rect": [2200, 240], "pos": [-1100, -120]},
	{"rect": [240, 1400], "pos": [-120, -700]},
	{"rect": [2040, 140], "pos": [-1020, -430]},
	{"rect": [2040, 140], "pos": [-1020, 290]},
]

const STATIONS := [
	[Vector2(-850, -480), "WIRES", "Cables: Electrica"],
	[Vector2(-600, -350), "CODE", "Codigo: Electrica"],
	[Vector2(850, -480), "CALIBRATE", "Calibrar: Motores"],
	[Vector2(600, -350), "WIRES", "Cables: Motores"],
	[Vector2(-850, 480), "CODE", "Codigo: Medica"],
	[Vector2(-600, 430), "CALIBRATE", "Escaner: Medica"],
	[Vector2(850, 480), "WIRES", "Cables: Armeria"],
	[Vector2(600, 430), "CODE", "Codigo: Armeria"],
	[Vector2(0, -540), "CALIBRATE", "Calibrar: Puente"],
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("ship")
	_rng.randomize()
	_build_floors()
	_build_walls()
	_build_table()
	_build_vents()
	_build_stations()
	_build_nav()
	var mod := CanvasModulate.new()
	mod.color = Color(0.30, 0.30, 0.40)
	add_child(mod)


func get_random_point() -> Vector2:
	return Vector2(
		_rng.randf_range(WALK.position.x, WALK.position.x + WALK.size.x),
		_rng.randf_range(WALK.position.y, WALK.position.y + WALK.size.y))


func spawn_points(count: int) -> Array:
	var pts: Array = []
	var base := [Vector2(-200, -200), Vector2(200, -200), Vector2(-200, 200),
		Vector2(200, 200), Vector2(-600, 0), Vector2(600, 0),
		Vector2(0, -300), Vector2(0, 300)]
	for i in count:
		var p: Vector2 = base[i % base.size()]
		pts.append(p + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-30, 30)))
	return pts


func seat_positions() -> Array:
	var seats: Array = []
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		seats.append(Vector2(cos(a), sin(a)) * 110.0)
	return seats


func _rect_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0),
		r.position + r.size, r.position + Vector2(0, r.size.y)])


func _build_floors() -> void:
	_add_floor(BOUNDS.grow(60), Color(0.07, 0.08, 0.10))
	for c in CORRIDORS:
		_add_floor(Rect2(Vector2(c["pos"][0], c["pos"][1]), Vector2(c["rect"][0], c["rect"][1])), Color(0.16, 0.17, 0.20))
	for r in ROOMS:
		var col: Array = r["color"]
		_add_floor(Rect2(Vector2(r["pos"][0], r["pos"][1]), Vector2(r["rect"][0], r["rect"][1])), Color(col[0], col[1], col[2]))
		_add_room_label(String(r["name"]), Vector2(r["pos"][0], r["pos"][1]), Vector2(r["rect"][0], r["rect"][1]))


func _add_floor(r: Rect2, col: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = _rect_points(r)
	p.color = col
	add_child(p)


func _add_room_label(room_name: String, pos: Vector2, room_size: Vector2) -> void:
	var label := Label.new()
	label.text = room_name
	label.position = pos + Vector2(10, 8)
	label.size = Vector2(room_size.x - 20, 30)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	add_child(label)


func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	var t: float = 40.0
	_add_wall(body, Rect2(BOUNDS.position - Vector2(0, t), Vector2(BOUNDS.size.x, t)))
	_add_wall(body, Rect2(Vector2(BOUNDS.position.x, BOUNDS.position.y + BOUNDS.size.y), Vector2(BOUNDS.size.x, t)))
	_add_wall(body, Rect2(BOUNDS.position - Vector2(t, 0), Vector2(t, BOUNDS.size.y)))
	_add_wall(body, Rect2(Vector2(BOUNDS.position.x + BOUNDS.size.x, BOUNDS.position.y), Vector2(t, BOUNDS.size.y)))
	for pillar_pos in [Vector2(-1000, -640), Vector2(1000, -640), Vector2(-1000, 640), Vector2(1000, 640)]:
		_add_wall(body, Rect2(pillar_pos - Vector2(25, 25), Vector2(50, 50)))


func _add_wall(body: StaticBody2D, r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	body.add_child(shape)
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = _rect_points(Rect2(-r.size * 0.5, r.size))
	occ.occluder = poly
	occ.position = r.get_center()
	body.add_child(occ)
	var p := Polygon2D.new()
	p.polygon = _rect_points(r)
	p.color = Color(0.35, 0.38, 0.44)
	add_child(p)


func _build_table() -> void:
	var table := StaticBody2D.new()
	table.name = "MeetingTable"
	table.add_to_group("meeting_table")
	add_child(table)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	shape.shape = circle
	table.add_child(shape)
	var top := Polygon2D.new()
	top.polygon = _circle_points(52.0, 24)
	top.color = Color(0.55, 0.2, 0.2)
	table.add_child(top)
	var btn := Polygon2D.new()
	btn.polygon = _circle_points(16.0, 16)
	btn.color = Color(0.9, 0.25, 0.25)
	btn.position = Vector2.ZERO
	table.add_child(btn)


func _circle_points(radius: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _build_vents() -> void:
	var script: Script = load("res://scripts/vent.gd")
	var spots := [Vector2(-950, 0), Vector2(950, 0)]
	for i in spots.size():
		var v: Node2D = script.new()
		v.position = spots[i]
		add_child(v)
		v.setup(i)


func _build_stations() -> void:
	var script: Script = load("res://scripts/task_station.gd")
	for i in STATIONS.size():
		var spec: Array = STATIONS[i]
		var st: Area2D = script.new()
		st.position = spec[0]
		add_child(st)
		st.setup(i, spec[1], spec[2])


func _build_nav() -> void:
	var region := NavigationRegion2D.new()
	region.name = "NavRegion"
	var poly := NavigationPolygon.new()
	poly.vertices = _rect_points(WALK)
	poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = poly
	add_child(region)
