class_name NPC
extends Character
## IA con máquina de estados y NavigationAgent2D.

enum State { DEAMBULAR, IR_A_TAREA, HACER_TAREA, HUIR, REPORTAR_CADAVER, ACECHAR, MATAR, FINGIR_TAREA }

const CREW_SIGHT := 300.0
const IMPOSTOR_SIGHT := 420.0
const KILL_RANGE := 70.0
const REPORT_RANGE := 90.0
const NPC_SPEED := 160.0

var state: int = State.DEAMBULAR
var state_time := 0.0
var tasks: Array[TaskStation] = []
var suspicion := {}      # id -> float
var last_seen := {}      # id -> [Vector2, tiempo]
var agent: NavigationAgent2D

var _target_char: Character
var _target_body: Body
var _target_station: TaskStation
var _target_vent: Vent
var _flee_from := Vector2.ZERO
var _wait := 0.0
var _perceive_timer := 0.0
var _stuck_timer := 0.0
var _last_pos := Vector2.ZERO
var _fake_next := false


func _ready() -> void:
	super()
	agent = NavigationAgent2D.new()
	agent.path_desired_distance = 10.0
	agent.target_desired_distance = 16.0
	agent.radius = 14.0
	add_child(agent)


func is_impostor() -> bool:
	return GameState.is_impostor(char_id)


func sight() -> float:
	return IMPOSTOR_SIGHT if is_impostor() else CREW_SIGHT


func state_name() -> String:
	return State.keys()[state]


func enter(s: int) -> void:
	state = s
	state_time = 0.0
	velocity = Vector2.ZERO


## Llamado tras reuniones o teletransportes.
func reset_ai() -> void:
	_target_char = null
	_target_body = null
	_target_vent = null
	agent.target_position = global_position
	enter(State.DEAMBULAR)
	_decide()


func _physics_process(delta: float) -> void:
	if not alive or not game.is_playing():
		velocity = Vector2.ZERO
		return
	if NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return
	state_time += delta
	_perceive_timer -= delta
	if _perceive_timer <= 0.0:
		_perceive_timer = 0.25
		_perceive()
	match state:
		State.DEAMBULAR: _st_wander()
		State.IR_A_TAREA: _st_go_task()
		State.HACER_TAREA, State.FINGIR_TAREA: _st_do_task(delta)
		State.HUIR: _st_flee()
		State.REPORTAR_CADAVER: _st_report()
		State.ACECHAR: _st_stalk()
		State.MATAR: _st_kill()
	_check_stuck(delta)


# --- Percepción ---------------------------------------------------------

func _perceive() -> void:
	var now := game.time
	for c: Character in game.characters:
		if c == self or not c.alive:
			continue
		if game.can_see(global_position, c.global_position, sight()):
			last_seen[c.char_id] = [c.global_position, now]
	if is_impostor() or state == State.REPORTAR_CADAVER or state == State.HUIR:
		return
	for b: Body in game.bodies:
		if game.can_see(global_position, b.global_position, sight()):
			_target_body = b
			enter(State.REPORTAR_CADAVER)
			return


## Presenció un asesinato.
func witness_kill(killer: Character, body: Body) -> void:
	add_suspicion(killer.char_id, 100.0)
	_target_body = body
	_flee_from = killer.global_position
	enter(State.HUIR)
	_nav_to(_far_room_point(_flee_from))


## Vio al jugador salir/entrar de un ducto.
func witness_vent(c: Character) -> void:
	add_suspicion(c.char_id, 60.0)


## Al descubrirse un cadáver: sospecha por quién estuvo cerca recientemente.
func on_body_found(body_pos: Vector2) -> void:
	for id: int in last_seen:
		var entry: Array = last_seen[id]
		var pos: Vector2 = entry[0]
		var age := game.time - float(entry[1])
		var dist := pos.distance_to(body_pos)
		if dist < 450.0 and age < 30.0:
			add_suspicion(id, (1.0 - dist / 450.0) * (1.0 - age / 30.0) * 40.0)


func add_suspicion(id: int, amount: float) -> void:
	if id == char_id:
		return
	suspicion[id] = float(suspicion.get(id, 0.0)) + amount


# --- Estados --------------------------------------------------------------

func _st_wander() -> void:
	if _move() or state_time > 9.0:
		_decide()


func _st_go_task() -> void:
	if _target_station == null:
		_decide()
		return
	_nav_to(_target_station.global_position)
	if _move() or global_position.distance_to(_target_station.global_position) < 45.0:
		_wait = game.rng.randf_range(3.0, 5.5)
		enter(State.FINGIR_TAREA if _fake_next else State.HACER_TAREA)
		_fake_next = false


func _st_do_task(delta: float) -> void:
	velocity = Vector2.ZERO
	_wait -= delta
	if state == State.FINGIR_TAREA and is_impostor() and game.kill_cooldown <= 0.0 and state_time > 1.5:
		_decide()
		return
	if _wait > 0.0:
		return
	if state == State.HACER_TAREA and _target_station != null:
		tasks.erase(_target_station)
		game.npc_complete_task(self, _target_station)
		_target_station = null
	_decide()


