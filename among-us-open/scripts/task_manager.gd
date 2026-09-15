extends Node
## Reparte tareas entre tripulantes y lleva el progreso global.

var entries: Array = []


func _ready() -> void:
	add_to_group("task_manager")


func setup(crew_ids: Array, human_id: int) -> void:
	entries = []
	var stations: Array = get_tree().get_nodes_in_group("task_stations")
	stations.sort_custom(func(a: Node, b: Node) -> bool: return a.station_id < b.station_id)
	for cid in crew_ids:
		var cid_int: int = int(cid)
		if cid_int == human_id:
			_assign_player_tasks(cid_int, stations)
		else:
			var picks: Array = stations.duplicate()
			picks.shuffle()
			for k in mini(2, picks.size()):
				entries.append({"pid": cid_int, "station_id": picks[k].station_id, "done": false})
	GameState.set_tasks_total(entries.size())


func _assign_player_tasks(human_id: int, stations: Array) -> void:
	var by_type := {"WIRES": [], "CODE": [], "CALIBRATE": []}
	for st in stations:
		by_type[st.task_type].append(st)
	for ttype in ["WIRES", "CODE", "CALIBRATE"]:
		var pool: Array = by_type[ttype]
		if not pool.is_empty():
			var st: Node = pool[randi() % pool.size()]
			entries.append({"pid": human_id, "station_id": st.station_id, "done": false})


func pending_for(pid: int) -> Array:
	var out: Array = []
	for e in entries:
		if int(e["pid"]) == pid and not bool(e["done"]):
			out.append(e)
	return out


func pending_task_names(pid: int) -> Array:
	var names: Array = []
	for e in pending_for(pid):
		var st: Node = station_for_id(int(e["station_id"]))
		if st != null:
			names.append(st.task_name)
	return names


func is_station_pending_for(pid: int, station_id: int) -> bool:
	for e in pending_for(pid):
		if int(e["station_id"]) == station_id:
			return true
	return false


func get_next_station_for(npc_id: int) -> Node:
	var mine: Array = pending_for(npc_id)
	if mine.is_empty():
		return null
	return station_for_id(int(mine[0]["station_id"]))


func complete_npc_task(npc_id: int, station: Node) -> void:
	for e in entries:
		if int(e["pid"]) == npc_id and int(e["station_id"]) == station.station_id and not bool(e["done"]):
			e["done"] = true
			GameState.complete_task()
			_refresh_station_glow(station.station_id)
			return


func complete_player_task(station_id: int) -> void:
	for e in entries:
		if int(e["pid"]) == GameState.player_id and int(e["station_id"]) == station_id and not bool(e["done"]):
			e["done"] = true
			GameState.complete_task()
			_refresh_station_glow(station_id)
			return


func fake_task_flash(_station: Node) -> void:
	var main_ref: Node = get_tree().get_first_node_in_group("main")
	if main_ref != null:
		main_ref.hud.flash_message("Fingiendo tarea...")


func station_for_id(station_id: int) -> Node:
	for st in get_tree().get_nodes_in_group("task_stations"):
		if st.station_id == station_id:
			return st
	return null


func _refresh_station_glow(station_id: int) -> void:
	var st: Node = station_for_id(station_id)
	if st == null:
		return
	for e in entries:
		if int(e["station_id"]) == station_id and not bool(e["done"]):
			return
	st.set_done_glow(true)
