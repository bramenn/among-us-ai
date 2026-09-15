class_name Character
extends CharacterBody2D
## Base común de jugador y NPCs: aspecto, nombre, luz, muerte y teletransporte.

const SPEED := 190.0
const CHARACTER_LAYER := 2

var char_id := 0
var char_name := ""
var body_color := Color.WHITE
var alive := true
var game: Game
var sprite: CharacterSprite
var light: PointLight2D
var name_label: Label

static var _light_texture: GradientTexture2D


func setup(id: int, game_ref: Game) -> void:
	char_id = id
	char_name = GameState.NAMES[id]
	body_color = GameState.COLORS[id]
	game = game_ref


func _ready() -> void:
	collision_layer = CHARACTER_LAYER
	collision_mask = ShipMap.WALL_LAYER
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	shape.shape = circle
	shape.position = Vector2(0, 6)
	add_child(shape)
	sprite = CharacterSprite.new()
	sprite.body_color = body_color
	add_child(sprite)
	name_label = Label.new()
	name_label.text = char_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(120, 20)
	name_label.position = Vector2(-60, -48)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(name_label)
	light = PointLight2D.new()
	light.texture = light_texture()
	add_child(light)
	configure_light()


func configure_light() -> void:
	# Luz tenue de traje; Player la sobreescribe con su radio de visión.
	light.texture_scale = 0.2
	light.energy = 0.7


static func light_texture() -> GradientTexture2D:
	if _light_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.7, Color(1, 1, 1, 0.85))
		_light_texture = GradientTexture2D.new()
		_light_texture.gradient = g
		_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_light_texture.fill_from = Vector2(0.5, 0.5)
		_light_texture.fill_to = Vector2(1.0, 0.5)
		_light_texture.width = 512
		_light_texture.height = 512
	return _light_texture


func _process(_delta: float) -> void:
	var moving := velocity.length() > 10.0
	sprite.walk_amount = move_toward(sprite.walk_amount, 1.0 if moving else 0.0, 0.2)
	if absf(velocity.x) > 5.0:
		sprite.facing = signf(velocity.x)


func die() -> void:
	alive = false
	velocity = Vector2.ZERO
	hide()
	set_physics_process(false)
	collision_layer = 0


func teleport(p: Vector2) -> void:
	global_position = p
	velocity = Vector2.ZERO
