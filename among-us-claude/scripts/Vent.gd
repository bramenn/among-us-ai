class_name Vent
extends Node2D
## Ducto: el impostor viaja al ducto conectado.

var partner: Vent
var room_name := ""


func _draw() -> void:
	draw_rect(Rect2(-20, -14, 40, 28), Color(0.1, 0.1, 0.12))
	draw_rect(Rect2(-20, -14, 40, 28), Color(0.45, 0.47, 0.5), false, 3.0)
	for i in 4:
		draw_line(Vector2(-14 + i * 9, -9), Vector2(-14 + i * 9, 9), Color(0.35, 0.36, 0.4), 3.0)