func _st_flee() -> void:
	if _target_vent != null:
		_nav_to(_target_vent.global_position)
		if global_position.distance_to(_target_vent.global_position) < 40.0:
			game.use_vent(self, _target_vent)
			_target_vent = null
			enter(State.DEAMBULAR)
			_nav_to(ShipMap.random_point_in_room(game.rng.randi_range(0, ShipMap.room_count() - 1), game.rng))
			return
		_move()
		return
	var arrived := _move()
	if arrived or state_time > 4.0:
		if _target_body != null and is_instance_valid(_target_body) and not is_impostor():
			enter(State.REPORTAR_CADAVER)
		else:
			_decide()


func _st_report() -> void:
	if _target_body == null or not is_instance_valid(_target_body):
		_decide()
		return
	_nav_to(_target_body.global_position)
	_move()
	if global_position.distance_to(_target_body.global_position) < REPORT_RANGE:
		game.report_body(self, _target_body)
	elif state_time > 20.0:
		_decide()


func _st_stalk() -> void:
	if _target_char == null or not _target_char.alive or state_time > 14.0:
		_decide()
		return
	_nav_to(_target_char.global_position)
	_move()
	if game.kill_cooldown <= 0.0 and global_position.distance_to(_target_char.global_position) < KILL_RANGE \
			and game.witnesses(self, _target_char).is_empty():
		enter(State.MATAR)


func _st_kill() -> void:
	if _target_char != null and _target_char.alive and game.try_kill(self, _target_char):
		_flee_from = global_position
		_target_vent = null
		for v: Vent in game.map.vents:
			if v.global_position.distance_to(global_position) < 350.0 and game.rng.randf() < 0.7:
				_target_vent = v
		enter(State.HUIR)
		_nav_to(_far_room_point(_flee_from))
	else:
		enter(State.ACECHAR)


# --- Decisión ----------------------------------------------------------

func _decide() -> void:
	if is_impostor():
		_decide_impostor()
		return
	if not tasks.is_empty() and game.rng.randf() < 0.8:
		_target_station = tasks[game.rng.randi_range(0, tasks.size() - 1)]
		_fake_next = false
		enter(State.IR_A_TAREA)
		_nav_to(_target_station.global_position)
	else:
		enter(State.DEAMBULAR)
		_nav_to(ShipMap.random_point_in_room(game.rng.randi_range(0, ShipMap.room_count() - 1), game.rng))


func _decide_impostor() -> void:
	if game.kill_cooldown <= 3.0:
		var target := _pick_victim()
		if target != null:
			_target_char = target
			enter(State.ACECHAR)
			return
	if game.rng.randf() < 0.6:
		_target_station = game.map.stations[game.rng.randi_range(0, game.map.stations.size() - 1)]
		enter(State.IR_A_TAREA)   # camina a la consola y luego finge
		_nav_to(_target_station.global_position)
		_fake_next = true
	else:
		enter(State.DEAMBULAR)
		_nav_to(ShipMap.random_point_in_room(game.rng.randi_range(0, ShipMap.room_count() - 1), game.rng))


## Prefiere víctimas aisladas y cercanas.
func _pick_victim() -> Character:
	var best: Character = null
	var best_score := INF
	for c: Character in game.characters:
		if c == self or not c.alive:
			continue
		var score := global_position.distance_to(c.global_position)
		for o: Character in game.characters:
			if o != c and o != self and o.alive and o.global_position.distance_to(c.global_position) < CREW_SIGHT:
				score += 600.0
		if score < best_score:
			best_score = score
			best = c
	return best


# --- Movimiento --------------------------------------------------------

func _nav_to(p: Vector2) -> void:
	if agent.target_position.distance_to(p) > 24.0:
		agent.target_position = p


## Avanza por el camino. Devuelve true si llegó.
func _move() -> bool:
	if agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return true
	var next := agent.get_next_path_position()
	velocity = global_position.direction_to(next) * NPC_SPEED
	move_and_slide()
	return false


func _far_room_point(from: Vector2) -> Vector2:
	var best := 0
	for i in ShipMap.room_count():
		if ShipMap.room_center(i).distance_to(from) > ShipMap.room_center(best).distance_to(from):
			best = i
	return ShipMap.random_point_in_room(best, game.rng)


func _check_stuck(delta: float) -> void:
	if velocity == Vector2.ZERO:
		_stuck_timer = 0.0
		_last_pos = global_position
		return
	_stuck_timer += delta
	if _stuck_timer > 2.0:
		if global_position.distance_to(_last_pos) < 20.0 and state != State.ACECHAR:
			enter(State.DEAMBULAR)
			_nav_to(ShipMap.random_point_in_room(game.rng.randi_range(0, ShipMap.room_count() - 1), game.rng))
		_stuck_timer = 0.0
		_last_pos = global_position
