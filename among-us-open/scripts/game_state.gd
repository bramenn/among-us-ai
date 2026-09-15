extends Node
## Autoload: roles, fase del juego, sospechas, tareas globales y resultado.
## Toda la logica es pura (sin nodos) para poder testearla sin render.

enum Phase { MENU, PLAY, MEETING, GAMEOVER }
enum Role { CREW, IMPOSTOR }
enum WinState { NONE, CREW, IMPOSTOR }

const KILL_COOLDOWN: float = 25.0
const KILL_RANGE: float = 130.0
const REPORT_RANGE: float = 170.0
const INTERACT_RANGE: float = 115.0
const VENT_RANGE: float = 105.0
const CREW_LIGHT: float = 3.0
const IMPOSTOR_LIGHT: float = 4.6
const SUSPICION_THRESHOLD: float = 1.5

signal tasks_updated(done: int, total: int)
signal game_ended(winner: int)

var phase: int = Phase.MENU
var player_infos: Array = []
var suspicion: Dictionary = {}
var total_tasks: int = 0
var done_tasks: int = 0
var winner: int = WinState.NONE
var player_id: int = -1
var emergencies_left: int = 1
var meeting_count: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_input()


func reset() -> void:
	phase = Phase.MENU
	player_infos = []
	suspicion = {}
	total_tasks = 0
	done_tasks = 0
	winner = WinState.NONE
	player_id = -1
	emergencies_left = 1
	meeting_count = 0


func setup_match(ids: Array, human_id: int) -> void:
	reset()
	player_id = human_id
	var pool: Array = ids.duplicate()
	pool.shuffle()
	var impostor_id: int = int(pool[0])
	for pid in ids:
		var pid_int: int = int(pid)
		var role: int = Role.IMPOSTOR if pid_int == impostor_id else Role.CREW
		player_infos.append({"id": pid_int, "role": role, "alive": true})
		suspicion[pid_int] = {}
	phase = Phase.PLAY


func info_by_id(pid: int) -> Dictionary:
	for info in player_infos:
		if int(info["id"]) == pid:
			return info
	return {}


func get_role(pid: int) -> int:
	var info: Dictionary = info_by_id(pid)
	if info.is_empty():
		return Role.CREW
	return int(info["role"])


func is_alive(pid: int) -> bool:
	return bool(info_by_id(pid).get("alive", false))


func is_player(pid: int) -> bool:
	return pid == player_id


func alive_ids() -> Array:
	var out: Array = []
	for info in player_infos:
		if bool(info["alive"]):
			out.append(int(info["id"]))
	return out


func alive_crew() -> int:
	var n: int = 0
	for info in player_infos:
		if bool(info["alive"]) and int(info["role"]) == Role.CREW:
			n += 1
	return n


func alive_impostors() -> int:
	var n: int = 0
	for info in player_infos:
		if bool(info["alive"]) and int(info["role"]) == Role.IMPOSTOR:
			n += 1
	return n


func record_kill(victim_id: int) -> void:
	var info: Dictionary = info_by_id(victim_id)
	if not info.is_empty():
		info["alive"] = false
	check_win()


func eject(pid: int) -> void:
	var info: Dictionary = info_by_id(pid)
	if not info.is_empty():
		info["alive"] = false
	check_win()


func set_tasks_total(n: int) -> void:
	total_tasks = n
	done_tasks = 0
	tasks_updated.emit(done_tasks, total_tasks)


func complete_task() -> void:
	if winner != WinState.NONE:
		return
	done_tasks = mini(done_tasks + 1, total_tasks)
	tasks_updated.emit(done_tasks, total_tasks)
	check_win()


func task_progress() -> float:
	if total_tasks <= 0:
		return 0.0
	return float(done_tasks) / float(total_tasks)


func record_sighting(witness: int, suspect: int, amount: float) -> void:
	if witness == suspect:
		return
	if not suspicion.has(witness):
		suspicion[witness] = {}
	var table: Dictionary = suspicion[witness]
	table[suspect] = float(table.get(suspect, 0.0)) + amount


func get_suspicion(witness: int, suspect: int) -> float:
	if not suspicion.has(witness):
		return 0.0
	return float(suspicion[witness].get(suspect, 0.0))


## Heuristica de voto NPC: sospecha alta -> vota al sospechoso,
## si no hay informacion -> voto aleatorio ponderado o abstencion.
func compute_npc_vote(voter: int, candidates: Array) -> int:
	var others: Array = []
	for cid in candidates:
		if int(cid) != voter and is_alive(int(cid)):
			others.append(int(cid))
	if others.is_empty():
		return -1
	var best_id: int = -1
	var best_val: float = SUSPICION_THRESHOLD
	var tied: Array = []
	for oid in others:
		var val: float = get_suspicion(voter, int(oid))
		if val > best_val:
			best_val = val
			best_id = int(oid)
			tied = [int(oid)]
		elif best_id != -1 and is_equal_approx(val, best_val):
			tied.append(int(oid))
	if best_id != -1:
		if tied.size() > 1:
			return int(tied[_rng.randi_range(0, tied.size() - 1)])
		return best_id
	if _rng.randf() < 0.25:
		return -1
	var total_w: float = 0.0
	for oid in others:
		total_w += 1.0 + get_suspicion(voter, int(oid))
	var pick: float = _rng.randf() * total_w
	for oid in others:
		pick -= 1.0 + get_suspicion(voter, int(oid))
		if pick <= 0.0:
			return int(oid)
	return int(others[others.size() - 1])


func check_win() -> int:
	if winner != WinState.NONE:
		return winner
	if phase == Phase.MENU:
		return WinState.NONE
	if alive_impostors() == 0:
		set_winner(WinState.CREW)
	elif alive_impostors() >= alive_crew():
		set_winner(WinState.IMPOSTOR)
	elif total_tasks > 0 and done_tasks >= total_tasks:
		set_winner(WinState.CREW)
	return winner


func set_winner(w: int) -> void:
	if winner != WinState.NONE:
		return
	winner = w
	phase = Phase.GAMEOVER
	game_ended.emit(winner)


func _ensure_input() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("interact", [KEY_E])
	_add_key_action("report", [KEY_R])
	_add_key_action("kill_action", [KEY_Q])
	_add_key_action("emergency", [KEY_SPACE])
	_add_key_action("pause_game", [KEY_ESCAPE])


func _add_key_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var exists: bool = false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and ev.physical_keycode == int(key):
				exists = true
		if not exists:
			var e := InputEventKey.new()
			e.physical_keycode = int(key) as Key
			InputMap.action_add_event(action, e)
