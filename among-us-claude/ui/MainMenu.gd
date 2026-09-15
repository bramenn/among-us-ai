extends Control
## Menú principal: título animado, jugar y salir.

var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	UIKit.place(box, Control.PRESET_CENTER, Vector2(-300, -170), Vector2(600, 420))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var title := Label.new()
	title.text = "IMPOSTOR\nEN ÓRBITA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.05))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "1 impostor · 7 tripulantes · 6 salas"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	box.add_child(sub)
	var play := _button(box, "JUGAR")
	play.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	play.grab_focus()
	_button(box, "SALIR").pressed.connect(func() -> void: get_tree().quit())
	var help := Label.new()
	help.text = "WASD/Flechas mover · E usar · R reportar · Q matar · Espacio emergencia · Esc pausa"
	UIKit.place(help, Control.PRESET_CENTER_BOTTOM, Vector2(-500, -50), Vector2(1000, 30))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	add_child(help)


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 30)
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.02, 0.06))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 220:
		var p := Vector2(fposmod(rng.randf() * vs.x - _t * rng.randf_range(10.0, 60.0), vs.x), rng.randf() * vs.y)
		draw_circle(p, rng.randf_range(0.7, 2.0), Color(1, 1, 1, rng.randf_range(0.3, 1.0)))
	for i in GameState.PLAYER_COUNT:
		var x := fposmod(i * 190.0 + _t * (25.0 + i * 6.0), vs.x + 200.0) - 100.0
		var y := vs.y * (0.12 + 0.76 * fposmod(i * 0.37, 1.0)) + sin(_t + i) * 20.0
		draw_set_transform(Vector2(x, y), sin(_t * 0.5 + i) * 0.8, Vector2(1.6, 1.6))
		CharacterSprite.draw_bean(self, GameState.COLORS[i], Vector2.ZERO, 1.0)
	draw_set_transform(Vector2.ZERO)
