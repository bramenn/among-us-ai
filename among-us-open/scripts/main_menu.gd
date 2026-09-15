extends Control
## Menu principal: titulo + jugar + controles.

var main_ref: Node = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	var title := Label.new()
	title.text = "AMONG US OPEN"
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = "7 tripulantes. 1 impostor. Sobrevive a la nave."
	sub.add_theme_font_size_override("font_size", 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	var play := Button.new()
	play.text = "JUGAR"
	play.custom_minimum_size = Vector2(260, 64)
	play.add_theme_font_size_override("font_size", 28)
	play.pressed.connect(_on_play)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(play)
	vbox.add_child(h)
	var controls := Label.new()
	controls.text = "WASD/Flechas moverse · E interactuar · R reportar · Q matar (impostor)\nESPACIO reunion (en mesa) · Esc pausa"
	controls.add_theme_font_size_override("font_size", 16)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(controls)


func _on_play() -> void:
	if main_ref != null:
		main_ref.start_game()
