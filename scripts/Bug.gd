extends Area2D

signal killed

# ====== Tamanho e hitbox ======
@export var base_scale: float = 0.35
@export var scale_jitter: float = 0.10
@export var hitbox_scale: float = 1.10

# ====== Orientação da arte ======
@export var sprite_forward_angle: float = +PI / 2.0

# ====== Movimento e vida ======
var _speed: float = 120.0
var _dir: Vector2 = Vector2.RIGHT
var _bounds: Rect2
@export var max_lifetime: float = 14.0
var _life: float = 0.0
var _dead := false

# ====== Efeito de "passinhos" ======
var _wiggle_speed: float = 8.0
var _wiggle_amplitude: float = deg_to_rad(5.0)
var _wiggle_time: float = 0.0

func setup(start_pos: Vector2, end_pos: Vector2, speed_range: Vector2, bounds: Rect2) -> void:
	position = start_pos
	_dir = (end_pos - start_pos).normalized()
	_speed = randf_range(speed_range.x, speed_range.y)
	_bounds = bounds

	var jitter := randf_range(1.0 - scale_jitter, 1.0 + scale_jitter)
	scale = Vector2.ONE * base_scale * jitter

	input_pickable = true

	var collision_shape := $CollisionShape2D
	if collision_shape:
		collision_shape.disabled = false

	_sync_hitbox_size()

	var half_size := _get_visual_half_size()
	var left := _bounds.position.x
	var top := _bounds.position.y
	var right := _bounds.position.x + _bounds.size.x
	var bottom := _bounds.position.y + _bounds.size.y
	var epsilon := 0.5
	position.x = clamp(position.x, left - half_size.x + epsilon, right + half_size.x - epsilon)
	position.y = clamp(position.y, top - half_size.y + epsilon, bottom + half_size.y - epsilon)

	_life = 0.0

func _physics_process(delta: float) -> void:
	position += _dir * _speed * delta

	_wiggle_time += delta * _wiggle_speed
	var wobble := sin(_wiggle_time) * _wiggle_amplitude
	$Sprite2D.rotation = _dir.angle() + sprite_forward_angle + wobble

	_life += delta
	if _life >= max_lifetime:
		queue_free()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		kill()

func _sync_hitbox_size() -> void:
	var collision_shape: CollisionShape2D = $CollisionShape2D
	var sprite: Sprite2D = $Sprite2D
	if not collision_shape or not sprite or not sprite.texture:
		return

	var texture := sprite.texture
	var texture_size := Vector2(texture.get_size())
	var global_scale := Vector2(abs(self.global_scale.x), abs(self.global_scale.y))
	var half_visual := (texture_size * global_scale) * 0.5

	if collision_shape.shape is CircleShape2D:
		var radius := max(half_visual.x, half_visual.y) * hitbox_scale
		(collision_shape.shape as CircleShape2D).radius = radius
	elif collision_shape.shape is RectangleShape2D:
		var extents := half_visual * hitbox_scale
		(collision_shape.shape as RectangleShape2D).extents = extents

	sprite.position = Vector2.ZERO
	collision_shape.position = Vector2.ZERO

func _get_visual_half_size() -> Vector2:
	var collision_shape: CollisionShape2D = $CollisionShape2D
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CircleShape2D:
			var radius := (collision_shape.shape as CircleShape2D).radius
			return Vector2(radius, radius)
		elif collision_shape.shape is RectangleShape2D:
			return (collision_shape.shape as RectangleShape2D).extents

	var sprite: Sprite2D = $Sprite2D
	if sprite and sprite.texture:
		var texture_size := Vector2(sprite.texture.get_size())
		var global_scale := Vector2(abs(self.global_scale.x), abs(self.global_scale.y))
		return (texture_size * global_scale) * 0.5

	return Vector2(16, 16)

func kill() -> void:
	if _dead:
		return
	_dead = true
	emit_signal("killed")
	queue_free()
