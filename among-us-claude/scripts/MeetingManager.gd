class_name MeetingManager
extends Node
## Flujo de reunión: discusión -> votación -> resultados. Sin UI.

signal stage_changed(stage: int, duration: float)
signal vote_cast(voter: int, target: int)
signal chat(speaker: int, text: String)
signal finished(ejected: int)

enum Stage { IDLE, DISCUSSION, VOTING, RESULTS }

var discussion_time := 20.0
var voting_time := 15.0
var results_time := 6.0

var stage: int = Stage.IDLE
var time_left := 0.0
var votes := {}            # voter -> target (VoteLogic.SKIP = saltar)
var alive_ids: Array[int] = []
var result := VoteLogic.SKIP

var _npcs: Array[NPC] = []
var _rng: RandomNumberGenerator
var _pending: Array = []   # [tiempo_restante, Callable]


func start(npcs: Array[NPC], ids: Array[int], reporter: int, victim: int, room: String, rng: RandomNumberGenerator) -> void:
	_npcs = npcs
	alive_ids = ids
	_rng = rng
	votes.clear()
	_pending.clear()
	result = VoteLogic.SKIP
	_set_stage(Stage.DISCUSSION, discussion_time)
	_schedule_chat(reporter, victim, room)


func _process(delta: float) -> void:
	if stage == Stage.IDLE:
		return
	time_left -= delta
	for p: Array in _pending.duplicate():
		p[0] = float(p[0]) - delta
		if float(p[0]) <= 0.0:
			_pending.erase(p)
			(p[1] as Callable).call()
	if stage == Stage.VOTING and votes.size() >= alive_ids.size():
		time_left = minf(time_left, 0.0)
	if time_left > 0.0:
		return
	match stage:
		Stage.DISCUSSION:
			_set_stage(Stage.VOTING, voting_time)
			_schedule_npc_votes()
		Stage.VOTING:
			for id in alive_ids:
				if not votes.has(id):
					votes[id] = VoteLogic.SKIP
			result = VoteLogic.tally(votes)
			_pending.clear()
			_set_stage(Stage.RESULTS, results_time)
		Stage.RESULTS:
			_set_stage(Stage.IDLE, 0.0)
			finished.emit(result)


func cast_vote(voter: int, target: int) -> bool:
	if stage != Stage.VOTING or votes.has(voter) or not alive_ids.has(voter):
		return false
	votes[voter] = target
	vote_cast.emit(voter, target)
	return true


## Sospecha "pública": suma de lo que sospechan los tripulantes (para el impostor).
func public_suspicion() -> Dictionary:
	var d := {}
	for n in _npcs:
		if n.is_impostor():
			continue
		for id: int in n.suspicion:
			d[id] = float(d.get(id, 0.0)) + float(n.suspicion[id])
	return d


func npc_vote(n: NPC) -> int:
	return VoteLogic.npc_choose(n.char_id, n.suspicion, alive_ids, n.is_impostor(), public_suspicion(), _rng)


func _set_stage(s: int, duration: float) -> void:
	stage = s
	time_left = duration
	stage_changed.emit(s, duration)


func _schedule_npc_votes() -> void:
	for n in _npcs:
		if alive_ids.has(n.char_id):
			var voter := n
			_pending.append([_rng.randf_range(1.5, voting_time - 2.0), func() -> void: cast_vote(voter.char_id, npc_vote(voter))])


func _schedule_chat(reporter: int, victim: int, room: String) -> void:
	var t := 1.0
	if reporter >= 0 and victim >= 0 and reporter != GameState.PLAYER_ID:
		_pending.append([t, chat.emit.bind(reporter, "Encontré el cuerpo de %s en %s." % [GameState.NAMES[victim], room])])
		t += 2.0
	for n in _npcs:
		if not alive_ids.has(n.char_id):
			continue
		var line := _line_for(n)
		_pending.append([t + _rng.randf_range(0.0, 1.5), chat.emit.bind(n.char_id, line)])
		t += _rng.randf_range(1.2, 2.2)


func _line_for(n: NPC) -> String:
	var others: Array[int] = []
	for id in alive_ids:
		if id != n.char_id:
			others.append(id)
	if n.is_impostor():
		if _rng.randf() < 0.5 and not others.is_empty():
			return "Vi a %s actuando raro cerca de un ducto..." % GameState.NAMES[others[_rng.randi_range(0, others.size() - 1)]]
		return "Yo estaba haciendo mis tareas, no vi nada."
	var top := VoteLogic.argmax(n.suspicion, others)
	if top != VoteLogic.SKIP and float(n.suspicion[top]) >= VoteLogic.CONFIDENT_THRESHOLD:
		return "¡Fue %s! Lo vi cerca del cuerpo." % GameState.NAMES[top]
	if top != VoteLogic.SKIP and float(n.suspicion[top]) > 5.0:
		return "%s estaba cerca... no estoy seguro." % GameState.NAMES[top]
	return ["No vi nada.", "Estaba en mis tareas.", "Sin pruebas, mejor saltar.", "¿Dónde estaba cada uno?"][_rng.randi_range(0, 3)]
