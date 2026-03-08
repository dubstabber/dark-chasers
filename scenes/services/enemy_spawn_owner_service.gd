class_name EnemySpawnOwnerService
extends Node

signal enemy_spawned(owner_id: StringName, enemy: Node)
signal spawn_blocked(owner_id: StringName, max_active: int, active_count: int)

var _owner_states: Dictionary = {}


func spawn_enemy(
	scene: PackedScene,
	parent: Node,
	spawn_position: Vector3 = Vector3.ZERO,
	spawn_room: String = "",
	target_player: Node = null,
	owner_id: StringName = &"",
	max_active: int = 0,
	apply_spawn_position: bool = true,
	spawn_setup: Callable = Callable()
) -> Node:
	if scene == null or parent == null:
		return null

	var resolved_owner_id := _normalize_owner_id(owner_id)
	var owner_state := _get_or_create_owner_state(resolved_owner_id)
	owner_state["attempted"] = int(owner_state.get("attempted", 0)) + 1
	owner_state["max_active"] = max_active

	if max_active > 0 and int(owner_state.get("active", 0)) >= max_active:
		owner_state["blocked"] = int(owner_state.get("blocked", 0)) + 1
		spawn_blocked.emit(resolved_owner_id, max_active, int(owner_state.get("active", 0)))
		return null

	var enemy := scene.instantiate()
	parent.add_child(enemy)

	if apply_spawn_position and enemy is Node3D:
		(enemy as Node3D).position = spawn_position
	if not spawn_room.is_empty() and "current_room" in enemy:
		enemy.current_room = spawn_room
	if target_player != null and "current_target" in enemy:
		enemy.current_target = target_player
	if spawn_setup.is_valid():
		spawn_setup.call(enemy)

	owner_state["spawned"] = int(owner_state.get("spawned", 0)) + 1
	_track_owned_enemy(resolved_owner_id, enemy)
	enemy_spawned.emit(resolved_owner_id, enemy)
	return enemy


func get_owner_active_count(owner_id: StringName) -> int:
	var resolved_owner_id := _normalize_owner_id(owner_id)
	var owner_state := _get_or_create_owner_state(resolved_owner_id)
	return int(owner_state.get("active", 0))


func get_owner_stats(owner_id: StringName) -> Dictionary:
	var resolved_owner_id := _normalize_owner_id(owner_id)
	var owner_state := _get_or_create_owner_state(resolved_owner_id)
	return {
		"owner_id": resolved_owner_id,
		"attempted": int(owner_state.get("attempted", 0)),
		"spawned": int(owner_state.get("spawned", 0)),
		"blocked": int(owner_state.get("blocked", 0)),
		"active": int(owner_state.get("active", 0)),
		"max_active": int(owner_state.get("max_active", 0)),
	}


func get_global_stats() -> Dictionary:
	var attempted := 0
	var spawned := 0
	var blocked := 0
	var active := 0
	for owner_state in _owner_states.values():
		attempted += int(owner_state.get("attempted", 0))
		spawned += int(owner_state.get("spawned", 0))
		blocked += int(owner_state.get("blocked", 0))
		active += int(owner_state.get("active", 0))
	return {
		"owner_count": _owner_states.size(),
		"attempted": attempted,
		"spawned": spawned,
		"blocked": blocked,
		"active": active,
	}


func _track_owned_enemy(owner_id: StringName, enemy: Node) -> void:
	var owner_state := _get_or_create_owner_state(owner_id)
	var tracked_ids: Dictionary = owner_state.get("tracked_ids", {})
	var enemy_id := enemy.get_instance_id()
	if tracked_ids.has(enemy_id):
		return
	tracked_ids[enemy_id] = true
	owner_state["tracked_ids"] = tracked_ids
	owner_state["active"] = int(owner_state.get("active", 0)) + 1
	enemy.tree_exited.connect(_on_owned_enemy_exited.bind(owner_id, enemy_id), CONNECT_ONE_SHOT)


func _on_owned_enemy_exited(owner_id: StringName, enemy_id: int) -> void:
	var owner_state = _owner_states.get(owner_id)
	if typeof(owner_state) != TYPE_DICTIONARY:
		return
	var tracked_ids: Dictionary = owner_state.get("tracked_ids", {})
	if not tracked_ids.has(enemy_id):
		return
	tracked_ids.erase(enemy_id)
	owner_state["tracked_ids"] = tracked_ids
	owner_state["active"] = max(0, int(owner_state.get("active", 0)) - 1)


func _normalize_owner_id(owner_id: StringName) -> StringName:
	if owner_id == &"":
		return &"anonymous"
	return owner_id


func _get_or_create_owner_state(owner_id: StringName) -> Dictionary:
	if not _owner_states.has(owner_id):
		_owner_states[owner_id] = {
			"attempted": 0,
			"spawned": 0,
			"blocked": 0,
			"active": 0,
			"max_active": 0,
			"tracked_ids": {},
		}
	return _owner_states[owner_id]