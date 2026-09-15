class_name Game
extends Node2D
## Orquestador de la partida: spawn, acciones, asesinatos, reuniones y fin.

const INTERACT_RANGE := 70.0
const KILL_RANGE := 80.0
const REPORT_RANGE := 130.0
const TABLE_RANGE := 170.0
const TASKS_PER_CREW := 3

var rng := RandomNumberGenerator.new()
var time := 0.0
var characters: Array[Character] = []
var npcs: Array[NPC] = []
var player: Player
var bodies: Array[Body] = []
var player_tasks: Array[TaskStation] = []
var player_done: Array[TaskStation] = []
var kill_cooldown := GameState.KILL_COOLDOWN
var emergency_left := 1
var camera: ShakeCamera
var frozen := true
var _pending_eject := VoteLogic.SKIP

@onready var map: ShipMap = $ShipMap
@onready var bodies_node: Node2D = $Bodies
@onready var characters_node: Node2D = $Characters
@onready var hud: HUD = $HUD
@onready var task_host: TaskHost = $TaskHost
@onready var meeting: MeetingManager = $MeetingManager
@onready var meeting_ui: MeetingUI = $MeetingUI
@onready var transition: Transition = $Transition
@onready var end_screen: EndScreen = $EndScreen


func _ready() -> void:
	rng.randomize()
	GameState.new_game(rng)
	_spawn_characters()
	_assign_tasks()
	hud.game = self
	task_host.task_completed.connect(_on_player_task_done)
	meeting.finished.connect(_on_meeting_finished)
	meeting_ui.ejection_done.connect(_on_ejection_done)
	var imp := GameState.player_is_impostor()
	transition.play("ERES EL IMPOSTOR" if imp else "ERES TRIPULANTE",
		Color(1, 0.2, 0.2) if imp else Color(0.4, 0.85, 1), func() -> void: frozen = false, 1.8)


func _spawn_characters() -> void:
	var spots := map.meeting_spots(GameState.PLAYER_COUNT)
	for i in GameState.PLAYER_COUNT:
		var c: Character
		if i == GameState.PLAYER_ID:
			c = Player.new()
		else:
			c = NPC.new()
		c.setup(i, self)
		c.position = spots[i]
		characters_node.add_child(c)
		characters.append(c)
		if c is NPC:
			npcs.append(c as NPC)
	player = characters[GameState.PLAYER_ID] as Player
	camera = ShakeCamera.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	camera.make_current()


func _assign_tasks() -> void:
	for c in characters:
		var pool := map.stations.duplicate()
		pool.shuffle()
		var picks: Array[TaskStation] = []
		for i in TASKS_PER_CREW:
			picks.append(pool[i])
		if c == player:
			player_tasks = picks
			for s in picks:
				s.highlighted = true
		else:
			(c as NPC).tasks = picks
		if not GameState.is_impostor(c.char_id):
			GameState.register_tasks(c.char_id, TASKS_PER_CREW)


func is_playing() -> bool:
	return GameState.phase == GameState.Phase.PLAYING and not frozen


func _process(delta: float) -> void:
	if not is_playing():
		return
	time += delta
	kill_cooldown = maxf(kill_cooldown - delta, 0.0)


# --- Consultas ------------------------------------------------------------

