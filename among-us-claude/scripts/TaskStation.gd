class_name TaskStation
extends Node2D
## Consola de tarea. Se resalta si el jugador la tiene pendiente.

const TYPE_NAMES := ["Reparar cables", "Ingresar código", "Calibrar escudos"]

var task_type := 0
var index := 0
var room_name := ""
var highlighted := false:
	set(v):
		highlighted = v
		queue_redraw()
var _t := 0.0


func task_name() -> String:
	return "%s (%s)" % [TYPE_NAMES[task_type], room_name]


func _process(delta: float) -> void:
	if highlighted:
		_t += delta
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-18, -16, 36, 30), Color(0.15, 0.16, 0.2))
	var screen := [Color(0.2, 0.8, 1.0), Color(0.3, 1.0, 0.4), Color(1.0, 0.75, 0.2)][task_type] as Color
	draw_rect(Rect2(-13, -12, 26, 14), screen.darkened(0.3))
	draw_rect(Rect2(-10, 6, 20, 4), Color(0.4, 0.4, 0.45))
	if highlighted:
		var a := 0.5 + 0.5 * sin(_t * 5.0)
		draw_rect(Rect2(-22, -20, 44, 38), Color(1, 0.9, 0.2, a), false, 3.0)
