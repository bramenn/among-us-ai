extends CharacterBody2D
## NPC con maquina de estados y navegacion por NavigationAgent2D.
## Tripulante: Deambular / IrATarea / HacerTarea / Huir / Reportar.
## Impostor: Acechar / Matar / Fingir tarea (+ ductos).

enum State { WANDER, GO_TO_TASK, DO_TASK, FLEE, REPORT_CORPSE, STALK, FAKE_TASK }

const CREW_SPEED: float = 165.0
const IMPOSTOR_SPEED: float = 182.0
const SIGHT_CORPSE: float = 280.0
const SIGHT_KILL: float = 380.0

var pid: int = 0
var pname: String = "NPC"
var pcolor := Color.BLUE

var _state: int = State.WANDER
var _agent: NavigationAgent2D = null
var _visual: Node2D = null
var _state_time: float = 0.0
var _percept_cd: float = 0.0
var _retarget_cd: float = 0.0
var _station: Node = null
var _victim_id: int = -1
var _threat_pos := Vector2.ZERO
var _corpse: Node = null
var _kill_cd: float = 8.0
var _vent_cd: float = 20.0
var _idle_point := Vector2.ZERO


func setup(id: int, aname: String, color_value: Color) -> void:
	pid = id
	pname = aname
	pcolor = color_value


func _ready() -> void:
	add_to_group("characters")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 12.0
	capsule.height = 28.0
	shape.shape = capsule
	add_child(shape)
	_agent = NavigationAgent2D.new()
	_agent.path_desired_distance = 12.0
	_agent.target_desired_distance = 24.0
	add_child(_agent)
	_visual = preload("res://scripts/character_visual.gd").new()
	_visual.setup(pcolor)
	add_child(_visual)
	var light := PointLight2D.new()
	light.texture = _make_glow_texture()
	light.energy = 1.0
	light.shadow_enabled = true
	if GameState.get_role(pid) == GameState.Role.IMPOSTOR:
		light.texture_scale = GameState.IMPOSTOR_LIGHT
		_state = State.STALK
	else:
		light.texture_scale = GameState.CREW_LIGHT
	add_child(light)
	var label := Label.new()
	label.text = pname
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -66)
	label.size = Vector2(100, 22)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	_idle_point = global_position
	_agent.target_position = global_position


func get_pid() -> int:
	return pid


func calm_down() -> void:
	_corpse = null
	_station = null
	_victim_id = -1
	_state = State.STALK if is_impostor() else State.WANDER
	_state_time = 0.0
	_agent.target_position = global_position


func is_impostor() -> bool:
	return GameState.get_role(pid) == GameState.Role.IMPOSTOR


func on_witnessed_kill(killer_id: int, killer_pos: Vector2) -> void:
	if not is_impostor():
		GameState.record_sighting(pid, killer_id, 3.0)
		_threat_pos = killer_pos
		_state = State.FLEE
		_state_time = 4.0


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


func _physics_process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAY:
		velocity = Vector2.ZERO
		move_and_slide()
		_visual.moving = false
		return
	_state_time -= delta
	_percept_cd -= delta
	_retarget_cd -= delta
	_kill_cd = maxf(_kill_cd - delta, 0.0)
	_vent_cd -= delta
	if _percept_cd <= 0.0:
		_percept_cd = 0.4
		_perceive()
	if is_impostor():
		_impostor_tick(delta)
	else:
		_crew_tick(delta)


func speed_value() -> float:
	return IMPOSTOR_SPEED if is_impostor() else CREW_SPEED


func _crew_tick(_delta: float) -> void:
	match _state:
		State.WANDER:
			if _arrived():
				_state_time = randf_range(1.0, 3.0)
				_pick_wander_target()
			_steer(speed_value())
			if _state_time <= -3.0:
				_request_task()
		State.GO_TO_TASK:
			if _station == null or not is_instance_valid(_station):
				_state = State.WANDER
				return
			_agent.target_position = (_station as Node2D).global_position
			_steer(speed_value())
			if _arrived_to((_station as Node2D).global_position, 70.0):
				_state = State.DO_TASK
				_state_time = randf_range(3.0, 6.0)
		State.DO_TASK:
			_visual.moving = false
			velocity = Vector2.ZERO
			move_and_slide()
			if _state_time <= 0.0:
				_finish_task()
		State.FLEE:
			_steer(speed_value() * 1.15)
			if _state_time <= 0.0:
				_state = State.WANDER
		State.REPORT_CORPSE:
			if _corpse == null or not is_instance_valid(_corpse) or bool(_corpse.get("reported")):
				_state = State.WANDER
				return
			_agent.target_position = (_corpse as Node2D).global_position
			_steer(speed_value() * 1.1)
			if _arrived_to((_corpse as Node2D).global_position, 95.0):
				var main_ref: Node = get_tree().get_first_node_in_group("main")
				if main_ref != null:
					main_ref.start_meeting(pid, _corpse)
				_state = State.WANDER


