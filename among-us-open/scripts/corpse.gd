extends Node2D
## Cadaver en el piso: dibujo por codigo + marca de reportado.

var body_color := Color(0.9, 0.2, 0.2)
var victim_name := ""
var reported: bool = false


func setup(color_value: Color, pname: String) -> void:
	body_color = color_value
	victim_name = pname


func _draw() -> void:
	var dark: Color = body_color.darkened(0.4)
	# Charco.
	draw_circle(Vector2.ZERO, 20, Color(0.5, 0.05, 0.05, 0.55))
	# Cuerpo tumbado.
	draw_rect(Rect2(-20, -8, 34, 16), body_color)
	draw_circle(Vector2(-22, 0), 9, body_color)
	# Hueso visible.
	draw_rect(Rect2(8, -3, 14, 6), Color(0.92, 0.9, 0.85))
	draw_circle(Vector2(8, 0), 3, Color(0.92, 0.9, 0.85))
	draw_circle(Vector2(22, 0), 3, Color(0.92, 0.9, 0.85))
	draw_arc(Vector2(-22, 0), 9, 0.0, PI, 10, dark, 2.0)
