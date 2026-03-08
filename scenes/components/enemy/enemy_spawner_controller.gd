class_name EnemySpawnerController
extends Node

## Reusable controller for timed enemy spawning from spawn points.
## Extracts spawning logic from room scripts into a reusable component.

signal enemy_spawned(enemy: Node, spawner_index: int)
signal all_spawners_active()

@export var enemy_scene: PackedScene
@export var min_respawn_time: float = 10.0
@export var max_respawn_time: float = 30.0
@export var delay_between_spawners: float = 1.0
@export var auto_start: bool = true
@export var is_wandering: bool = true
@export var max_active_enemies: int = 0
@export var spawn_owner_id: StringName = &""

var _spawners_container: Node = null
var _enemies_container: Node = null
var _current_spawner_index: int = 0
var _spawner_timers: Array[Timer] = []
var _delay_timer: Timer = null


func _ready() -> void:
	_setup_delay_timer()


func _setup_delay_timer() -> void:
	_delay_timer = Timer.new()
	_delay_timer.one_shot = true
	_delay_timer.wait_time = delay_between_spawners
	_delay_timer.timeout.connect(_on_delay_timer_timeout)
	add_child(_delay_timer)


func initialize(spawners: Node, enemies: Node) -> void:
	_spawners_container = spawners
	_enemies_container = enemies
	
	if auto_start and _spawners_container and _spawners_container.get_child_count() > 0:
		spawn_enemy_at_index(0)


func spawn_enemy_at_index(index: int) -> Node:
	if not _spawners_container or not _enemies_container:
		return null
	
	var spawners = _spawners_container.get_children()
	if index >= spawners.size():
		return null
	
	var spawner = spawners[index]
	_setup_respawn_timer(index, spawner)
	var enemy = _spawn_from_spawner(spawner)
	
	if enemy:
		enemy_spawned.emit(enemy, index)
	
	_current_spawner_index += 1
	
	if _current_spawner_index < spawners.size():
		_delay_timer.start()
	else:
		all_spawners_active.emit()
	
	return enemy


func _setup_respawn_timer(index: int, spawner: Node) -> void:
	if index < _spawner_timers.size() and _spawner_timers[index] != null:
		return
	var respawn_timer = Timer.new()
	spawner.add_child(respawn_timer)
	respawn_timer.timeout.connect(_on_respawn_timer_timeout.bind(index, respawn_timer))
	respawn_timer.wait_time = randf_range(min_respawn_time, max_respawn_time)
	respawn_timer.one_shot = true
	respawn_timer.start()
	
	while _spawner_timers.size() <= index:
		_spawner_timers.append(null)
	_spawner_timers[index] = respawn_timer


func _on_respawn_timer_timeout(index: int, timer: Timer) -> void:
	if not _spawners_container or not _enemies_container:
		return
	
	var spawners = _spawners_container.get_children()
	if index >= spawners.size():
		return
	
	var enemy = _spawn_from_spawner(spawners[index])
	
	timer.wait_time = randf_range(min_respawn_time, max_respawn_time)
	timer.start()
	
	if enemy:
		enemy_spawned.emit(enemy, index)


func _on_delay_timer_timeout() -> void:
	if not _spawners_container:
		return
	
	if _current_spawner_index < _spawners_container.get_child_count():
		spawn_enemy_at_index(_current_spawner_index)


func get_spawner_count() -> int:
	if _spawners_container:
		return _spawners_container.get_child_count()
	return 0


func get_active_spawner_count() -> int:
	return _current_spawner_index


func _spawn_from_spawner(spawner: Node) -> Node:
	if enemy_scene == null or _enemies_container == null:
		return null

	var setup_enemy := func(spawned_enemy: Node) -> void:
		if is_wandering and spawned_enemy is Enemy:
			spawned_enemy.is_wandering = true

	if Services.enemy_spawn_owner:
		var spawn_position := (spawner as Node3D).position if spawner is Node3D else Vector3.ZERO
		return Services.enemy_spawn_owner.spawn_enemy(
			enemy_scene,
			_enemies_container,
			spawn_position,
			"",
			null,
			_get_spawn_owner_id(),
			max_active_enemies,
			true,
			setup_enemy
		)

	var enemy = enemy_scene.instantiate()
	_enemies_container.add_child(enemy)
	if enemy is Node3D and spawner is Node3D:
		(enemy as Node3D).position = (spawner as Node3D).position
	setup_enemy.call(enemy)
	return enemy


func _get_spawn_owner_id() -> StringName:
	if spawn_owner_id != &"":
		return spawn_owner_id
	return StringName("spawner:%s" % String(get_path()))
