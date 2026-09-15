extends Control
## Minijuego: ingresar el código numérico mostrado.

signal completed

var code := ""
var entered := ""
var _display: Label
var _status: Label


func _ready() -> void:
	custom_minimum_size = Vector2(360, 460)
	code = ""
	for i in 5:
		code += str(randi_range(0, 9))
	var box := VBoxContainer.new()
	box.position = Vector2(30, 20)
	box.size = Vector2(300, 420)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var hint := Label.new()
	hint.text = "CÓDIGO: " + code
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	box.add_child(hint)
	_display = Label.new()
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display.add_theme_font_size_override("font_size", 34)
	_display.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
	box.add_child(_display)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for label: String in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]:
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(94, 56)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_key.bind(label))
		grid.add_child(b)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = "Teclado numérico o clic"
	box.add_child(_status)
	_refresh()


func _on_key(label: String) -> void:
	if label == "C":
		entered = ""
	elif label == "OK":
		submit()
	else:
		press_digit(label)
	_refresh()


func press_digit(d: String) -> void:
	if entered.length() < code.length():
		entered += d
	_refresh()


func submit() -> bool:
	if entered == code:
		_status.text = "¡Aceptado!"
		completed.emit()
		return true
	_status.text = "Código incorrecto"
	entered = ""
	_refresh()
	return false


func _refresh() -> void:
	if _display:
		_display.text = entered + "_".repeat(code.length() - entered.length())


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode >= KEY_0 and k.keycode <= KEY_9:
		press_digit(str(k.keycode - KEY_0))
	elif k.keycode >= KEY_KP_0 and k.keycode <= KEY_KP_9:
		press_digit(str(k.keycode - KEY_KP_0))
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		submit()
	elif k.keycode == KEY_BACKSPACE:
		entered = entered.left(-1)
		_refresh()
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color(0.16, 0.17, 0.2))
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color(0.5, 0.5, 0.55), false, 4.0)
