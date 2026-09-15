extends Control
## Reunion y votacion: 20s de discusion, votos NPC con heuristica,
## muestra quien voto a quien y la expulsion.

const MEETING_TIME: float = 20.0

var main_ref: Node = null

var _time_left: float = 0.0
var _votes: Dictionary = {}
var _npc_schedule: Array = []
var _alive: Array = []
var _infos: Dictionary = {}
var _tallied: bool = false
var _end_delay: float = 0.0
var _expelled: int = -1

var _timer_label: Label = null
var _title_label: Label = null
var _result_label: Label = null
var _btn_box: VBoxContainer = null
var _skip_btn: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func start_meeting(reporter_id: int, infos: Array, emergency: bool) -> void:
	for c in get_children():
		c.queue_free()
	_votes = {}
	_npc_schedule = []
	_tallied = false
	_end_delay = 0.0
	_expelled = -1
	_time_left = MEETING_TIME
	_alive = []
	_infos = {}
	for info in infos:
		_alive.append(int(info["id"]))
		_infos[int(info["id"])] = info
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 560)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if emergency:
		_title_label.text = "REUNION DE EMERGENCIA (%s)" % _name_of(reporter_id)
	else:
		_title_label.text = "%s reporto un cadaver" % _name_of(reporter_id)
	vbox.add_child(_title_label)
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 18)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_timer_label)
	var sub := Label.new()
	sub.text = "Discutan y voten al sospechoso."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	_btn_box = VBoxContainer.new()
	_btn_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_btn_box)
	for pid in _alive:
		var b := Button.new()
		b.text = _name_of(pid)
		b.modulate = _color_of(pid)
		if pid == GameState.player_id and GameState.is_alive(pid):
			b.pressed.connect(_on_human_vote.bind(pid))
		else:
			b.disabled = true
		_btn_box.add_child(b)
	_skip_btn = Button.new()
	_skip_btn.text = "Saltar voto"
	_skip_btn.pressed.connect(_on_human_vote.bind(-1))
	vbox.add_child(_skip_btn)
	if not GameState.is_alive(GameState.player_id):
		_skip_btn.disabled = true
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 16)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.custom_minimum_size = Vector2(500, 120)
	vbox.add_child(_result_label)
	for pid in _alive:
		if pid == GameState.player_id:
			continue
		_npc_schedule.append({"voter": pid, "at": randf_range(4.0, MEETING_TIME - 2.0)})
	visible = true


func _name_of(pid: int) -> String:
	if _infos.has(pid):
		return String(_infos[pid]["name"])
	return "?"


func _color_of(pid: int) -> Color:
	if _infos.has(pid):
		return _infos[pid]["color"]
	return Color.WHITE


func _process(delta: float) -> void:
	if not visible:
		return
	if _tallied:
		_end_delay -= delta
		if _end_delay <= 0.0:
			visible = false
			if main_ref != null:
				main_ref.finish_meeting(_expelled, _votes)
		return
	_time_left -= delta
	_timer_label.text = "Tiempo: %ds" % maxi(int(ceil(_time_left)), 0)
	var elapsed: float = MEETING_TIME - _time_left
	var done: Array = []
	for s in _npc_schedule:
		if elapsed >= float(s["at"]):
			_cast_npc_vote(int(s["voter"]))
			done.append(s)
	for s in done:
		_npc_schedule.erase(s)
	if _time_left <= 0.0 or _all_voted():
		_tally()


func _on_human_vote(target: int) -> void:
	if _tallied or _votes.has(GameState.player_id):
		return
	_votes[GameState.player_id] = target
	_skip_btn.disabled = true
	for b in _btn_box.get_children():
		b.disabled = true


func _cast_npc_vote(voter: int) -> void:
	if _votes.has(voter):
		return
	_votes[voter] = GameState.compute_npc_vote(voter, _alive)


func _all_voted() -> bool:
	for pid in _alive:
		if not _votes.has(pid):
			if pid == GameState.player_id and not GameState.is_alive(pid):
				continue
			return false
	return true


func _vote_label(v: int) -> String:
	if v == -1:
		return "salto"
	return _name_of(v)


func _tally() -> void:
	_tallied = true
	for pid in _alive:
		if not _votes.has(pid):
			if pid == GameState.player_id and GameState.is_alive(pid):
				_votes[pid] = -1
			elif pid != GameState.player_id:
				_cast_npc_vote(pid)
	var counts := {}
	for voter in _votes:
		var t: int = int(_votes[voter])
		counts[t] = int(counts.get(t, 0)) + 1
	var lines: Array = []
	for voter in _votes:
		lines.append("%s voto a %s" % [_name_of(int(voter)), _vote_label(int(_votes[voter]))])
	var best: int = -1
	var best_n: int = 0
	var tie: bool = false
	for t in counts:
		if int(t) == -1:
			continue
		if int(counts[t]) > best_n:
			best_n = int(counts[t])
			best = int(t)
			tie = false
		elif int(counts[t]) == best_n:
			tie = true
	if best != -1 and not tie:
		_expelled = best
		lines.append("%s fue expulsado con %d votos." % [_name_of(best), best_n])
	else:
		lines.append("Sin mayoria: nadie fue expulsado.")
	_result_label.text = "\n".join(lines)
	for b in _btn_box.get_children():
		b.disabled = true
	_skip_btn.disabled = true
	_end_delay = 4.0
