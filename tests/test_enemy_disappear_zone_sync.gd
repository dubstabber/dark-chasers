extends Node

## Tests for disappear zone dedupe + sync between Enemy (export bridge) and EnemyDisappearZoneComponent.

const EnemyScene := preload("res://scenes/enemies/enemy.tscn")

var _failed := false

func _ready() -> void:
	print("=".repeat(60))
	print("ENEMY DISAPPEAR ZONE SYNC TESTS")
	print("=".repeat(60))

	_test_enemy_add_disappear_zone_dedupes_and_connects_once()
	_test_component_sync_sanitizes_duplicates()
	_test_component_sync_repairs_mismatch_and_disconnects_removed()
	await _test_component_detects_overlap_via_kill_zone_area()
	await _test_component_detects_brief_overlap_for_small_body()

	# Give one frame for output to flush in headless runs.
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_enemy_add_disappear_zone_dedupes_and_connects_once() -> void:
	print("\n--- add_disappear_zone dedupe + single connect ---")
	var enemy := EnemyScene.instantiate() as Enemy
	var comp := enemy.get_node("EnemyDisappearZoneComponent") as EnemyDisappearZoneComponent
	enemy._disappear_zone_component = comp

	var zone = Area3D.new()
	enemy.add_disappear_zone(zone)
	enemy.add_disappear_zone(zone) # duplicate

	_assert(enemy.disappear_zones.size() == 1, "Enemy export list should dedupe")
	_assert(comp.disappear_zones.size() == 1, "Component list should dedupe")

	var cb := Callable(comp, "_on_disappear_area")
	_assert(zone.body_entered.is_connected(cb), "Zone should be connected to component callback")
	_assert(_count_connections(zone, &"body_entered", cb) == 1, "Should only have 1 connection")
	print("✓ dedupe + single connect")

	zone.free()
	enemy.free()


func _test_component_sync_sanitizes_duplicates() -> void:
	print("\n--- component sync sanitizes duplicates (edge) ---")
	var enemy := EnemyScene.instantiate() as Enemy
	var comp := enemy.get_node("EnemyDisappearZoneComponent") as EnemyDisappearZoneComponent
	var a := Area3D.new()
	var b := Area3D.new()
	var desired: Array[Area3D] = [a, a, b]

	var was_in_sync: bool = comp.sync_with_enemy_zones(desired)
	_assert(was_in_sync == false, "Should repair duplicates in desired list")
	_assert(comp.disappear_zones.size() == 2, "Duplicates should be removed")
	_assert(comp.disappear_zones.has(a) and comp.disappear_zones.has(b), "Should contain desired unique zones")

	var cb := Callable(comp, "_on_disappear_area")
	_assert(_count_connections(a, &"body_entered", cb) == 1, "Zone A should only have 1 connection")
	_assert(_count_connections(b, &"body_entered", cb) == 1, "Zone B should only have 1 connection")
	print("✓ duplicate sanitization")

	a.free()
	b.free()
	enemy.free()


func _test_component_sync_repairs_mismatch_and_disconnects_removed() -> void:
	print("\n--- component sync repairs mismatch ---")
	var enemy := EnemyScene.instantiate() as Enemy
	var comp := enemy.get_node("EnemyDisappearZoneComponent") as EnemyDisappearZoneComponent
	var a = Area3D.new()
	var b = Area3D.new()
	var removed = Area3D.new()

	# Start with a zone that should be removed.
	comp.add_zone(removed)
	var cb := Callable(comp, "_on_disappear_area")
	_assert(removed.body_entered.is_connected(cb), "Precondition: removed zone connected")

	var desired: Array[Area3D] = [a, b]
	var was_in_sync: bool = comp.sync_with_enemy_zones(desired)
	_assert(was_in_sync == false, "Should report out-of-sync and repair")
	_assert(comp.disappear_zones.size() == 2, "After repair should match desired unique set")
	_assert(comp.disappear_zones.has(a) and comp.disappear_zones.has(b), "After repair should contain desired zones")
	_assert(not removed.body_entered.is_connected(cb), "Removed zone should be disconnected")
	_assert(a.body_entered.is_connected(cb) and b.body_entered.is_connected(cb), "Desired zones should be connected")
	print("✓ sync repair + disconnect removed")

	a.free()
	b.free()
	removed.free()
	enemy.free()


