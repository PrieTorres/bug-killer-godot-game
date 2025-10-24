extends Area2D

signal killed(world_pos: Vector2)

# ====== Tamanho e hitbox ======
@export var base_scale: float = 0.35          # deixe menor aqui
@export var scale_jitter: float = 0.10        # variação +-10%
@export var hitbox_scale: float = 1.10        # 1.0 = igual ao sprite; >1 = hitbox um pouco maior (clique mais fácil)

# ====== Orientação da arte ======
@export var sprite_forward_angle: float = +PI / 2.0  # sua arte aponta PRA CIMA → -PI/2
@onready var pewAudio: AudioStreamPlayer2D = $pew

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

	# escala visual com jitter
	var j := randf_range(1.0 - scale_jitter, 1.0 + scale_jitter)
	scale = Vector2.ONE * base_scale * j
	
	# cinto e suspensório:
	self.input_pickable = true

	# certifica que a hitbox existe e está habilitada
	var cs := $CollisionShape2D
	if cs:
		cs.disabled = false

	# === SINCRONIZA A HITBOX COM O TAMANHO REAL ===
	_sync_hitbox_size()

	# opcional: se por algum motivo nascer dentro, impede grudar na borda (acolchoa um pouco)
	var half := _get_visual_half_size()
	var left := _bounds.position.x
	var top := _bounds.position.y
	var right := _bounds.position.x + _bounds.size.x
	var bottom := _bounds.position.y + _bounds.size.y
	var eps := 0.5
	position.x = clamp(position.x, left - half.x + eps, right + half.x - eps)
	position.y = clamp(position.y, top  - half.y + eps, bottom + half.y - eps)

	_life = 0.0

func _physics_process(delta: float) -> void:
	# movimento
	position += _dir * _speed * delta

	# rotação (direção + offset + wiggle)
	_wiggle_time += delta * _wiggle_speed
	var wobble := sin(_wiggle_time) * _wiggle_amplitude
	$Sprite2D.rotation = _dir.angle() + sprite_forward_angle + wobble

	# não sumimos na borda (SubViewport já corta). Limpeza por tempo:
	_life += delta
	if _life >= max_lifetime:
		queue_free()

func _input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		kill()


# ====== Utilitários ======
func _sync_hitbox_size() -> void:
	# Garante que a hitbox (CollisionShape2D) acompanhe o tamanho do sprite + escala
	var cs: CollisionShape2D = $CollisionShape2D
	var spr: Sprite2D = $Sprite2D
	if not cs or not spr or not spr.texture:
		return

	# tamanho do sprite já em pixels
	var tex := spr.texture
	var tex_size: Vector2 = Vector2(tex.get_size())
	var gs: Vector2 = Vector2(abs(global_scale.x), abs(global_scale.y))
	var half_visual: Vector2 = (tex_size * gs) * 0.5

	# Defina a shape preferida: círculo é ótimo pra clique
	if cs.shape is CircleShape2D:
		var r: float = max(half_visual.x, half_visual.y) * hitbox_scale
		(cs.shape as CircleShape2D).radius = r
	elif cs.shape is RectangleShape2D:
		var e: Vector2 = (half_visual * hitbox_scale)
		(cs.shape as RectangleShape2D).extents = e
	# Centralize os nós filhos para evitar offsets
	spr.position = Vector2.ZERO
	cs.position = Vector2.ZERO

func _get_visual_half_size() -> Vector2:
	# tenta derivar pelo CollisionShape2D (já sincronizado)
	var cs: CollisionShape2D = $CollisionShape2D
	if cs and cs.shape:
		if cs.shape is CircleShape2D:
			var r: float = (cs.shape as CircleShape2D).radius
			return Vector2(r, r)
		elif cs.shape is RectangleShape2D:
			return (cs.shape as RectangleShape2D).extents

	# fallback pelo sprite
	var spr: Sprite2D = $Sprite2D
	if spr and spr.texture:
		var tex_size: Vector2 = Vector2(spr.texture.get_size())
		var gs: Vector2 = Vector2(abs(global_scale.x), abs(global_scale.y))
		return (tex_size * gs) * 0.5

	return Vector2(16, 16)
	

func kill() -> void:
        if _dead:
                return
        _dead = true
        self.input_pickable = false
        var cs: CollisionShape2D = $CollisionShape2D
        if cs:
                cs.disabled = true
        emit_signal("killed", global_position)
        queue_free()
