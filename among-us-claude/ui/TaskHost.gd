class_name TaskHost
extends CanvasLayer
## Abre el minijuego de una estación sobre el juego.

signal task_completed(station: TaskStation)
signal closed

const SCRIPTS := [preload("res://ui/WiresTask.gd"), preload("res://ui/CodeTask.gd"), preload("res://ui/CalibrateTask.gd")]

var station: TaskStation
var game_open := false
var _root: Control
var _center: CenterContainer
var _title: Label


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_center)
	_title = Label.new()
	UIKit.place(_title, Control.PRESET_CENTER_TOP, Vector2(-300, 30), Vector2(600, 40))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_root.add_child(_title)
	var hint := Label.new()
	hint.text = "[Esc] cerrar"
	UIKit.place(hint, Control.PRESET_CENTER_BOTTOM, Vector2(-100, -50), Vector2(200, 30))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(hint)
	_root.hide()


func open(s: TaskStation) -> Control:
	close_task()
	station = s
	var mg: Control = SCRIPTS[s.task_type].new()
	mg.connect("completed", _on_completed)
	_center.add_child(mg)
	_title.text = s.task_name()
	_root.show()
	game_open = true
	return mg


func close_task() -> void:
	for c in _center.get_children():
		c.queue_free()
	_root.hide()
	if game_open:
		game_open = false
		closed.emit()


func _on_completed() -> void:
	var s := station
	game_open = false
	await get_tree().create_timer(0.4).timeout
	for c in _center.get_children():
		c.queue_free()
	_root.hide()
	task_completed.emit(s)
	closed.emit()


func _input(event: InputEvent) -> void:
	if game_open and event.is_action_pressed("pause"):
		close_task()
		get_viewport().set_input_as_handled()
