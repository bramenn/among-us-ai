class_name Effects
extends RefCounted
## Partículas generadas por código.


static func blood_burst(parent: Node, pos: Vector2, col: Color) -> void:
	_burst(parent, pos, 60, Color(0.8, 0.02, 0.05), 260.0, 0.9)
	_burst(parent, pos, 25, col, 160.0, 0.7)


static func puff(parent: Node, pos: Vector2) -> void:
	_burst(parent, pos, 30, Color(0.6, 0.62, 0.7), 120.0, 0.6)


static func _burst(parent: Node, pos: Vector2, amount: int, col: Color, spd: float, life: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = spd * 0.4
	p.initial_velocity_max = spd
	p.gravity = Vector2(0, 300)
	p.damping_min = 80.0
	p.damping_max = 160.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	var fade := Gradient.new()
	fade.set_color(0, col)
	fade.set_color(1, Color(col, 0.0))
	p.color_ramp = fade
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
