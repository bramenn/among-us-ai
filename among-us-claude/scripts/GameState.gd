extends Node
## Autoload: roles, fase del juego, progreso de tareas y resultado.

signal phase_changed(phase: int)
signal tasks_changed(done: int, total: int)

enum Phase { MENU, PLAYING, MEETING, ENDED }
enum Role { CREW, IMPOSTOR }

const PLAYER_COUNT := 8
const PLAYER_ID := 0
const NAMES: Array[String] = ["Tú", "Rojo", "Azul", "Verde", "Rosa", "Naranja", "Amarillo", "Cian"]
const COLORS: Array[Color] = [
	Color(0.95, 0.95, 0.95), Color(0.85, 0.12, 0.15), Color(0.15, 0.3, 0.9), Color(0.1, 0.6, 0.2),
	Color(0.95, 0.4, 0.75), Color(0.95, 0.5, 0.1), Color(0.95, 0.9, 0.2), Color(0.2, 0.9, 0.85),
]
const KILL_COOLDOWN := 25.0

var phase: int = Phase.MENU
var roles: Array[int] = []
var alive: Array[bool] = []
var impostor_id := -1
var winner := -1          # Role que ganó, -1 si sigue la partida
var end_reason := ""
# tareas por personaje: id -> [asignadas, completadas]
var task_counts := {}


func _ready() -> void:
	_setup_input()


func new_game(rng: RandomNumberGenerator) -> void:
	roles.clear()
	alive.clear()
	task_counts.clear()
	impostor_id = rng.randi_range(0, PLAYER_COUNT - 1)
	for i in PLAYER_COUNT:
		roles.append(Role.IMPOSTOR if i == impostor_id else Role.CREW)
		alive.append(true)
	winner = -1
	end_reason = ""
	set_phase(Phase.PLAYING)


func set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


func is_impostor(id: int) -> bool:
	return id == impostor_id


func player_is_impostor() -> bool:
	return is_impostor(PLAYER_ID)


func register_tasks(id: int, count: int) -> void:
	task_counts[id] = [count, 0]
	_emit_tasks()


func complete_task(id: int) -> void:
	var c: Array = task_counts[id]
	c[1] = mini(int(c[1]) + 1, int(c[0]))
	_emit_tasks()


func mark_dead(id: int) -> void:
	alive[id] = false
	_emit_tasks()


## Total = tareas de tripulantes vivos + las ya hechas por los muertos.
func task_totals() -> Vector2i:
	var done := 0
	var total := 0
	for id: int in task_counts:
		var c: Array = task_counts[id]
		done += int(c[1])
		total += int(c[0]) if alive[id] else int(c[1])
	return Vector2i(done, total)


func task_progress() -> float:
	var t := task_totals()
	return 1.0 if t.y == 0 else float(t.x) / float(t.y)


func _emit_tasks() -> void:
	var t := task_totals()
	tasks_changed.emit(t.x, t.y)


## Devuelve el rol ganador o -1. No cambia estado.
func evaluate_winner() -> int:
	if not alive[impostor_id]:
		return Role.CREW
	var crew_alive := 0
	for i in PLAYER_COUNT:
		if alive[i] and i != impostor_id:
			crew_alive += 1
	if crew_alive <= 1:
		return Role.IMPOSTOR
	var t := task_totals()
	if t.y > 0 and t.x >= t.y:
		return Role.CREW
	return -1


func finish(role: int, reason: String) -> void:
	winner = role
	end_reason = reason
	set_phase(Phase.ENDED)


func player_won() -> bool:
	return winner == roles[PLAYER_ID]


func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E], "report": [KEY_R], "kill": [KEY_Q],
		"emergency": [KEY_SPACE], "pause": [KEY_ESCAPE],
	}
	for action: String in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
