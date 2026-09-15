class_name EndScreen
extends CanvasLayer
## Pantalla de victoria/derrota con reinicio.

var _root: Control


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_result() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.modulate.a = 0.0
	add_child(_root)
	var won := GameState.player_won()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.12, 0.92) if won else Color(0.12, 0.01, 0.02, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var box := VBoxContainer.new()
	UIKit.place(box, Control.PRESET_CENTER, Vector2(-400, -250), Vector2(800, 500))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_root.add_child(box)
	var title := _text(box, "VICTORIA" if won else "DERROTA", 96, Color(0.4, 0.8, 1) if won else Color(1, 0.2, 0.2))
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	var who := "LA TRIPULACIÓN GANA" if GameState.winner == GameState.Role.CREW else "EL IMPOSTOR GANA"
	_text(box, who, 34, Color.WHITE)
	_text(box, GameState.end_reason, 22, Color(0.85, 0.85, 0.85))
	_text(box, "El impostor era: %s" % GameState.NAMES[GameState.impostor_id], 26, GameState.COLORS[GameState.impostor_id])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for pair: Array in [["Reiniciar", _restart], ["Menú principal", _menu]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(240, 60)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(pair[1])
		row.add_child(b)
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.8)


func _text(parent: Control, t: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _menu() -> void:
	get_tree().paused = false
	GameState.set_phase(GameState.Phase.MENU)
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
