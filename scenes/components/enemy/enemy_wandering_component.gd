class_name EnemyWanderingComponent
extends Node

signal direction_changed(new_direction: Vector3)
signal started_wandering()
signal stopped_wandering()

@export var enabled := true
@export var min_direction_change_time := 0.2
@export var max_direction_change_time := 2.8
@export var interaction_ray_path: NodePath

var direction := Vector3.ZERO
var _interaction_ray: RayCast3D
var _timer: Timer
var _is_wandering := false
var _debug_prints := false


func _ready() -> void:
	if interaction_ray_path:
		_interaction_ray = get_node_or_null(interaction_ray_path)
	_setup_timer()


func _setup_timer() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func start_wandering() -> void:
	if not enabled or _is_wandering:
		return
	_is_wandering = true
	_change_direction()
	_timer.start()
	started_wandering.emit()


func stop_wandering() -> void:
	if not _is_wandering:
		return
	_is_wandering = false
	_timer.stop()
	direction = Vector3.ZERO
	stopped_wandering.emit()


func is_wandering() -> bool:
	return _is_wandering


func update(_delta: float) -> void:
	if not enabled or not _is_wandering:
		return
	
	if _timer.is_stopped():
		_timer.start()
	
	if _check_wall_collision():
		_turn_around()


func _check_wall_collision() -> bool:
	if not _interaction_ray:
		return false
	
	if _interaction_ray.is_colliding():
		var collider = _interaction_ray.get_collider()
		if collider != null and not collider.is_in_group("player"):
			return true
	return false


func _turn_around() -> void:
	direction = - direction.normalized()
	direction_changed.emit(direction)
	if _debug_prints:
		Services.utils.debug_log("Wandering: turned around, new direction: %s" % direction)


func _change_direction() -> void:
	direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	direction_changed.emit(direction)


func _on_timer_timeout() -> void:
	_timer.wait_time = randf_range(min_direction_change_time, max_direction_change_time)
	_change_direction()
	_timer.start()


func set_debug(value: bool) -> void:
	_debug_prints = value
