class_name HUD
extends CanvasLayer
## HUD: progreso global, rol, tareas pendientes, acciones y cooldown.

var game: Game
var _progress: ProgressBar
var _progress_label: Label
var _role: Label
var _tasks: Label
var _room: Label
var _toast: Label
var _actions := {}   # action -> Label


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Barra global de tareas
	_progress = ProgressBar.new()
	UIKit.place(_progress, Control.PRESET_CENTER_TOP, Vector2(-260, 14), Vector2(520, 26))
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.add_theme_stylebox_override("background", UIKit.box(Color(0.1, 0.1, 0.12, 0.85), Color(0.8, 0.8, 0.85)))
	_progress.add_theme_stylebox_override("fill", UIKit.box(Color(0.25, 0.85, 0.35), Color(0, 0, 0, 0)))
	root.add_child(_progress)
	_progress_label = _label(root, 15)
	UIKit.place(_progress_label, Control.PRESET_CENTER_TOP, Vector2(-260, 16), Vector2(520, 26))
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Panel izquierdo
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	panel.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.15), 12))
	root.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	_role = Label.new()
	_role.add_theme_font_size_override("font_size", 22)
	vb.add_child(_role)
	_tasks = Label.new()
	_tasks.add_theme_font_size_override("font_size", 15)
	vb.add_child(_tasks)

	_room = _label(root, 20)
	UIKit.place(_room, Control.PRESET_TOP_RIGHT, Vector2(-320, 14), Vector2(300, 30))
	_room.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Acciones abajo a la derecha
	var hb := HBoxContainer.new()
	UIKit.place(hb, Control.PRESET_BOTTOM_RIGHT, Vector2(-640, -90), Vector2(620, 70))
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 10)
	root.add_child(hb)
	for a: String in ["interact", "report", "kill", "emergency"]:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UIKit.box(Color(0.1, 0.1, 0.14, 0.85), Color(1, 1, 1, 0.6), 10))
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(120, 50)
		l.add_theme_font_size_override("font_size", 16)
		pc.add_child(l)
		hb.add_child(pc)
		_actions[a] = l

	_toast = _label(root, 34)
	UIKit.place(_toast, Control.PRESET_CENTER_TOP, Vector2(-400, 120), Vector2(800, 60))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.modulate.a = 0.0


func _label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(l)
	return l


func toast(text: String, col := Color.WHITE) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", col)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.8)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _process(_delta: float) -> void:
	if game == null or game.player == null:
		return
	var t := GameState.task_totals()
	_progress.value = GameState.task_progress()
	_progress_label.text = "TAREAS TOTALES  %d / %d" % [t.x, t.y]
	var imp := GameState.player_is_impostor()
	if not game.player.alive:
		_role.text = "FANTASMA"
		_role.add_theme_color_override("font_color", Color(0.7, 0.8, 1))
	else:
		_role.text = "IMPOSTOR" if imp else "TRIPULANTE"
		_role.add_theme_color_override("font_color", Color(1, 0.25, 0.25) if imp else Color(0.4, 0.8, 1))
	var lines: Array[String] = []
	if imp:
		lines.append("Mata a la tripulación sin ser visto.")
		lines.append("Tareas falsas:")
	for s in game.map.stations:
		if game.player_tasks.has(s):
			lines.append("  [  ] " + s.task_name())
		elif game.player_done.has(s):
			lines.append("  [OK] " + s.task_name())
	_tasks.text = "\n".join(lines)
	_room.text = ShipMap.room_name_at(game.player.global_position)

	_set_action("interact", "[E] USAR", game.player_can_interact())
	_set_action("report", "[R] REPORTAR", game.player_nearby_body() != null)
	if imp:
		var cd := game.kill_cooldown
		_set_action("kill", "[Q] MATAR" if cd <= 0.0 else "[Q] MATAR %ds" % ceili(cd), game.player_can_kill())
	else:
		(_actions["kill"] as Label).get_parent().hide()
	_set_action("emergency", "[ESPACIO] EMERG." if game.emergency_left > 0 else "SIN EMERG.", game.player_can_emergency())


func _set_action(a: String, text: String, enabled: bool) -> void:
	var l: Label = _actions[a]
	l.text = text
	(l.get_parent() as Control).modulate = Color(1, 1, 1, 1.0 if enabled else 0.35)