func _test_component_detects_overlap_via_kill_zone_area() -> void:
	print("\n--- component detects overlap via kill zone area ---")
	var enemy := CharacterBody3D.new()
	enemy.collision_layer = 2
	enemy.collision_mask = 55

	var kill_zone := Area3D.new()
	kill_zone.name = "KillZone"
	var kill_zone_shape := CollisionShape3D.new()
	var kill_zone_capsule := CapsuleShape3D.new()
	kill_zone_capsule.radius = 0.694512
	kill_zone_capsule.height = 1.0
	kill_zone_shape.position = Vector3(0.0, 0.984, 0.0)
	kill_zone_shape.shape = kill_zone_capsule
	kill_zone.add_child(kill_zone_shape)
	enemy.add_child(kill_zone)

	var comp := EnemyDisappearZoneComponent.new()
	comp.name = "EnemyDisappearZoneComponent"
	enemy.add_child(comp)
	var state := {"disappeared": false}
	enemy.tree_exited.connect(func() -> void:
		state["disappeared"] = true
	)

	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(0.28, 2.0, 0.28)
	zone_shape.shape = zone_box
	zone.add_child(zone_shape)

	add_child(enemy)
	add_child(zone)
	enemy.global_position = Vector3(0.36, 0.0, 0.0)
	zone.global_position = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().physics_frame

	comp.add_zone(zone)
	await get_tree().process_frame
	await get_tree().physics_frame
	if is_instance_valid(comp):
		comp.update(0.02)
	await get_tree().process_frame

	_assert(state["disappeared"] or (is_instance_valid(enemy) and enemy.is_queued_for_deletion()), "Component should detect disappear overlap via KillZone area proxy")
	print("✓ kill zone area overlap detection")

	zone.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
	await get_tree().process_frame


func _test_component_detects_brief_overlap_for_small_body() -> void:
	print("\n--- component detects brief overlap for small body ---")
	var enemy := CharacterBody3D.new()
	enemy.collision_layer = 2
	enemy.collision_mask = 55
	var enemy_shape := CollisionShape3D.new()
	var enemy_capsule := CapsuleShape3D.new()
	enemy_capsule.radius = 0.2
	enemy_capsule.height = 1.0
	enemy_shape.position = Vector3(0.0, 0.505, 0.0)
	enemy_shape.shape = enemy_capsule
	enemy.add_child(enemy_shape)

	var comp := EnemyDisappearZoneComponent.new()
	comp.name = "EnemyDisappearZoneComponent"
	enemy.add_child(comp)
	var state := {"disappeared": false}
	enemy.tree_exited.connect(func() -> void:
		state["disappeared"] = true
	)

	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(0.28, 2.0, 0.28)
	zone_shape.shape = zone_box
	zone.add_child(zone_shape)

	add_child(enemy)
	add_child(zone)
	enemy.global_position = Vector3(2.0, 0.0, 0.0)
	zone.global_position = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().physics_frame

	comp.add_zone(zone)
	comp.update(0.02)
	enemy.global_position = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().physics_frame
	if is_instance_valid(comp):
		comp.update(0.02)
	await get_tree().process_frame

	_assert(state["disappeared"] or (is_instance_valid(enemy) and enemy.is_queued_for_deletion()), "Component should detect a brief thin-zone overlap for a 0.2m-radius body")
	print("✓ brief overlap detection")

	zone.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
	await get_tree().process_frame


func _count_connections(obj: Object, signal_name: StringName, cb: Callable) -> int:
	var list: Array = obj.get_signal_connection_list(signal_name)
	var count := 0
	for d in list:
		if d is Dictionary and d.get("callable") == cb:
			count += 1
	return count


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
