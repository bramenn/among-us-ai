extends Node2D
## Ducto de ventilacion: dibujo + parpadeo cuando el impostor esta cerca.

var vent_index: int = 0
var _t: float = 0.0
var highlight: bool = false


func setup(idx: int) -> void:
	vent_index = idx
	queue_redraw()


func _ready() -> void:
	add_to_group("vents")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var rim := Color(0.55, 0.6, 0.65)
	if highlight:
		var pulse: float = 0.5 + 0.5 * sin(_t * 6.0)
		rim = Color(0.4 + 0.6 * pulse, 0.3, 0.3)
	draw_circle(Vector2.ZERO, 26, Color(0.1, 0.1, 0.12))
	draw_arc(Vector2.ZERO, 26, 0.0, TAU, 24, rim, 4.0)
	for i in 3:
		var y: float = -10.0 + float(i) * 10.0
		draw_line(Vector2(-16, y), Vector2(16, y), Color(0.35, 0.37, 0.4), 3.0)
