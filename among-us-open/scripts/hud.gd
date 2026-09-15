extends CanvasLayer
## HUD: progreso de tareas, lista pendiente, cooldown, pistas y rol.

var task_manager: Node = null

var _progress: ProgressBar = null
var _progress_label: Label = null
var _task_list: Label = null
var _hint: Label = null
var _flash: Label = null
var _flash_t: float = 0.0
var _kill_label: Label = null
var _role_label: Label = null
var _role_panel: PanelContainer = null
var _role_text: Label = null


func _ready() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	_progress_label = Label.new()
	_progress_label.text = "Tareas"
	_progress_label.add_theme_font_size_override("font_size", 18)
	top.add_child(_progress_label)
	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.custom_minimum_size = Vector2(380, 22)
	_progress.show_percentage = false
	top.add_child(_progress)
	_role_label = Label.new()
	_role_label.add_theme_font_size_override("font_size", 18)
	top.add_child(_role_label)
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.position = Vector2(12, 44)
	add_child(left)
	var title := Label.new()
	title.text = "Pendientes:"
	title.add_theme_font_size_override("font_size", 16)
	left.add_child(title)
	_task_list = Label.new()
	_task_list.add_theme_font_size_override("font_size", 15)
	left.add_child(_task_list)
	_kill_label = Label.new()
	_kill_label.add_theme_font_size_override("font_size", 16)
	_kill_label.position = Vector2(12, 200)
	add_child(_kill_label)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.position = Vector2(0, -60)
	_hint.add_theme_color_override("font_color", Color(1, 1, 0.6))
	add_child(_hint)
	_flash = Label.new()
	_flash.add_theme_font_size_override("font_size", 26)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.set_anchors_preset(Control.PRESET_CENTER)
	_flash.position = Vector2(-300, -120)
	_flash.size = Vector2(600, 40)
	_flash.modulate = Color(1, 1, 1, 0)
	add_child(_flash)
	_build_role_panel()
	GameState.tasks_updated.connect(_on_tasks_updated)


func _build_role_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_role_panel = PanelContainer.new()
	_role_panel.custom_minimum_size = Vector2(420, 200)
	center.add_child(_role_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_role_panel.add_child(vbox)
	_role_text = Label.new()
	_role_text.add_theme_font_size_override("font_size", 20)
	_role_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_role_text)
	var ok := Button.new()
	ok.text = "Entendido"
	ok.pressed.connect(func() -> void: _role_panel.visible = false)
	vbox.add_child(ok)
	_role_panel.visible = false


func show_role(is_impostor: bool) -> void:
	if is_impostor:
		_role_text.text = "Eres el IMPOSTOR.\nElimina a la tripulacion sin ser visto.\n[Q] matar · [E] ductos y fingir"
		_role_label.text = "Rol: IMPOSTOR"
		_role_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		_role_text.text = "Eres TRIPULANTE.\nCompleta tareas y encuentra al impostor.\n[E] tareas · [R] reportar"
		_role_label.text = "Rol: TRIPULANTE"
		_role_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
	_role_panel.visible = true


func refresh_tasks() -> void:
	_progress.value = GameState.task_progress()
	_progress_label.text = "Tareas %d/%d" % [GameState.done_tasks, GameState.total_tasks]
	if task_manager != null:
		if GameState.get_role(GameState.player_id) == GameState.Role.IMPOSTOR:
			_task_list.text = "(impostor: finge tareas)"
			return
		var names: Array = task_manager.pending_task_names(GameState.player_id)
		if names.is_empty():
			_task_list.text = "(sin tareas)"
		else:
			_task_list.text = "\n".join(names)


func set_hint(txt: String) -> void:
	_hint.text = txt


func set_kill_cd(cd: float, max_cd: float) -> void:
	if cd > 0.0:
		_kill_label.text = "Kill: %ds" % int(ceil(cd))
	else:
		_kill_label.text = "Kill listo [Q]"
	_kill_label.visible = true


func hide_kill() -> void:
	_kill_label.visible = false


func flash_message(txt: String) -> void:
	_flash.text = txt
	_flash.modulate = Color(1, 1, 1, 1)
	_flash_t = 2.2


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.modulate = Color(1, 1, 1, 0)


func _on_tasks_updated(done: int, total: int) -> void:
	_progress.value = GameState.task_progress()
	_progress_label.text = "Tareas %d/%d" % [done, total]
