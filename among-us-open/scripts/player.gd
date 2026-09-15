extends CharacterBody2D
## Jugador humano: movimiento WASD/flechas + acciones E/R/Q/Espacio.

const SPEED: float = 205.0

var pid: int = 0
var pname: String = "TU"
var pcolor := Color.RED
var main_ref: Node = null
var kill_cd: float = 0.0

var _visual: Node2D = null
var _light: PointLight2D = null
var _camera: Camera2D = null
var _shake: float = 0.0


func setup(id: int, aname: String, color_value: Color, game_root: Node) -> void:
	pid = id
	pname = aname
	pcolor = color_value
	main_ref = game_root


func _ready() -> void:
	add_to_group("characters")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 12.0
	capsule.height = 28.0
	shape.shape = capsule
	add_child(shape)
	_visual = preload("res://scripts/character_visual.gd").new()
	_visual.setup(pcolor)
	add_child(_visual)
	_light = PointLight2D.new()
	_light.texture = _make_glow_texture()
	_light.energy = 1.1
	_light.shadow_enabled = true
	add_child(_light)
	_update_light_range()
	var label := Label.new()
	label.text = pname
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -66)
	label.size = Vector2(100, 22)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	add_child(_camera)
	_camera.make_current()


func _update_light_range() -> void:
	if GameState.get_role(pid) == GameState.Role.IMPOSTOR:
		_light.texture_scale = GameState.IMPOSTOR_LIGHT
	else:
		_light.texture_scale = GameState.CREW_LIGHT


func get_pid() -> int:
	return pid


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _make_glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _physics_process(_delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAY or main_ref == null or main_ref.is_blocking():
		velocity = Vector2.ZERO
		move_and_slide()
		_visual.moving = false
		return
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	_visual.moving = dir.length() > 0.1
	if absf(dir.x) > 0.1:
		_visual.face_dir = signf(dir.x)


func _process(delta: float) -> void:
	if kill_cd > 0.0:
		kill_cd = maxf(kill_cd - delta, 0.0)
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 14.0, 0.0)
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		_camera.offset = Vector2.ZERO
	if GameState.phase != GameState.Phase.PLAY or main_ref == null or main_ref.is_blocking():
		return
	_update_hint()
	_update_vent_highlight()
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	elif Input.is_action_just_pressed("report"):
		_try_report()
	elif Input.is_action_just_pressed("kill_action"):
		_try_kill()
	elif Input.is_action_just_pressed("emergency"):
		_try_emergency()


func _update_hint() -> void:
	var hint: String = ""
	var crew: bool = GameState.get_role(pid) != GameState.Role.IMPOSTOR
	var station: Node = _nearest_in_group("task_stations", GameState.INTERACT_RANGE)
	if station != null:
		if crew and main_ref.task_manager.is_station_pending_for(pid, station.station_id):
			hint = "[E] Hacer tarea: " + station.task_name
		elif not crew:
			hint = "[E] Fingir tarea"
	if hint.is_empty() and not crew:
		if _nearest_in_group("vents", GameState.VENT_RANGE) != null:
			hint = "[E] Usar ducto"
	if hint.is_empty():
		if _nearest_corpse(GameState.REPORT_RANGE) != null:
			hint = "[R] Reportar cadaver"
	if hint.is_empty() and not crew and kill_cd <= 0.0:
		if _nearest_victim(GameState.KILL_RANGE) != null:
			hint = "[Q] Matar"
	if hint.is_empty() and _near_table() and GameState.emergencies_left > 0:
		hint = "[ESPACIO] Reunion de emergencia"
	main_ref.hud.set_hint(hint)
	if not crew:
		main_ref.hud.set_kill_cd(kill_cd, GameState.KILL_COOLDOWN)


func _update_vent_highlight() -> void:
	var crew: bool = GameState.get_role(pid) != GameState.Role.IMPOSTOR
	for v in get_tree().get_nodes_in_group("vents"):
		v.highlight = (not crew) and v.global_position.distance_to(global_position) < 260.0


func _try_interact() -> void:
	var crew: bool = GameState.get_role(pid) != GameState.Role.IMPOSTOR
	var station: Node = _nearest_in_group("task_stations", GameState.INTERACT_RANGE)
	if station != null:
		if crew:
			if main_ref.task_manager.is_station_pending_for(pid, station.station_id):
				main_ref.task_ui.open_task(station)
		else:
			main_ref.task_manager.fake_task_flash(station)
		return
	if not crew:
		var vent: Node = _nearest_in_group("vents", GameState.VENT_RANGE)
		if vent != null:
			main_ref.travel_vent(self)


func _try_report() -> void:
	var corpse: Node = _nearest_corpse(GameState.REPORT_RANGE)
	if corpse != null:
		main_ref.start_meeting(pid, corpse)


func _try_kill() -> void:
	if GameState.get_role(pid) != GameState.Role.IMPOSTOR or kill_cd > 0.0:
		return
	var victim: Node = _nearest_victim(GameState.KILL_RANGE)
	if victim != null:
		kill_cd = GameState.KILL_COOLDOWN
		main_ref.do_kill(pid, victim.get_pid())


func _try_emergency() -> void:
	if _near_table() and GameState.emergencies_left > 0:
		GameState.emergencies_left -= 1
		main_ref.start_meeting(pid, null)


func _near_table() -> bool:
	var table: Node = get_tree().get_first_node_in_group("meeting_table")
	if table == null:
		return false
	return table.global_position.distance_to(global_position) < GameState.INTERACT_RANGE


func _nearest_in_group(group_name: String, max_dist: float) -> Node:
	var best: Node = null
	var best_d: float = max_dist
	for n in get_tree().get_nodes_in_group(group_name):
		var n2d := n as Node2D
		if n2d == null:
			continue
		var d: float = n2d.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _nearest_corpse(max_dist: float) -> Node:
	var best: Node = null
	var best_d: float = max_dist
	for n in get_tree().get_nodes_in_group("corpses"):
		if bool(n.get("reported")):
			continue
		var n2d := n as Node2D
		if n2d == null:
			continue
		var d: float = n2d.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _nearest_victim(max_dist: float) -> Node:
	var best: Node = null
	var best_d: float = max_dist
	for n in get_tree().get_nodes_in_group("characters"):
		if n == self:
			continue
		if GameState.get_role(n.get_pid()) == GameState.Role.IMPOSTOR:
			continue
		var n2d := n as Node2D
		if n2d == null:
			continue
		var d: float = n2d.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
