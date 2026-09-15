class_name MeetingUI
extends CanvasLayer
## Interfaz de reunión: candidatos, chat, votos y pantalla de expulsión.

signal ejection_done

var manager: MeetingManager
var _root: Control
var _header: Label
var _timer: Label
var _chat: RichTextLabel
var _rows := {}        # id -> {button, voters: HBoxContainer, stamp: Label}
var _skip: Button
var _skip_voters: HBoxContainer
var _eject_root: Control
var _eject_label: Label
var _eject_bean: Control


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.hide()
	_eject_root = Control.new()
	_eject_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_eject_root)
	_eject_root.hide()


func open(m: MeetingManager, caller_text: String) -> void:
	manager = m
	for c in _root.get_children():
		c.queue_free()
	_rows.clear()
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var tablet := Panel.new()
	tablet.set_anchors_preset(Control.PRESET_FULL_RECT)
	tablet.offset_left = 30
	tablet.offset_top = 20
	tablet.offset_right = -30
	tablet.offset_bottom = -20
	tablet.add_theme_stylebox_override("panel", UIKit.box(Color(0.72, 0.78, 0.86), Color(0.25, 0.3, 0.4), 24))
	_root.add_child(tablet)
	_header = _label(tablet, Vector2(30, 16), 30, Color(0.1, 0.1, 0.2))
	_header.text = "¿QUIÉN ES EL IMPOSTOR?"
	var sub := _label(tablet, Vector2(30, 56), 18, Color(0.25, 0.25, 0.35))
	sub.text = caller_text
	_timer = _label(tablet, Vector2(640, 20), 26, Color(0.6, 0.1, 0.1))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(30, 100)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	tablet.add_child(grid)
	for id in GameState.PLAYER_COUNT:
		grid.add_child(_make_row(id))
	_skip = Button.new()
	_skip.text = "SALTAR VOTO"
	_skip.position = Vector2(30, 510)
	_skip.size = Vector2(200, 48)
	_skip.add_theme_font_size_override("font_size", 20)
	_skip.pressed.connect(_vote.bind(VoteLogic.SKIP))
	tablet.add_child(_skip)
	_skip_voters = HBoxContainer.new()
	_skip_voters.position = Vector2(245, 522)
	tablet.add_child(_skip_voters)

	_chat = RichTextLabel.new()
	_chat.bbcode_enabled = true
	_chat.scroll_following = true
	_chat.position = Vector2(820, 100)
	_chat.size = Vector2(370, 460)
	_chat.add_theme_font_size_override("normal_font_size", 16)
	_chat.add_theme_color_override("default_color", Color(0.1, 0.1, 0.15))
	tablet.add_child(_chat)
	var chat_bg := UIKit.box(Color(1, 1, 1, 0.5), Color(0.3, 0.3, 0.4), 10)
	_chat.add_theme_stylebox_override("normal", chat_bg)

	m.stage_changed.connect(_on_stage)
	m.vote_cast.connect(_on_vote)
	m.chat.connect(_on_chat)
	_on_stage(m.stage, m.time_left)
	_root.show()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.3)


func close() -> void:
	if manager and manager.stage_changed.is_connected(_on_stage):
		manager.stage_changed.disconnect(_on_stage)
		manager.vote_cast.disconnect(_on_vote)
		manager.chat.disconnect(_on_chat)
	_root.hide()


func _make_row(id: int) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(380, 92)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UIKit.box(Color(0.92, 0.94, 0.97), Color(0.4, 0.45, 0.55), 10))
	b.add_theme_stylebox_override("hover", UIKit.box(Color(1, 1, 0.85), Color(0.9, 0.7, 0.1), 10))
	b.add_theme_stylebox_override("disabled", UIKit.box(Color(0.6, 0.62, 0.66), Color(0.4, 0.4, 0.45), 10))
	b.pressed.connect(_vote.bind(id))
	var portrait := Control.new()
	portrait.position = Vector2(10, 10)
	portrait.size = Vector2(60, 60)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := GameState.COLORS[id]
	var dead := not GameState.alive[id]
	portrait.draw.connect(func() -> void:
		CharacterSprite.draw_bean(portrait, col.darkened(0.5) if dead else col, Vector2(32, 36), 1.2))
	b.add_child(portrait)
	var n := _label(b, Vector2(84, 8), 22, Color(0.1, 0.1, 0.15))
	n.text = GameState.NAMES[id] + ("  (muerto)" if dead else "")
	var stamp := _label(b, Vector2(290, 8), 16, Color(0.1, 0.5, 0.2))
	var voters := HBoxContainer.new()
	voters.position = Vector2(84, 50)
	voters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(voters)
	b.disabled = dead
	_rows[id] = {"button": b, "voters": voters, "stamp": stamp}
	return b


