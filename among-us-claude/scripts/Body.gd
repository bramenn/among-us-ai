class_name Body
extends Node2D
## Cadáver en el piso.

var victim_id := 0
var body_color := Color.WHITE
var reported := false
var time_of_death := 0.0


func _draw() -> void:
	var pts := PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(16, 18), Vector2(4, 18),
		Vector2(3, 12), Vector2(-3, 12), Vector2(-4, 18), Vector2(-16, 18)])
	draw_ellipse_shadow()
	draw_colored_polygon(pts, body_color)
	draw_rect(Rect2(-22, 0, 8, 12), body_color.darkened(0.35))
	# hueso
	draw_rect(Rect2(-3, -10, 6, 12), Color(0.95, 0.93, 0.85))
	draw_circle(Vector2(-4, -11), 4, Color(0.95, 0.93, 0.85))
	draw_circle(Vector2(4, -11), 4, Color(0.95, 0.93, 0.85))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(12, 3), Vector2(-12, 3)]), Color(0.7, 0, 0))


func draw_ellipse_shadow() -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * 34.0, 14.0 + sin(a) * 10.0))
	draw_colored_polygon(pts, Color(0.5, 0, 0, 0.6))
