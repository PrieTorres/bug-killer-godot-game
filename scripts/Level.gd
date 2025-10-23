extends Node2D

signal level_finished(success: bool)

@export var duration: float = 30.0
@export var target_kills: int = 10
@export var spawn_interval: float = 0.8
@export var bug_speed_range: Vector2 = Vector2(90, 160)
@export var max_concurrent_bugs: int = 20
@export var initial_delay: float = 0.5
@export var allow_vertical_spawns: bool = false

@onready var _level_timer: Timer = $LevelTimer
@onready var _spawn_timer: Timer = $SpawnTimer
@onready var _time_label: Label = $CanvasLayer/HBoxContainer/TimeLabel
@onready var _score_label: Label = $CanvasLayer/HBoxContainer/ScoreLabel
@onready var _status_label: Label = $CanvasLayer/HBoxContainer/StatusLabel

@onready var _game_viewport: SubViewport = get_viewport() as SubViewport

var _bug_scene: PackedScene = preload("res://scenes/Bug.tscn")
var _rng := RandomNumberGenerator.new()
var _kills: int = 0
var _running: bool = false
var _time_left: float

func _ready() -> void:
    _rng.randomize()
    _setup_viewport()
    _setup_timers()
    start_level()

func _setup_viewport() -> void:
    if not _game_viewport:
        return

    _game_viewport.handle_input_locally = true
    _game_viewport.physics_object_picking = true
    _game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _setup_timers() -> void:
    _level_timer.one_shot = true
    _spawn_timer.one_shot = false

func _reset_ui() -> void:
    _kills = 0
    _time_left = duration
    _update_ui()
    _status_label_hide()

func _update_ui() -> void:
    _time_label.text = "Tempo: %.1f" % _time_left
    _score_label.text = "Kills: %d/%d" % [_kills, target_kills]

func _process(_delta: float) -> void:
    if _running:
        _time_left = max(0.0, _level_timer.time_left)
        _update_ui()

func start_level() -> void:
    _running = true
    _reset_ui()
    _level_timer.wait_time = duration
    _level_timer.start()
    _spawn_timer.wait_time = spawn_interval
    get_tree().create_timer(initial_delay).timeout.connect(func() -> void:
        if _running:
            _spawn_timer.start()
    )

func stop_level() -> void:
    _running = false
    _level_timer.stop()
    _spawn_timer.stop()

func _on_SpawnTimer_timeout() -> void:
    if not _running:
        return
    if get_tree().get_nodes_in_group("bugs").size() >= max_concurrent_bugs:
        return

    var bug: Bug = _bug_scene.instantiate() as Bug
    if bug == null:
        return

    bug.add_to_group("bugs")
    add_child(bug)

    var bounds: Rect2 = _get_play_bounds()
    var start_pos: Vector2
    var end_pos: Vector2
    var edge: int = _rng.randi_range(0, 3 if allow_vertical_spawns else 1)
    var outer := 32.0

    match edge:
        0:
            start_pos = Vector2(bounds.position.x - outer, _rng.randf_range(bounds.position.y, bounds.end.y))
            end_pos = Vector2(bounds.end.x + outer, start_pos.y + _rng.randf_range(-80, 80))
        1:
            start_pos = Vector2(bounds.end.x + outer, _rng.randf_range(bounds.position.y, bounds.end.y))
            end_pos = Vector2(bounds.position.x - outer, start_pos.y + _rng.randf_range(-80, 80))
        2:
            start_pos = Vector2(_rng.randf_range(bounds.position.x, bounds.end.x), bounds.position.y - outer)
            end_pos = Vector2(start_pos.x + _rng.randf_range(-80, 80), bounds.end.y + outer)
        3:
            start_pos = Vector2(_rng.randf_range(bounds.position.x, bounds.end.x), bounds.end.y + outer)
            end_pos = Vector2(start_pos.x + _rng.randf_range(-80, 80), bounds.position.y - outer)

    bug.setup(start_pos, end_pos, bug_speed_range, bounds)
    bug.killed.connect(_on_bug_killed)

func _on_bug_killed() -> void:
    _kills += 1
    _update_ui()
    if _kills >= target_kills:
        _end_level(true)

func _end_level(success: bool) -> void:
    if not _running:
        return

    stop_level()
    _status_label.visible = true
    _status_label.text = "✅ Sucesso!" if success else "❌ Falha!"
    emit_signal("level_finished", success)

    for bug: Node in get_tree().get_nodes_in_group("bugs"):
        if is_instance_valid(bug):
            bug.queue_free()

func _get_play_bounds() -> Rect2:
    if _game_viewport:
        var viewport_size: Vector2 = Vector2(_game_viewport.size)
        var override_size: Vector2i = _game_viewport.size_2d_override
        if override_size != Vector2i.ZERO:
            viewport_size = Vector2(override_size)
        return Rect2(Vector2.ZERO, viewport_size)

    return Rect2(Vector2.ZERO, get_viewport_rect().size)

func _on_LevelTimer_timeout() -> void:
    _end_level(_kills >= target_kills)

func _unhandled_input(event: InputEvent) -> void:
    if not _running:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _try_kill_bug_at_pointer()

func _try_kill_bug_at_pointer() -> void:
    var viewport: Viewport = _game_viewport if _game_viewport else get_viewport()
    if not viewport:
        return

    var mouse_pos: Vector2 = viewport.get_mouse_position()
    var canvas_transform: Transform2D = get_canvas_transform()
    var world_pos: Vector2 = canvas_transform.affine_inverse() * mouse_pos

    var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
    if not space_state:
        return

    var params: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
    params.collide_with_areas = true
    params.collide_with_bodies = false
    params.position = world_pos

    var hits: Array[Dictionary] = space_state.intersect_point(params, 8)
    for hit: Dictionary in hits:
        var collider: Bug = hit.get("collider") as Bug
        if collider and collider.is_in_group("bugs"):
            collider.kill()
            return

func _status_label_hide() -> void:
    _status_label.text = ""
    _status_label.visible = false
