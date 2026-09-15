extends Area2D
## Estacion de tarea: consola dibujada por codigo, luz de estado.

const TYPES := ["WIRES", "CODE", "CALIBRATE"]

var station_id: int = 0
var task_type: String = "WIRES"
var task_name: String = "Tarea"
var done_glow: bool = false
var _t: float = 0.0


func setup(sid: int, ttype: String, tname: String) -> void:
	station_id = sid
	task_type = ttype
	task_name = tname


func _ready() -> void:
	add_to_group("task_stations")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 60.0
	shape.shape = circle
	add_child(shape)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func set_done_glow(v: bool) -> void:
	done_glow = v


func _draw() -> void:
	var base := Color(0.16, 0.18, 0.22)
	var edge := Color(0.4, 0.45, 0.5)
	draw_rect(Rect2(-30, -22, 60, 44), base)
	draw_rect(Rect2(-30, -22, 60, 44), edge, false, 3.0)
	# Pantalla segun tipo.
	match task_type:
		"WIRES":
			var cols := [Color.RED, Color.YELLOW, Color.GREEN, Color.CYAN]
			for i in 4:
				draw_circle(Vector2(-15 + float(i) * 10.0, 0), 4, cols[i])
		"CODE":
			draw_rect(Rect2(-18, -8, 36, 16), Color(0.05, 0.1, 0.08))
			draw_rect(Rect2(-18, -8, 36, 16), Color(0.2, 1.0, 0.4), false, 1.5)
		"CALIBRATE":
			draw_rect(Rect2(-18, -4, 36, 8), Color(0.1, 0.1, 0.15))
			var x: float = -18.0 + fmod(_t * 30.0, 36.0)
			draw_rect(Rect2(x - 2, -6, 4, 12), Color(1.0, 0.8, 0.2))
	# Luz de estado.
	var lamp := Color(1.0, 0.85, 0.2) if not done_glow else Color(0.3, 1.0, 0.4)
	if not done_glow:
		lamp = lamp * (0.7 + 0.3 * sin(_t * 4.0))
	draw_circle(Vector2(24, -16), 5, lamp)