func _impostor_tick(_delta: float) -> void:
	if _vent_cd <= 0.0:
		_vent_cd = randf_range(20.0, 35.0)
		_try_vent_escape()
	match _state:
		State.STALK:
			_validate_victim()
			if _victim_id == -1:
				_state = State.FAKE_TASK
				_state_time = randf_range(3.0, 6.0)
				_pick_wander_target()
				return
			var target: Node2D = _char_by_id(_victim_id)
			if target == null:
				_victim_id = -1
				return
			if _retarget_cd <= 0.0:
				_retarget_cd = 1.0
				_agent.target_position = target.global_position
			_steer(IMPOSTOR_SPEED)
			var d: float = target.global_position.distance_to(global_position)
			if d < GameState.KILL_RANGE and _kill_cd <= 0.0 and not _watched():
				_kill_cd = GameState.KILL_COOLDOWN
				var main_ref: Node = get_tree().get_first_node_in_group("main")
				if main_ref != null:
					main_ref.do_kill(pid, _victim_id)
				_victim_id = -1
				_state = State.FAKE_TASK
				_state_time = randf_range(4.0, 7.0)
				_pick_wander_target()
		State.FAKE_TASK, State.WANDER:
			_steer(IMPOSTOR_SPEED * 0.8)
			if _state_time <= 0.0 or _arrived():
				_state = State.STALK
				_state_time = 0.0
		State.FLEE:
			_steer(IMPOSTOR_SPEED)
			if _state_time <= 0.0:
				_state = State.STALK


func _steer(speed: float) -> void:
	var next: Vector2 = _agent.get_next_path_position()
	var to_next: Vector2 = next - global_position
	var dir: Vector2
	if to_next.length() < 6.0 or _agent.is_navigation_finished():
		var goal: Vector2 = _agent.target_position - global_position
		if goal.length() < _agent.target_desired_distance + 4.0:
			velocity = Vector2.ZERO
			move_and_slide()
			_visual.moving = false
			return
		dir = goal.normalized()
	else:
		dir = to_next.normalized()
	velocity = dir * speed
	move_and_slide()
	_visual.moving = true
	if absf(dir.x) > 0.1:
		_visual.face_dir = signf(dir.x)


func _arrived() -> bool:
	if not _agent.is_navigation_finished():
		return false
	return global_position.distance_to(_agent.target_position) < _agent.target_desired_distance + 10.0


func _arrived_to(point: Vector2, radius: float) -> bool:
	return global_position.distance_to(point) < radius


func _pick_wander_target() -> void:
	var ship: Node = get_tree().get_first_node_in_group("ship")
	if ship != null:
		_agent.target_position = ship.get_random_point()
		_state_time = 0.0


func _request_task() -> void:
	var tm: Node = get_tree().get_first_node_in_group("task_manager")
	if tm == null:
		return
	var st: Node = tm.get_next_station_for(pid)
	if st != null:
		_station = st
		_state = State.GO_TO_TASK
	else:
		_pick_wander_target()


func _finish_task() -> void:
	var tm: Node = get_tree().get_first_node_in_group("task_manager")
	if tm != null and _station != null and is_instance_valid(_station):
		tm.complete_npc_task(pid, _station)
	_station = null
	_state = State.WANDER
	_state_time = 0.0
	_pick_wander_target()


func _perceive() -> void:
	if is_impostor():
		return
	for n in get_tree().get_nodes_in_group("corpses"):
		if bool(n.get("reported")):
			continue
		var c := n as Node2D
		if c == null:
			continue
		if c.global_position.distance_to(global_position) < SIGHT_CORPSE:
			_note_others_near_corpse(c.global_position)
			_corpse = n
			_state = State.REPORT_CORPSE
			return


func _note_others_near_corpse(corpse_pos: Vector2) -> void:
	for n in get_tree().get_nodes_in_group("characters"):
		if n == self:
			continue
		var c := n as Node2D
		if c == null:
			continue
		if c.global_position.distance_to(corpse_pos) < 320.0:
			GameState.record_sighting(pid, n.get_pid(), 1.0)


func _validate_victim() -> void:
	if _victim_id == -1 or not GameState.is_alive(_victim_id) or _char_by_id(_victim_id) == null:
		_victim_id = _pick_victim()


func _pick_victim() -> int:
	var best: int = -1
	var best_d: float = 1e9
	for n in get_tree().get_nodes_in_group("characters"):
		if n == self:
			continue
		var nid: int = n.get_pid()
		if not GameState.is_alive(nid):
			continue
		if GameState.get_role(nid) == GameState.Role.IMPOSTOR:
			continue
		var c := n as Node2D
		if c == null:
			continue
		var d: float = c.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = nid
	return best


func _char_by_id(nid: int) -> Node2D:
	for n in get_tree().get_nodes_in_group("characters"):
		if n.get_pid() == nid:
			return n as Node2D
	return null


func _watched() -> bool:
	for n in get_tree().get_nodes_in_group("characters"):
		if n == self:
			continue
		var nid: int = n.get_pid()
		if not GameState.is_alive(nid) or nid == _victim_id:
			continue
		if GameState.get_role(nid) == GameState.Role.IMPOSTOR:
			continue
		var c := n as Node2D
		if c == null:
			continue
		if c.global_position.distance_to(global_position) < SIGHT_KILL:
			return true
	return false


func _try_vent_escape() -> void:
	for n in get_tree().get_nodes_in_group("characters"):
		if n == self:
			continue
		var c := n as Node2D
		if c == null:
			continue
		if c.global_position.distance_to(global_position) < 400.0:
			return
	var main_ref: Node = get_tree().get_first_node_in_group("main")
	if main_ref != null:
		main_ref.travel_vent(self)