func can_see(from: Vector2, to: Vector2, radius: float) -> bool:
	if from.distance_to(to) > radius:
		return false
	var q := PhysicsRayQueryParameters2D.create(from, to, ShipMap.WALL_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Personajes vivos (distintos de asesino y víctima) que verían el asesinato.
func witnesses(killer: Character, victim: Character) -> Array[Character]:
	var out: Array[Character] = []
	for c in characters:
		if c == killer or c == victim or not c.alive:
			continue
		if can_see(c.global_position, killer.global_position, NPC.CREW_SIGHT):
			out.append(c)
	return out


func alive_ids() -> Array[int]:
	var ids: Array[int] = []
	for c in characters:
		if c.alive:
			ids.append(c.char_id)
	return ids


func _nearest_body(p: Vector2, r: float) -> Body:
	for b in bodies:
		if b.global_position.distance_to(p) < r:
			return b
	return null


func _nearest_station(p: Vector2) -> TaskStation:
	for s in player_tasks:
		if s.global_position.distance_to(p) < INTERACT_RANGE:
			return s
	return null


func _nearest_vent(p: Vector2) -> Vent:
	for v in map.vents:
		if v.global_position.distance_to(p) < INTERACT_RANGE:
			return v
	return null


func _nearest_victim(p: Vector2) -> Character:
	var best: Character = null
	for c in characters:
		if c != player and c.alive and c.global_position.distance_to(p) < KILL_RANGE:
			if best == null or c.global_position.distance_to(p) < best.global_position.distance_to(p):
				best = c
	return best


# --- Acciones del jugador ------------------------------------------------

func player_can_act() -> bool:
	return is_playing() and not task_host.game_open


func player_can_interact() -> bool:
	if not player.alive:
		return false
	if GameState.player_is_impostor():
		return _nearest_vent(player.global_position) != null
	return _nearest_station(player.global_position) != null


func player_interact() -> void:
	if not player_can_interact():
		return
	if GameState.player_is_impostor():
		use_vent(player, _nearest_vent(player.global_position))
	else:
		task_host.open(_nearest_station(player.global_position))


func player_nearby_body() -> Body:
	return _nearest_body(player.global_position, REPORT_RANGE) if player.alive else null


func player_report() -> void:
	var b := player_nearby_body()
	if b != null:
		report_body(player, b)


func player_can_kill() -> bool:
	return player.alive and GameState.player_is_impostor() and kill_cooldown <= 0.0 \
		and _nearest_victim(player.global_position) != null


func player_kill() -> void:
	if player_can_kill():
		try_kill(player, _nearest_victim(player.global_position))


func player_can_emergency() -> bool:
	return player.alive and emergency_left > 0 \
		and player.global_position.distance_to(ShipMap.table_position()) < TABLE_RANGE


func player_emergency() -> void:
	if player_can_emergency():
		emergency_left -= 1
		start_meeting(player.char_id, -1, "")


# --- Eventos de juego -------------------------------------------------------

func try_kill(killer: Character, victim: Character) -> bool:
	if not is_playing() or not killer.alive or not victim.alive or kill_cooldown > 0.0:
		return false
	if not GameState.is_impostor(killer.char_id) or killer.global_position.distance_to(victim.global_position) > KILL_RANGE + 10.0:
		return false
	var seen_by := witnesses(killer, victim)
	var pos := victim.global_position
	victim.die()
	GameState.mark_dead(victim.char_id)
	var body := Body.new()
	body.victim_id = victim.char_id
	body.body_color = victim.body_color
	body.time_of_death = time
	body.position = pos
	bodies_node.add_child(body)
	bodies.append(body)
	killer.teleport(pos)
	Effects.blood_burst(bodies_node, pos, victim.body_color)
	kill_cooldown = GameState.KILL_COOLDOWN
	for w in seen_by:
		if w is NPC:
			(w as NPC).witness_kill(killer, body)
	if victim == player:
		task_host.close_task()
		for s in player_tasks:
			s.highlighted = false
		camera.shake(18.0)
		hud.toast("¡%s te asesinó!" % killer.char_name, Color(1, 0.3, 0.3))
	elif killer == player:
		camera.shake(8.0)
	_check_win()
	return true


func use_vent(c: Character, vent: Vent) -> void:
	if vent == null or not GameState.is_impostor(c.char_id):
		return
	for n in npcs:
		if n != c and n.alive and can_see(n.global_position, c.global_position, NPC.CREW_SIGHT * 0.8):
			n.witness_vent(c)
	Effects.puff(bodies_node, c.global_position)
	c.teleport(vent.partner.global_position + Vector2(0, 36))
	Effects.puff(bodies_node, c.global_position)
	if c == player:
		camera.reset_smoothing()


func npc_complete_task(n: NPC, _station: TaskStation) -> void:
	if GameState.is_impostor(n.char_id):
		return
	GameState.complete_task(n.char_id)
	_check_win()


func _on_player_task_done(s: TaskStation) -> void:
	if not player.alive or not player_tasks.has(s):
		return
	player_tasks.erase(s)
	player_done.append(s)
	s.highlighted = false
	if not GameState.player_is_impostor():
		GameState.complete_task(player.char_id)
	hud.toast("Tarea completada", Color(0.4, 1, 0.5))
	_check_win()


func report_body(reporter: Character, body: Body) -> void:
	if not is_playing() or body.reported or not reporter.alive:
		return
	body.reported = true
	for n in npcs:
		if n.alive:
			n.on_body_found(body.global_position)
	start_meeting(reporter.char_id, body.victim_id, ShipMap.room_name_at(body.global_position))


func start_meeting(caller: int, victim: int, room: String) -> void:
	frozen = true
	GameState.set_phase(GameState.Phase.MEETING)
	task_host.close_task()
	camera.shake(16.0 if victim >= 0 else 8.0)
	var title := "¡CADÁVER REPORTADO!" if victim >= 0 else "¡REUNIÓN DE EMERGENCIA!"
	transition.play(title, Color(1, 0.25, 0.2), _begin_meeting.bind(caller, victim, room))


func _begin_meeting(caller: int, victim: int, room: String) -> void:
	var spots := map.meeting_spots(GameState.PLAYER_COUNT)
	for c in characters:
		c.teleport(spots[c.char_id])
	camera.reset_smoothing()
	for b in bodies:
		b.queue_free()
	bodies.clear()
	var text := "%s convocó una reunión de emergencia." % GameState.NAMES[caller]
	if victim >= 0:
		text = "%s reportó el cadáver de %s (%s)." % [GameState.NAMES[caller], GameState.NAMES[victim], room]
	meeting.start(npcs, alive_ids(), caller, victim, room, rng)
	meeting_ui.open(meeting, text)


func _on_meeting_finished(ejected: int) -> void:
	_pending_eject = ejected
	meeting_ui.show_ejection(ejected)


func _on_ejection_done() -> void:
	var e := _pending_eject
	_pending_eject = VoteLogic.SKIP
	if e >= 0:
		characters[e].die()
		GameState.mark_dead(e)
		if e == player.char_id:
			for s in player_tasks:
				s.highlighted = false
	if _check_win():
		return
	resume_after_meeting()


func resume_after_meeting() -> void:
	kill_cooldown = GameState.KILL_COOLDOWN
	GameState.set_phase(GameState.Phase.PLAYING)
	frozen = false
	for n in npcs:
		if n.alive:
			n.reset_ai()


func _check_win() -> bool:
	if GameState.phase == GameState.Phase.ENDED:
		return true
	var w := GameState.evaluate_winner()
	if w < 0:
		return false
	var reason := "El impostor eliminó a la tripulación."
	if w == GameState.Role.CREW:
		reason = "El impostor fue expulsado." if not GameState.alive[GameState.impostor_id] else "Se completaron todas las tareas."
	frozen = true
	GameState.finish(w, reason)
	task_host.close_task()
	meeting_ui.close()
	get_tree().create_timer(1.2).timeout.connect(end_screen.show_result)
	return true
