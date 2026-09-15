extends Node
## Escena de test: corre logica pura + integracion real sin render.
## Uso: godot4 --headless res://scenes/test_logic.tscn

const TASK_UI_SCRIPT := preload("res://scripts/task_ui.gd")

var _failures: Array = []
var _checks: int = 0


func _ready() -> void:
	_check(GameState.has_method("setup_match"), "autoload GameState presente")
	_pure_tests()
	await get_tree().process_frame
	await _integration_test()
	_report()


func _check(cond: bool, test_name: String) -> void:
	_checks += 1
	if cond:
		print("PASS: ", test_name)
	else:
		_failures.append(test_name)
		push_error("FAIL: " + test_name)


func _pure_tests() -> void:
	var ids: Array = []
	for i in 8:
		ids.append(i)
	GameState.setup_match(ids, 3)
	_check(GameState.player_id == 3, "player id asignado")
	_check(GameState.alive_impostors() == 1, "exactamente 1 impostor")
	_check(GameState.alive_crew() == 7, "7 tripulantes")
	_check(GameState.phase == GameState.Phase.PLAY, "fase PLAY tras setup")
	GameState.record_sighting(1, 2, 3.0)
	_check(is_equal_approx(GameState.get_suspicion(1, 2), 3.0), "sospecha acumulada")
	_check(GameState.compute_npc_vote(1, [1, 2, 4]) == 2, "voto por sospecha alta")
	var v: int = GameState.compute_npc_vote(5, [5, 6, 7])
	_check(v == 6 or v == 7 or v == -1, "voto ponderado/skip sin info")
	_check(GameState.compute_npc_vote(5, [5]) == -1, "sin candidatos -> skip")
	GameState.set_tasks_total(10)
	for i in 5:
		GameState.complete_task()
	_check(is_equal_approx(GameState.task_progress(), 0.5), "progreso tareas 50%")
	var crew_ids: Array = []
	for info in GameState.player_infos:
		if int(info["role"]) == GameState.Role.CREW:
			crew_ids.append(int(info["id"]))
	GameState.record_kill(int(crew_ids[0]))
	GameState.record_kill(int(crew_ids[1]))
	_check(GameState.alive_crew() == 5, "kills restan vivos")
	# 1v1 -> gana impostor.
	for i in crew_ids.size() - 1:
		if i < 2:
			continue
		GameState.record_kill(int(crew_ids[i]))
	_check(GameState.winner == GameState.WinState.IMPOSTOR, "impostor gana en 1v1")
	GameState.reset()
	GameState.setup_match(ids, 0)
	var imp: int = -1
	for info in GameState.player_infos:
		if int(info["role"]) == GameState.Role.IMPOSTOR:
			imp = int(info["id"])
	GameState.set_tasks_total(4)
	GameState.eject(imp)
	_check(GameState.winner == GameState.WinState.CREW, "tripulantes ganan al expulsar")
	GameState.reset()
	GameState.setup_match(ids, 0)
	GameState.set_tasks_total(2)
	GameState.complete_task()
	GameState.complete_task()
	_check(GameState.winner == GameState.WinState.CREW, "tripulantes ganan por tareas")
	GameState.reset()
	_check(TASK_UI_SCRIPT.check_code_entered("12345", "12345"), "codigo correcto")
	_check(not TASK_UI_SCRIPT.check_code_entered("12345", "12344"), "codigo incorrecto")
	_check(TASK_UI_SCRIPT.calibrate_success(0.5, 0.52, 0.08), "calibracion en zona")
	_check(not TASK_UI_SCRIPT.calibrate_success(0.1, 0.6, 0.08), "calibracion fuera de zona")
	print("PASS: logica pura OK (", _checks, " checks)")


func _integration_test() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game: Node = packed.instantiate()
	add_child(game)
	for i in 10:
		await get_tree().physics_frame
	game.start_game()
	for i in 120:
		await get_tree().physics_frame
	_check(game.get_tree().get_nodes_in_group("characters").size() == 8, "8 personajes spawneados")
	_check(game.get_tree().get_nodes_in_group("task_stations").size() == 9, "9 estaciones")
	_check(game.get_tree().get_nodes_in_group("vents").size() == 2, "2 ductos")
	_check(GameState.total_tasks > 0, "tareas repartidas")
	var active: bool = false
	for s in 3:
		for i in 60:
			await get_tree().physics_frame
		for n in game.get_tree().get_nodes_in_group("characters"):
			if (n as CharacterBody2D).velocity.length() > 10.0:
				active = true
	_check(active, "NPCs se mueven con NavigationAgent2D")
	var imp: int = -1
	var victim: int = -1
	for info in GameState.player_infos:
		if int(info["role"]) == GameState.Role.IMPOSTOR:
			imp = int(info["id"])
		elif victim == -1:
			victim = int(info["id"])
	game.do_kill(imp, victim)
	for i in 5:
		await get_tree().physics_frame
	_check(game.get_tree().get_nodes_in_group("corpses").size() == 1, "kill deja cadaver")
	_check(not GameState.is_alive(victim), "victima marcada muerta")
	var reporter: int = -1
	for info in GameState.player_infos:
		var cid: int = int(info["id"])
		if bool(info["alive"]) and cid != imp:
			reporter = cid
			break
	var corpse: Node = game.get_tree().get_nodes_in_group("corpses")[0]
	game.start_meeting(reporter, corpse)
	await get_tree().process_frame
	_check(game.meeting.visible, "reunion visible")
	_check(get_tree().paused, "juego pausado en reunion")
	game.meeting.set("_time_left", 0.05)
	var waited: int = 0
	while not bool(game.meeting.get("_tallied")) and waited < 3000:
		await get_tree().process_frame
		waited += 1
	game.meeting.set("_end_delay", 0.05)
	waited = 0
	while game.meeting.visible and waited < 3000:
		await get_tree().process_frame
		waited += 1
	_check(not game.meeting.visible, "votacion termina y cierra")
	_check(GameState.phase != GameState.Phase.MEETING, "fase sale de MEETING")
	game.queue_free()
	GameState.reset()


func _report() -> void:
	if _failures.is_empty():
		print("TEST OK: ", _checks, " checks pasados, 0 fallos")
	else:
		push_error("TEST FALLOS: " + str(_failures))
	get_tree().quit(1 if not _failures.is_empty() else 0)
