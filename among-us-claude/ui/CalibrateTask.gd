extends Control
## Minijuego: detener la barra móvil dentro de la zona verde 3 veces.

signal completed

const HITS_NEEDED := 3
const ZONE := 0.16

var value := 0.0
var speed := 0.7
var zone_start := 0.4
var hits := 0
var _dir := 1.0
var _flash := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(560, 260)
	_new_zone()
	var b := Button.new()
	b.text = "DETENER  [Espacio]"
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(180, 180)
	b.size = Vector2(200, 50)
	b.pressed.connect(attempt)
	add_child(b)


func _new_zone() -> void:
	zone_start = randf_range(0.05, 0.95 - ZONE)


func in_zone() -> bool:
	return value >= zone_start and value <= zone_start + ZONE


func attempt() -> bool:
	var ok := in_zone()
	if ok:
		hits += 1
		speed += 0.35
		_new_zone()
		if hits >= HITS_NEEDED:
			completed.emit()
	else:
		hits = maxi(hits - 1, 0)
	_flash = 0.3 if ok else -0.3
	queue_redraw()
	return ok


func _process(delta: float) -> void:
	value += _dir * speed * delta
	if value >= 1.0 or value <= 0.0:
		_dir = -_dir
		value = clampf(value, 0.0, 1.0)
	_flash = move_toward(_flash, 0.0, delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("emergency") or event.is_action_pressed("interact"):
		attempt()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var bg := Color(0.16, 0.17, 0.2)
	if _flash > 0.0:
		bg = bg.lerp(Color(0.1, 0.5, 0.2), _flash * 2.0)
	elif _flash < 0.0:
		bg = bg.lerp(Color(0.6, 0.1, 0.1), -_flash * 2.0)
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), bg)
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color(0.5, 0.5, 0.55), false, 4.0)
	var bar := Rect2(40, 90, 480, 50)
	draw_rect(bar, Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(bar.position.x + zone_start * bar.size.x, bar.position.y, ZONE * bar.size.x, bar.size.y), Color(0.2, 0.8, 0.3))
	var x := bar.position.x + value * bar.size.x
	draw_rect(Rect2(x - 4, bar.position.y - 10, 8, bar.size.y + 20), Color(1, 1, 1))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(40, 60), "Calibración %d / %d" % [hits, HITS_NEEDED], HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	for i in HITS_NEEDED:
		draw_circle(Vector2(440 + i * 30, 52), 10, Color(0.2, 1, 0.4) if i < hits else Color(0.3, 0.3, 0.35))
