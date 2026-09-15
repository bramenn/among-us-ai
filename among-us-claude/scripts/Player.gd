class_name Player
extends Character
## Personaje controlado por el humano.

const CREW_VISION := 1.3
const IMPOSTOR_VISION := 2.0
const GHOST_VISION := 2.6


func configure_light() -> void:
	light.texture_scale = IMPOSTOR_VISION if GameState.player_is_impostor() else CREW_VISION
	light.energy = 1.1
	light.shadow_enabled = true
	light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	light.shadow_color = Color(0, 0, 0, 1)


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if game.player_can_act():
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not game.player_can_act() or event.is_echo():
		return
	if event.is_action_pressed("interact"):
		game.player_interact()
	elif event.is_action_pressed("report"):
		game.player_report()
	elif event.is_action_pressed("kill"):
		game.player_kill()
	elif event.is_action_pressed("emergency"):
		game.player_emergency()
	else:
		return
	get_viewport().set_input_as_handled()


func die() -> void:
	alive = false
	sprite.ghost = true
	collision_mask = 0
	light.texture_scale = GHOST_VISION
	light.shadow_enabled = false
