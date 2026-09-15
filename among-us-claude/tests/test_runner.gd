extends Node
## Tests headless: lógica pura + partida simulada. Sale con código 1 si algo falla.
## Ejecutar: godot --headless --fixed-fps 60 res://tests/TestRunner.tscn

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _ready() -> void:
	print("== Lógica")
	_test_roles()
	_test_votes()
	_test_tasks_and_win()
	_test_minigames()
	var menu: Control = preload("res://ui/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu.get_child_count() > 0, "menú principal construye su UI")
	_check_on_screen(menu, "menú")
	menu.queue_free()
	print("== Partida")
	await _test_game()
	print("RESULT: %s (%d fallos)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_roles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var player_imp := 0
	for i in 200:
		GameState.new_game(rng)
		check_silent(GameState.roles.count(GameState.Role.IMPOSTOR) == 1, "exactamente 1 impostor")
		if GameState.player_is_impostor():
			player_imp += 1
	check(player_imp > 0 and player_imp < 200, "el jugador puede ser impostor o tripulante (%d/200)" % player_imp)


func check_silent(cond: bool, msg: String) -> void:
	if not cond:
		check(false, msg)


func _test_votes() -> void:
	check(VoteLogic.tally({1: 2, 3: 2, 4: 5}) == 2, "tally mayoría")
	check(VoteLogic.tally({1: 2, 3: 5}) == VoteLogic.SKIP, "tally empate = nadie")
	check(VoteLogic.tally({1: -1, 3: -1, 4: 5}) == VoteLogic.SKIP, "tally gana saltar")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cands: Array[int] = [1, 2, 3, 4]
	check(VoteLogic.npc_choose(1, {3: 100.0}, cands, false, {}, rng) == 3, "NPC con sospecha fuerte vota al sospechoso")
	var self_votes := 0
	var counts := {}
	for i in 500:
		var v := VoteLogic.npc_choose(2, {4: 10.0}, cands, false, {}, rng)
		if v == 2:
			self_votes += 1
		counts[v] = int(counts.get(v, 0)) + 1
		if VoteLogic.npc_choose(2, {}, cands, true, {}, rng) == 2:
			self_votes += 1
	check(self_votes == 0, "nadie se vota a sí mismo")
	check(int(counts.get(4, 0)) > int(counts.get(1, 0)), "voto aleatorio ponderado por sospecha")
	check(VoteLogic.npc_choose(2, {}, cands, true, {3: 80.0}, rng) == 3, "impostor se suma a la sospecha pública")


func _test_tasks_and_win() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	GameState.new_game(rng)
	var imp := GameState.impostor_id
	var crew: Array[int] = []
	for i in GameState.PLAYER_COUNT:
		if i != imp:
			crew.append(i)
			GameState.register_tasks(i, 2)
	check(GameState.task_totals() == Vector2i(0, 14), "total de tareas 7x2")
	GameState.complete_task(crew[0])
	GameState.mark_dead(crew[1])
	check(GameState.task_totals() == Vector2i(1, 12), "tareas de muertos se descuentan")
	check(GameState.evaluate_winner() == -1, "partida sigue")
	for id in crew:
		if GameState.alive[id]:
			GameState.complete_task(id)
			GameState.complete_task(id)
	check(GameState.evaluate_winner() == GameState.Role.CREW, "tripulación gana por tareas")
	GameState.new_game(rng)
	for i in GameState.PLAYER_COUNT:
		if i != GameState.impostor_id:
			GameState.register_tasks(i, 1)
	var killed := 0
	for i in GameState.PLAYER_COUNT:
		if i != GameState.impostor_id and killed < 5:
			GameState.mark_dead(i)
			killed += 1
	check(GameState.evaluate_winner() == -1, "2 tripulantes vivos: sigue")
	for i in GameState.PLAYER_COUNT:
		if i != GameState.impostor_id and GameState.alive[i]:
			GameState.mark_dead(i)
			break
	check(GameState.evaluate_winner() == GameState.Role.IMPOSTOR, "1v1: gana impostor")
	GameState.alive[GameState.impostor_id] = false
	check(GameState.evaluate_winner() == GameState.Role.CREW, "impostor expulsado: gana tripulación")


func _test_minigames() -> void:
	var wires: Control = preload("res://ui/WiresTask.gd").new()
	add_child(wires)
	var done := [false]
	wires.connect("completed", func() -> void: done[0] = true)
	var order: Array[int] = wires.get("right_order")
	var wrong := (order.find(0) + 1) % 4
	check(not wires.call("connect_wire", 0, wrong), "cables: conexión incorrecta no cuenta")
	for r in 4:
		wires.call("connect_wire", order[r], r)
	check(done[0], "cables: completar con colores correctos")
	wires.queue_free()

	var code: Control = preload("res://ui/CodeTask.gd").new()
	add_child(code)
	var cdone := [false]
	code.connect("completed", func() -> void: cdone[0] = true)
	code.call("press_digit", "x")
	check(not code.call("submit"), "código: incorrecto rechazado")
	for ch in String(code.get("code")):
		code.call("press_digit", ch)
	check(code.call("submit") and cdone[0], "código: correcto aceptado")
	code.queue_free()

	var cal: Control = preload("res://ui/CalibrateTask.gd").new()
	add_child(cal)
	var kdone := [false]
	cal.connect("completed", func() -> void: kdone[0] = true)
	cal.set_process(false)
	cal.set("value", 0.0)
	cal.set("zone_start", 0.5)
	check(not cal.call("attempt"), "calibrar: fuera de zona falla")
	for i in 3:
		cal.set("value", float(cal.get("zone_start")) + 0.05)
		cal.call("attempt")
	check(kdone[0], "calibrar: 3 aciertos completa")
	cal.queue_free()


func _test_game() -> void:
	var game: Game = preload("res://scenes/Game.tscn").instantiate()
	add_child(game)
	await _frames(10)
	check(game.characters.size() == 8 and game.npcs.size() == 7, "8 personajes spawneados")
	check(game.map.stations.size() == 9 and game.map.vents.size() == 2, "estaciones y ductos")
	await _seconds(game, 3.0)
	_check_on_screen(game.hud, "HUD")
	game.task_host.open(game.map.stations[3])
	await _frames(2)
	_check_on_screen(game.task_host, "minijuego")
	game.task_host.close_task()
	# Navegación: camino desde la cafetería a cada sala.
	var nav_map := game.get_world_2d().navigation_map
	var from := ShipMap.table_position() + Vector2(0, 150)
	for i in ShipMap.room_count():
		var to := ShipMap.room_center(i) + Vector2(0, 90)
		var path := NavigationServer2D.map_get_path(nav_map, from, to, true)
		check(path.size() > 1 and path[path.size() - 1].distance_to(to) < 40.0, "camino navegable a %s" % ShipMap.ROOMS[i].name)
	game.meeting.finished.connect(func(e: int) -> void:
		print("  info reunión: votos=%s expulsado=%d impostor=%d" % [game.meeting.votes, e, GameState.impostor_id]))
	# Simulación de IA.
	game.meeting.discussion_time = 2.0
	game.meeting.voting_time = 4.0
	game.meeting.results_time = 1.0
	var start_pos := game.npcs[0].global_position
	await _seconds(game, 6.0)
	check(game.npcs[0].global_position.distance_to(start_pos) > 50.0, "NPC se mueve con navegación (estado %s)" % game.npcs[0].state_name())
	var t0 := GameState.task_totals().x
	await _seconds(game, 25.0)
	check(GameState.task_totals().x > t0 or GameState.phase != GameState.Phase.PLAYING, "NPCs completan tareas (%d)" % GameState.task_totals().x)
	# Forzar asesinato y reporte.
	if GameState.phase == GameState.Phase.MEETING:
		await _until(game, func() -> bool: return GameState.phase != GameState.Phase.MEETING, 30.0)
	if GameState.phase == GameState.Phase.PLAYING:
		var killer := game.characters[GameState.impostor_id]
		var victim: Character = null
		for c in game.characters:
			if c != killer and c.alive and c != game.player:
				victim = c
				break
		killer.teleport(victim.global_position + Vector2(20, 0))
		game.kill_cooldown = 0.0
		check(game.try_kill(killer, victim), "asesinato ejecutado")
		check(not game.bodies.is_empty() and game.bodies.back().victim_id == victim.char_id and not victim.alive, "cadáver en el piso")
		check(game.kill_cooldown == GameState.KILL_COOLDOWN, "cooldown de kill 25s")
		var reporter: Character = null
		for c in game.characters:
			if c != killer and c.alive:
				reporter = c
		game.report_body(reporter, game.bodies.back())
		check(GameState.phase == GameState.Phase.MEETING, "reporte inicia reunión")
		await _until(game, func() -> bool: return game.meeting.stage == MeetingManager.Stage.VOTING, 10.0)
		check(game.meeting.stage == MeetingManager.Stage.VOTING, "pasa a votación")
		_check_on_screen(game.meeting_ui, "reunión")
		# El jugador (si vive) vota al impostor para asegurar variedad.
		await _until(game, func() -> bool: return GameState.phase != GameState.Phase.MEETING, 25.0)
		check(game.bodies.is_empty(), "cadáveres limpiados tras reunión")
		check(GameState.phase == GameState.Phase.PLAYING or GameState.phase == GameState.Phase.ENDED, "reunión termina (fase %d)" % GameState.phase)
	# Simulación larga hasta el final (el impostor NPC mata; reuniones automáticas).
	if GameState.phase != GameState.Phase.ENDED and not GameState.player_is_impostor():
		await _until(game, func() -> bool: return GameState.phase == GameState.Phase.ENDED, 400.0)
		print("  info fin tras simulación: ganador=%d razón=%s" % [GameState.winner, GameState.end_reason])
	# Forzar expulsión del impostor si sigue la partida.
	if GameState.phase == GameState.Phase.PLAYING:
		game._pending_eject = GameState.impostor_id
		game._on_ejection_done()
	await _frames(5)
	check(GameState.phase == GameState.Phase.ENDED, "la partida termina")
	await _seconds(game, 2.5)
	_check_on_screen(game.end_screen, "pantalla final")
	check(game.end_screen.get_child_count() > 0, "pantalla de victoria/derrota visible")
	game.queue_free()
	await _frames(3)


## Todos los Control visibles deben quedar dentro de la pantalla.
func _check_on_screen(root: Node, label: String) -> void:
	var vp := get_viewport().get_visible_rect().grow(2.0)
	var bad: Array[String] = []
	for c in root.find_children("*", "Control", true, false):
		var ctrl := c as Control
		if ctrl.is_visible_in_tree() and ctrl.size != Vector2.ZERO and not vp.encloses(ctrl.get_global_rect()):
			bad.append("%s %s" % [ctrl.get_class(), ctrl.get_global_rect()])
	check(bad.is_empty(), "%s dentro de pantalla %s" % [label, bad.slice(0, 3)])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(_game: Game, s: float) -> void:
	await _frames(int(s * 60.0))


func _until(_game: Game, cond: Callable, max_s: float) -> void:
	var f := 0
	while not cond.call() and f < int(max_s * 60.0):
		await get_tree().physics_frame
		f += 1
