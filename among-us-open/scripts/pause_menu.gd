extends Control
## Menu de pausa (Esc): continuar, reiniciar, menu.

var main_ref: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)
	var title := Label.new()
	title.text = "PAUSA"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var resume := Button.new()
	resume.text = "Continuar"
	resume.custom_minimum_size = Vector2(240, 48)
	resume.pressed.connect(_on_resume)
	vbox.add_child(resume)
	var restart := Button.new()
	restart.text = "Reiniciar"
	restart.custom_minimum_size = Vector2(240, 48)
	restart.pressed.connect(_on_restart)
	vbox.add_child(restart)
	var menu_btn := Button.new()
	menu_btn.text = "Menu principal"
	menu_btn.custom_minimum_size = Vector2(240, 48)
	menu_btn.pressed.connect(_on_menu)
	vbox.add_child(menu_btn)
	visible = false


func _on_resume() -> void:
	if main_ref != null:
		main_ref.toggle_pause()


func _on_restart() -> void:
	if main_ref != null:
		main_ref.restart_game()


func _on_menu() -> void:
	if main_ref != null:
		main_ref.back_to_menu()