func _label(parent: Control, pos: Vector2, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _process(_delta: float) -> void:
	if manager and _root.visible and _timer:
		var names := {MeetingManager.Stage.DISCUSSION: "Discusión", MeetingManager.Stage.VOTING: "Votación", MeetingManager.Stage.RESULTS: "Resultados"}
		_timer.text = "%s: %ds" % [names.get(manager.stage, ""), ceili(maxf(manager.time_left, 0.0))]


func _can_player_vote() -> bool:
	return manager.stage == MeetingManager.Stage.VOTING and GameState.alive[GameState.PLAYER_ID] \
		and not manager.votes.has(GameState.PLAYER_ID)


func _vote(target: int) -> void:
	if _can_player_vote():
		manager.cast_vote(GameState.PLAYER_ID, target)


func _on_stage(stage: int, _duration: float) -> void:
	if stage == MeetingManager.Stage.DISCUSSION:
		_header.text = "¿QUIÉN ES EL IMPOSTOR?  — discutan"
	elif stage == MeetingManager.Stage.VOTING:
		_header.text = "¡VOTEN!" if GameState.alive[GameState.PLAYER_ID] else "Votación (eres fantasma)"
		_on_chat(-1, "— Comienza la votación —")
	elif stage == MeetingManager.Stage.RESULTS:
		_header.text = "RESULTADOS"
		_reveal_votes()
	_update_buttons()


func _update_buttons() -> void:
	var can := _can_player_vote()
	for id: int in _rows:
		(_rows[id].button as Button).disabled = not can or not GameState.alive[id]
	_skip.disabled = not can


func _on_vote(voter: int, _target: int) -> void:
	(_rows[voter].stamp as Label).text = "VOTÓ"
	_update_buttons()


func _on_chat(speaker: int, text: String) -> void:
	if speaker < 0:
		_chat.append_text("[i]%s[/i]\n" % text)
		return
	_chat.append_text("[color=#%s][b]%s:[/b][/color] %s\n" % [GameState.COLORS[speaker].darkened(0.3).to_html(false), GameState.NAMES[speaker], text])


func _reveal_votes() -> void:
	for voter: int in manager.votes:
		var target: int = manager.votes[voter]
		var dot := ColorRect.new()
		dot.color = GameState.COLORS[voter]
		dot.custom_minimum_size = Vector2(22, 22)
		var box: HBoxContainer = _skip_voters if target == VoteLogic.SKIP else _rows[target].voters
		box.add_child(dot)
		dot.scale = Vector2.ZERO
		create_tween().tween_property(dot, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		var tname := "saltar" if target == VoteLogic.SKIP else GameState.NAMES[target]
		_on_chat(-1, "%s votó → %s" % [GameState.NAMES[voter], tname])


## Pantalla de expulsión animada; emite ejection_done al terminar.
func show_ejection(ejected: int) -> void:
	close()
	for c in _eject_root.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_eject_root.add_child(bg)
	var stars := Control.new()
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.draw.connect(func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 150:
			stars.draw_circle(Vector2(rng.randf() * 1400.0, rng.randf() * 800.0), rng.randf_range(0.8, 2.2), Color(1, 1, 1, rng.randf())))
	_eject_root.add_child(stars)
	var text := "Nadie fue expulsado."
	if ejected >= 0:
		_eject_bean = Control.new()
		_eject_bean.position = Vector2(-100, 300)
		var col := GameState.COLORS[ejected]
		_eject_bean.draw.connect(func() -> void: CharacterSprite.draw_bean(_eject_bean, col, Vector2.ZERO, 2.5))
		_eject_root.add_child(_eject_bean)
		var tw := create_tween()
		tw.tween_property(_eject_bean, "position", Vector2(1400, 340), 4.0)
		tw.parallel().tween_property(_eject_bean, "rotation", TAU * 2.0, 4.0)
		text = "%s %s el impostor." % [GameState.NAMES[ejected], "era" if GameState.is_impostor(ejected) else "no era"]
	_eject_label = Label.new()
	UIKit.place(_eject_label, Control.PRESET_CENTER, Vector2(-500, -30), Vector2(1000, 60))
	_eject_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eject_label.add_theme_font_size_override("font_size", 40)
	_eject_label.text = text
	_eject_label.visible_ratio = 0.0
	_eject_root.add_child(_eject_label)
	_eject_root.show()
	var t2 := create_tween()
	t2.tween_property(_eject_label, "visible_ratio", 1.0, 1.6)
	t2.tween_interval(2.6)
	t2.tween_callback(func() -> void:
		_eject_root.hide()
		ejection_done.emit())
