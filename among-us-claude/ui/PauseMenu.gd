extends CanvasLayer
## Menú de pausa (Esc).

var _root: Control


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var box := VBoxContainer.new()
	UIKit.place(box, Control.PRESET_CENTER, Vector2(-140, -120), Vector2(280, 240))
	box.add_theme_constant_override("separation", 16)
	_root.add_child(box)
	var t := Label.new()
	t.text = "PAUSA"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 48)
	box.add_child(t)
	for pair: Array in [["Reanudar", toggle], ["Menú principal", _to_menu]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(280, 54)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(pair[1])
		box.add_child(b)
	_root.hide()


func toggle() -> void:
	_root.visible = not _root.visible
	get_tree().paused = _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameState.phase != GameState.Phase.ENDED:
		toggle()
		get_viewport().set_input_as_handled()


func _to_menu() -> void:
	get_tree().paused = false
	GameState.set_phase(GameState.Phase.MENU)
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
