extends Control
## Panel de minijuegos de tareas: cables, codigo y calibracion.

var task_manager: Node = null
var hud: Node = null

var _station: Node = null
var _title: Label = null
var _body: VBoxContainer = null
var _dim: ColorRect = null

var _wire_left: int = -1
var _wire_matches: int = 0
var _wire_buttons: Array = []
var _code_expected: String = ""
var _code_entered: String = ""
var _code_display: Label = null
var _cal_marker: float = 0.0
var _cal_dir: float = 1.0
var _cal_target: float = 0.5
var _cal_active: bool = false
var _cal_bar: ProgressBar = null
var _open_time: float = 0.0


static func check_code_entered(expected: String, entered: String) -> bool:
	return expected == entered and not expected.is_empty()


static func calibrate_success(marker: float, target: float, tol: float) -> bool:
	return absf(marker - target) <= tol


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.7)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 380)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	vbox.add_child(_body)
	var close_btn := Button.new()
	close_btn.text = "Cerrar [E]"
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)
	visible = false


func is_open() -> bool:
	return visible


func open_task(station: Node) -> void:
	_station = station
	_open_time = 0.0
	_title.text = station.task_name
	for c in _body.get_children():
		c.queue_free()
	_wire_buttons = []
	match String(station.task_type):
		"WIRES":
			_build_wires()
		"CODE":
			_build_code()
		"CALIBRATE":
			_build_calibrate()
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_open_time += delta
	if _open_time > 0.3 and Input.is_action_just_pressed("interact"):
		_on_close_pressed()
		return
	if not _cal_active or _cal_bar == null:
		return
	_cal_marker += _cal_dir * delta * 0.9
	if _cal_marker > 1.0:
		_cal_marker = 1.0
		_cal_dir = -1.0
	elif _cal_marker < 0.0:
		_cal_marker = 0.0
		_cal_dir = 1.0
	_cal_bar.value = _cal_marker * 100.0


func _on_close_pressed() -> void:
	visible = false
	_cal_active = false
	_station = null


func _complete() -> void:
	_cal_active = false
	if _station != null and task_manager != null:
		task_manager.complete_player_task(_station.station_id)
	visible = false
	_station = null
	if hud != null:
		hud.refresh_tasks()
		hud.flash_message("Tarea completada")


func _build_wires() -> void:
	_wire_left = -1
	_wire_matches = 0
	var info := Label.new()
	info.text = "Pulsa un cable izquierdo y luego su color derecho."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(info)
	var cols := [Color.RED, Color.YELLOW, Color.GREEN, Color.CYAN]
	var names := ["Rojo", "Amarillo", "Verde", "Cian"]
	var order: Array = [0, 1, 2, 3]
	order.shuffle()
	for side in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_body.add_child(row)
		for k in 4:
			var idx: int = order[k] if side == 1 else k
			var b := Button.new()
			b.text = names[idx] if side == 0 else "?"
			b.modulate = cols[idx]
			b.custom_minimum_size = Vector2(95, 44)
			b.pressed.connect(_on_wire_pressed.bind(side, idx, b))
			row.add_child(b)
			_wire_buttons.append(b)


func _on_wire_pressed(side: int, idx: int, btn: Button) -> void:
	if side == 0:
		_wire_left = idx
		for b in _wire_buttons:
			b.disabled = false
		btn.disabled = true
	else:
		if _wire_left == idx:
			btn.text = "OK"
			btn.disabled = true
			for b in _wire_buttons:
				if b.disabled and b.text != "OK":
					b.disabled = false
			_wire_left = -1
			_wire_matches += 1
			if _wire_matches >= 4:
				_complete()
		else:
			_wire_left = -1
			for b in _wire_buttons:
				if b.text != "OK":
					b.disabled = false


func _build_code() -> void:
	_code_expected = ""
	for i in 5:
		_code_expected += str(randi() % 10)
	_code_entered = ""
	var info := Label.new()
	info.text = "Introduce el codigo: " + _code_expected
	info.add_theme_font_size_override("font_size", 20)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(info)
	_code_display = Label.new()
	_code_display.text = "_ _ _ _ _"
	_code_display.add_theme_font_size_override("font_size", 26)
	_code_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(_code_display)
	for row in 3:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 6)
		_body.add_child(h)
		for c in 3:
			var digit: int = row * 3 + c + 1
			if digit > 9:
				continue
			var b := Button.new()
			b.text = str(digit % 10)
			b.custom_minimum_size = Vector2(64, 48)
			b.pressed.connect(_on_digit_pressed.bind(digit % 10))
			h.add_child(b)
	var h0 := HBoxContainer.new()
	h0.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(h0)
	var clear := Button.new()
	clear.text = "Borrar"
	clear.pressed.connect(_on_code_clear)
	h0.add_child(clear)


func _on_digit_pressed(digit: int) -> void:
	if _code_entered.length() >= 5:
		return
	_code_entered += str(digit)
	_update_code_display()
	if _code_entered.length() == 5:
		if check_code_entered(_code_expected, _code_entered):
			_complete()
		else:
			_code_entered = ""
			_update_code_display()
			if hud != null:
				hud.flash_message("Codigo incorrecto")


func _on_code_clear() -> void:
	_code_entered = ""
	_update_code_display()


func _update_code_display() -> void:
	if _code_display == null:
		return
	var txt: String = ""
	for i in 5:
		txt += (_code_entered[i] + " ") if i < _code_entered.length() else "_ "
	_code_display.text = txt.strip_edges()


func _build_calibrate() -> void:
	_cal_marker = 0.0
	_cal_dir = 1.0
	_cal_target = randf_range(0.3, 0.7)
	_cal_active = true
	var info := Label.new()
	info.text = "Deten el marcador dentro de la zona verde."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(info)
	_cal_bar = ProgressBar.new()
	_cal_bar.min_value = 0.0
	_cal_bar.max_value = 100.0
	_cal_bar.custom_minimum_size = Vector2(400, 30)
	_cal_bar.show_percentage = false
	_body.add_child(_cal_bar)
	var zone := Label.new()
	zone.text = "Zona buena: %d%% - %d%%" % [int(_cal_target * 100.0) - 8, int(_cal_target * 100.0) + 8]
	zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(zone)
	var stop := Button.new()
	stop.text = "DETENER"
	stop.custom_minimum_size = Vector2(200, 52)
	stop.pressed.connect(_on_cal_stop)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(stop)
	_body.add_child(h)


func _on_cal_stop() -> void:
	if calibrate_success(_cal_marker, _cal_target, 0.08):
		_complete()
	elif hud != null:
		hud.flash_message("Fuera de zona, reintenta")
