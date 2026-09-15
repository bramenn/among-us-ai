extends Control
## Minijuego: conectar cables del mismo color (arrastrar con el mouse).

signal completed

const COLORS: Array[Color] = [Color(0.9, 0.15, 0.15), Color(0.2, 0.4, 0.95), Color(0.95, 0.85, 0.1), Color(0.85, 0.2, 0.85)]

var right_order: Array[int] = [0, 1, 2, 3]
var connected: Array[bool] = [false, false, false, false]
var _drag := -1
var _mouse := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(520, 380)
	right_order.shuffle()
	mouse_filter = Control.MOUSE_FILTER_STOP


func left_point(i: int) -> Vector2:
	return Vector2(50, 70 + i * 80)


func right_point(i: int) -> Vector2:
	return Vector2(470, 70 + i * 80)


## Conecta el cable izquierdo `li` con el conector derecho `ri`. true si coincide.
func connect_wire(li: int, ri: int) -> bool:
	if right_order[ri] != li or connected[li]:
		return false
	connected[li] = true
	queue_redraw()
	if not connected.has(false):
		completed.emit()
	return true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			for i in 4:
				if not connected[i] and mb.position.distance_to(left_point(i)) < 30.0:
					_drag = i
		elif _drag >= 0:
			for r in 4:
				if mb.position.distance_to(right_point(r)) < 34.0:
					connect_wire(_drag, r)
			_drag = -1
		queue_redraw()
	elif event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		if _drag >= 0:
			queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color(0.18, 0.19, 0.22))
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color(0.5, 0.5, 0.55), false, 4.0)
	for i in 4:
		var col := COLORS[i]
		draw_rect(Rect2(left_point(i) - Vector2(40, 12), Vector2(34, 24)), col)
		draw_rect(Rect2(right_point(i) + Vector2(6, -12), Vector2(34, 24)), COLORS[right_order[i]])
		draw_circle(left_point(i), 10, Color(0.7, 0.6, 0.2))
		draw_circle(right_point(i), 10, Color(0.7, 0.6, 0.2))
	for li in 4:
		if connected[li]:
			draw_line(left_point(li), right_point(right_order.find(li)), COLORS[li], 12.0)
	if _drag >= 0:
		draw_line(left_point(_drag), _mouse, COLORS[_drag], 12.0)
