extends Node3D

var _failed := false


class TestEnemy extends CharacterBody3D:
	var current_target: Node3D = null
	var current_room: String = ""
	var is_flying := false


class TestTarget extends CharacterBody3D:
	var current_room: String = ""


func _ready() -> void:
	print("=== FUWATTY DASH POLICY TESTS ===")
	await _test_same_room_clear_path_can_commit()
	await _test_blank_room_names_do_not_block_commit()
	await _test_blocker_prevents_commit_when_clear_path_required()
	print("=== FUWATTY DASH POLICY TESTS COMPLETED ===")
	get_tree().quit(1 if _failed else 0)


func _test_same_room_clear_path_can_commit() -> void:
	var harness := Node3D.new()
	add_child(harness)
	var enemy := _spawn_enemy(harness, Vector3.ZERO, "A")
	var target := _spawn_target(harness, Vector3(6.0, 0.0, 0.0), "A")
	enemy.current_target = target
	await get_tree().physics_frame
	var policy: FuwattyDashPolicy = FuwattyDashPolicy.new()
	_assert(policy.can_commit_to_dash(enemy, 0.0, 12.0, true, 0.05, 6.0, [0.45]), "Clear same-room path should be dash-committable")
	harness.free()
	print("✓ same-room clear path commit")


func _test_blank_room_names_do_not_block_commit() -> void:
	var harness := Node3D.new()
	add_child(harness)
	var enemy := _spawn_enemy(harness, Vector3.ZERO, "")
	var target := _spawn_target(harness, Vector3(5.0, 0.0, 0.0), "")
	enemy.current_target = target
	await get_tree().physics_frame
	var policy: FuwattyDashPolicy = FuwattyDashPolicy.new()
	_assert(policy.is_target_in_enemy_room(enemy), "Empty room metadata should not block same-room dash checks")
	harness.free()
	print("✓ blank room names stay permissive")


func _test_blocker_prevents_commit_when_clear_path_required() -> void:
	var harness := Node3D.new()
	add_child(harness)
	var enemy := _spawn_enemy(harness, Vector3.ZERO, "A")
	var target := _spawn_target(harness, Vector3(8.0, 0.0, 0.0), "A")
	_spawn_blocker(harness, Vector3(4.0, 0.0, 0.0), Vector3(1.0, 2.0, 2.0))
	enemy.current_target = target
	await get_tree().physics_frame
	var policy: FuwattyDashPolicy = FuwattyDashPolicy.new()
	_assert(not policy.can_commit_to_dash(enemy, 0.0, 12.0, true, 0.05, 8.0, [0.45]), "Blocking geometry should prevent dash commit when clear path is required")
	harness.free()
	print("✓ blocker prevents clear-path commit")


func _spawn_enemy(parent: Node, position_value: Vector3, room_name: String) -> TestEnemy:
	var enemy := TestEnemy.new()
	parent.add_child(enemy)
	enemy.global_position = position_value
	enemy.current_room = room_name
	enemy.collision_mask = 1
	enemy.collision_layer = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.2
	shape.shape = capsule
	enemy.add_child(shape)
	return enemy


func _spawn_target(parent: Node, position_value: Vector3, room_name: String) -> TestTarget:
	var target := TestTarget.new()
	parent.add_child(target)
	target.global_position = position_value
	target.current_room = room_name
	target.collision_layer = 1
	target.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.0
	shape.shape = capsule
	target.add_child(shape)
	return target


func _spawn_blocker(parent: Node, position_value: Vector3, size: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	parent.add_child(blocker)
	blocker.global_position = position_value
	blocker.collision_layer = 1
	blocker.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	blocker.add_child(shape)
	return blocker


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
