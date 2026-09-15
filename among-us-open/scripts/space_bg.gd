extends Node2D
## Fondo estrellado dibujado por codigo.

var _stars: Array = []


func _ready() -> void:
	z_index = -100
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 220:
		_stars.append(Vector2(rng.randf_range(-2600, 2600), rng.randf_range(-1800, 1800)))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-2600, -1800, 5200, 3600), Color(0.02, 0.02, 0.05))
	for s in _stars:
		var v: Vector2 = s
		draw_circle(v, 1.6, Color(0.8, 0.8, 0.9, 0.7))
