class_name CharacterSprite
extends Node2D
## Dibujo del tripulante por código + animación de caminado por estiramiento.

var body_color := Color.WHITE
var facing := 1.0
var walk_amount := 0.0   # 0 quieto, 1 caminando
var ghost := false
var _phase := 0.0


func _process(delta: float) -> void:
	_phase += delta * 14.0 * walk_amount
	var s := sin(_phase) * 0.09 * walk_amount
	scale = Vector2((1.0 + s) * facing, 1.0 - s)
	position.y = -absf(sin(_phase)) * 4.0 * walk_amount
	rotation = sin(_phase * 0.5) * 0.06 * walk_amount
	modulate.a = 0.45 if ghost else 1.0
	queue_redraw()


func _draw() -> void:
	draw_bean(self, body_color, Vector2.ZERO, 1.0)


static func bean_points(offset: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:  # cabeza redondeada
		var a := PI + PI * i / 12.0
		pts.append(offset + Vector2(cos(a) * 16.0, sin(a) * 16.0 - 6.0) * s)
	pts.append(offset + Vector2(16, 18) * s)
	pts.append(offset + Vector2(4, 18) * s)
	pts.append(offset + Vector2(3, 12) * s)
	pts.append(offset + Vector2(-3, 12) * s)
	pts.append(offset + Vector2(-4, 18) * s)
	pts.append(offset + Vector2(-16, 18) * s)
	return pts


static func draw_bean(ci: CanvasItem, col: Color, offset: Vector2, s: float) -> void:
	ci.draw_rect(Rect2(offset + Vector2(-22, -8) * s, Vector2(8, 20) * s), col.darkened(0.35))  # mochila
	var pts := bean_points(offset, s)
	ci.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color(0.05, 0.05, 0.08), 2.5 * s)
	# visor
	var visor := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		visor.append(offset + Vector2(5 + cos(a) * 11.0, -7 + sin(a) * 6.5) * s)
	ci.draw_colored_polygon(visor, Color(0.55, 0.8, 0.95))
	ci.draw_circle(offset + Vector2(9, -9) * s, 2.5 * s, Color(1, 1, 1, 0.8))
