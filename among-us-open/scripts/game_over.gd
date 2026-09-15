extends Control
## Pantalla de victoria/derrota con reinicio.

var main_ref: Node = null
var _title: Label = null
var _sub: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 56)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 20)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_sub)
	var again := Button.new()
	again.text = "JUGAR DE NUEVO"
	again.custom_minimum_size = Vector2(280, 56)
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(_on_restart)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(again)
	vbox.add_child(h)
	var menu_btn := Button.new()
	menu_btn.text = "Menu principal"
	menu_btn.pressed.connect(_on_menu)
	var h2 := HBoxContainer.new()
	h2.alignment = BoxContainer.ALIGNMENT_CENTER
	h2.add_child(menu_btn)
	vbox.add_child(h2)
	visible = false


func show_result(winner: int) -> void:
	var player_impostor: bool = GameState.get_role(GameState.player_id) == GameState.Role.IMPOSTOR
	var won: bool = (winner == GameState.WinState.IMPOSTOR) == player_impostor
	if won:
		_title.text = "VICTORIA"
		_title.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
	else:
		_title.text = "DERROTA"
		_title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	if winner == GameState.WinState.IMPOSTOR:
		_sub.text = "El impostor se apodero de la nave."
	else:
		_sub.text = "La tripulacion sobrevivio. Tareas: %d/%d" % [GameState.done_tasks, GameState.total_tasks]
	visible = true


func _on_restart() -> void:
	if main_ref != null:
		main_ref.restart_game()


func _on_menu() -> void:
	if main_ref != null:
		main_ref.back_to_menu()
