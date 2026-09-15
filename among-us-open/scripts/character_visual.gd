extends Node2D
## Dibuja el tripulante estilo Among Us solo con codigo.
## Animacion de caminado por estiramiento + piernas alternas.

var body_color := Color(0.9, 0.2, 0.2)
var walk_phase: float = 0.0
var moving: bool = false
var face_dir: float = 1.0


func setup(color_value: Color) -> void:
	body_color = color_value
	queue_redraw()


func _process(delta: float) -> void:
	if moving:
		walk_phase += delta * 10.0
		var s: float = sin(walk_phase)
		scale = Vector2(1.0 + 0.05 * s, 1.0 - 0.05 * s)
	else:
		scale = scale.lerp(Vector2.ONE, minf(delta * 10.0, 1.0))
		if scale.distance_to(Vector2.ONE) < 0.005:
			scale = Vector2.ONE
	queue_redraw()


func _draw() -> void:
	var dark: Color = body_color.darkened(0.35)
	var step: float = sin(walk_phase) * 4.0 if moving else 0.0
	# Mochila.
	draw_rect(Rect2(-22, -18, 8, 26), dark)
	# Piernas (alternan al caminar).
	draw_rect(Rect2(-11, 8 + maxf(step, 0.0), 9, 16 - maxf(step, 0.0)), dark)
	draw_rect(Rect2(2, 8 + maxf(-step, 0.0), 9, 16 - maxf(-step, 0.0)), dark)
	# Cuerpo: rect + casco redondo.
	draw_rect(Rect2(-14, -20, 28, 30), body_color)
	draw_circle(Vector2(0, -20), 14, body_color)
	draw_arc(Vector2(0, -20), 14, PI, TAU, 12, dark, 2.0)
	# Visor.
	var visor := Rect2(Vector2(2, -28) * Vector2(face_dir, 1.0) + Vector2(-8, 0), Vector2(18, 10))
	draw_rect(visor.grow(2.0), dark)
	draw_rect(visor, Color(0.75, 0.9, 1.0, 1.0))
