extends Node2D
## Orquestador: crea nave, personajes, UI; kills, ductos, reuniones y fin.

const NAMES := ["Rojo", "Azul", "Verde", "Rosa", "Naranja", "Amarillo", "Morado", "Cian"]
const COLORS := [
	Color(0.85, 0.15, 0.15), Color(0.15, 0.35, 0.9), Color(0.2, 0.7, 0.25),
	Color(0.95, 0.55, 0.7), Color(0.95, 0.5, 0.1), Color(0.95, 0.85, 0.2),
	Color(0.55, 0.25, 0.8), Color(0.25, 0.85, 0.85)]

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const NPC_SCENE := preload("res://scenes/npc.tscn")
const CORPSE_SCRIPT := preload("res://scripts/corpse.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const MENU_SCENE := preload("res://ui/main_menu.tscn")
const TASK_SCENE := preload("res://ui/task_ui.tscn")
const MEETING_SCENE := preload("res://ui/meeting_ui.tscn")
const OVER_SCENE := preload("res://ui/game_over.tscn")
const PAUSE_SCENE := preload("res://ui/pause_menu.tscn")

var ship: Node2D = null
var task_manager: Node = null
var hud: CanvasLayer = null
var menu: Control = null
var task_ui: Control = null
var meeting: Control = null
var game_over_ui: Control = null
var pause_menu: Control = null
var fade: ColorRect = null
var spectate_cam: Camera2D = null
var _started: bool = false


func _ready() -> void:
	add_to_group("main")
	var bg: Node2D = preload("res://scripts/space_bg.gd").new()
	add_child(bg)
	menu = MENU_SCENE.instantiate()
	menu.main_ref = self
	add_child(menu)
	GameState.game_ended.connect(_on_game_ended)


func is_blocking() -> bool:
	if menu != null and menu.visible:
		return true
	if task_ui != null and task_ui.is_open():
		return true
	if meeting != null and meeting.visible:
		return true
	if game_over_ui != null and game_over_ui.visible:
		return true
	if pause_menu != null and pause_menu.visible:
		return true
	return get_tree().paused


func start_game() -> void:
	if _started:
		return
	_started = true
	ship = preload("res://scripts/ship_builder.gd").new()
	add_child(ship)
	task_manager = preload("res://scripts/task_manager.gd").new()
	add_child(task_manager)
	var ids: Array = []
	for i in 8:
		ids.append(i)
	var human_id: int = randi() % 8
	GameState.setup_match(ids, human_id)
	var order: Array = ids.duplicate()
	order.shuffle()
	var spots: Array = ship.spawn_points(8)
	for k in 8:
		var cid: int = int(order[k])
		_spawn_character(cid, spots[k], cid == human_id)
	var crew: Array = []
	for info in GameState.player_infos:
		if int(info["role"]) == GameState.Role.CREW:
			crew.append(int(info["id"]))
	task_manager.setup(crew, human_id)
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.task_manager = task_manager
	task_ui = TASK_SCENE.instantiate()
	add_child(task_ui)
	task_ui.task_manager = task_manager
	task_ui.hud = hud
	meeting = MEETING_SCENE.instantiate()
	add_child(meeting)
	meeting.main_ref = self
	game_over_ui = OVER_SCENE.instantiate()
	add_child(game_over_ui)
	game_over_ui.main_ref = self
	pause_menu = PAUSE_SCENE.instantiate()
	add_child(pause_menu)
	pause_menu.main_ref = self
	menu.visible = false
	hud.refresh_tasks()
	var impostor: bool = GameState.get_role(human_id) == GameState.Role.IMPOSTOR
	hud.show_role(impostor)
	if not impostor:
		hud.hide_kill()
	_fade_transition()
	hud.flash_message("La partida comenzo")


func _spawn_character(cid: int, pos: Vector2, is_human: bool) -> void:
	if is_human:
		var p: CharacterBody2D = PLAYER_SCENE.instantiate()
		p.position = pos
		add_child(p)
		p.setup(cid, NAMES[cid] + " (TU)", COLORS[cid], self)
	else:
		var n: CharacterBody2D = NPC_SCENE.instantiate()
		n.position = pos
		add_child(n)
		n.setup(cid, NAMES[cid], COLORS[cid])


func do_kill(killer_id: int, victim_id: int) -> void:
	if GameState.phase != GameState.Phase.PLAY:
		return
	var victim: Node2D = null
	var killer_pos := Vector2.ZERO
	for n in get_tree().get_nodes_in_group("characters"):
		var c := n as Node2D
		if c == null:
			continue
		if n.get_pid() == victim_id:
			victim = c
		if n.get_pid() == killer_id:
			killer_pos = c.global_position
	if victim == null:
		return
	var vpos: Vector2 = victim.global_position
	var corpse: Node2D = CORPSE_SCRIPT.new()
	corpse.position = vpos
	add_child(corpse)
	corpse.setup(victim.get("pcolor"), victim.get("pname"))
	corpse.add_to_group("corpses")
	_burst(vpos, Color(0.8, 0.05, 0.05))
	victim.queue_free()
	GameState.record_kill(victim_id)
	if victim_id == GameState.player_id:
		_enable_spectate()
	for n in get_tree().get_nodes_in_group("characters"):
		if n.get_pid() == killer_id or n.get_pid() == victim_id:
			continue
		var c := n as Node2D
		if c == null:
			continue
		if c.global_position.distance_to(vpos) < 380.0 and n.has_method("on_witnessed_kill"):
			n.on_witnessed_kill(killer_id, killer_pos)


func travel_vent(who: Node2D) -> void:
	var vents: Array = get_tree().get_nodes_in_group("vents")
	if vents.size() < 2:
		return
	var best: Node2D = vents[0]
	var best_d: float = -1.0
	for v in vents:
		var d: float = (v as Node2D).global_position.distance_to(who.global_position)
		if d > best_d:
			best_d = d
			best = v
	who.global_position = (best as Node2D).global_position
	_burst((best as Node2D).global_position, Color(0.6, 0.6, 0.65, 0.7))


func start_meeting(reporter_id: int, corpse: Node) -> void:
	if GameState.phase != GameState.Phase.PLAY:
		return
	if corpse != null:
		corpse.set("reported", true)
	GameState.phase = GameState.Phase.MEETING
	GameState.meeting_count += 1
	var seats: Array = ship.seat_positions()
	var chars: Array = get_tree().get_nodes_in_group("characters")
	var i: int = 0
	for n in chars:
		var c := n as Node2D
		if c == null:
			continue
		c.global_position = seats[i % seats.size()] + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		if c.has_method("calm_down"):
			c.calm_down()
		i += 1
	for n in get_tree().get_nodes_in_group("characters"):
		if n.get_pid() == GameState.player_id and n.has_method("add_shake"):
			n.add_shake(10.0)
	_fade_transition()
	var infos: Array = []
	for n in get_tree().get_nodes_in_group("characters"):
		infos.append({"id": n.get_pid(), "name": n.get("pname"), "color": n.get("pcolor")})
	get_tree().paused = true
	meeting.start_meeting(reporter_id, infos, corpse == null)


func finish_meeting(expelled_id: int, _votes: Dictionary) -> void:
	if expelled_id >= 0:
		GameState.eject(expelled_id)
		for n in get_tree().get_nodes_in_group("characters"):
			if n.get_pid() == expelled_id:
				_burst((n as Node2D).global_position, Color(0.5, 0.5, 0.55))
				n.queue_free()
	get_tree().paused = false
	if GameState.phase != GameState.Phase.MEETING:
		return
	GameState.phase = GameState.Phase.PLAY
	var seats: Array = ship.seat_positions()
	var i: int = 0
	for n in get_tree().get_nodes_in_group("characters"):
		(n as Node2D).global_position = seats[(i + 2) % seats.size()] + Vector2(randf_range(-40, 40), randf_range(30, 80))
		i += 1
	if GameState.check_win() == GameState.WinState.NONE:
		hud.refresh_tasks()
		hud.flash_message("Reunion terminada")


func toggle_pause() -> void:
	if GameState.phase != GameState.Phase.PLAY and not get_tree().paused:
		return
	if meeting != null and meeting.visible:
		return
	get_tree().paused = not get_tree().paused
	pause_menu.visible = get_tree().paused


func restart_game() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().reload_current_scene()


func back_to_menu() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	if not _started:
		return
	if Input.is_action_just_pressed("pause_game"):
		toggle_pause()
	_update_spectate()


func _enable_spectate() -> void:
	spectate_cam = Camera2D.new()
	spectate_cam.position_smoothing_enabled = true
	add_child(spectate_cam)
	spectate_cam.make_current()
	hud.flash_message("Has muerto. La partida continua...")


func _update_spectate() -> void:
	if spectate_cam == null:
		return
	for n in get_tree().get_nodes_in_group("characters"):
		var c := n as Node2D
		if c == null:
			continue
		spectate_cam.global_position = c.global_position
		return


func _on_game_ended(winner: int) -> void:
	get_tree().paused = false
	if pause_menu != null:
		pause_menu.visible = false
	if meeting != null:
		meeting.visible = false
	if task_ui != null:
		task_ui.visible = false
	game_over_ui.show_result(winner)


func _burst(pos: Vector2, color_value: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 26
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2.ZERO
	p.color = color_value
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _fade_transition() -> void:
	if fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 90
		add_child(layer)
		fade = ColorRect.new()
		fade.color = Color(0, 0, 0, 0)
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(fade)
	fade.color = Color(0, 0, 0, 1)
	var tw := create_tween()
	tw.tween_property(fade, "color", Color(0, 0, 0, 0), 0.6)
