extends Node

const EnemyScene := preload("res://scenes/enemies/enemy.tscn")

var _failed := false


class MockTarget extends CharacterBody3D:
	var current_room: String = ""
	var _dead := false

	func is_dead() -> bool:
		return _dead

	func is_alive() -> bool:
		return not _dead


func _ready() -> void:
	print("=".repeat(60))
	print("ENEMY STAIR-STEP HARDENING TESTS")
	print("=".repeat(60))

	await _test_doom_mode_climbs_grounded_stairs_with_stair_step_helper()
	await _test_doom_mode_does_not_climb_grounded_tall_wall()

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_doom_mode_climbs_grounded_stairs_with_stair_step_helper() -> void:
	print("\n--- doom mode climbs grounded stairs with stair-step helper ---")
	await _assert_doom_grounded_stair_behavior(true)
	print("✓ Doom stair-step grounded climb")


func _test_doom_mode_does_not_climb_grounded_tall_wall() -> void:
	print("\n--- doom mode does not climb grounded tall wall ---")
	await _assert_doom_grounded_stair_behavior(false)
	print("✓ Doom tall-wall guardrail")


func _assert_doom_grounded_stair_behavior(expect_climb: bool) -> void:
	var environment := _create_doom_stair_hardening_environment(expect_climb)
	add_child(environment["root"])

	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = Enemy.NavigationMode.DOOM
	enemy.current_room = "RoomA"
	enemy.position = environment["spawn_position"]
	add_child(enemy)
	var collision_shape := enemy.get_node("CollisionShape3D") as CollisionShape3D
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	if collision_shape:
		collision_shape.shape = shape

	var target := MockTarget.new()
	target.current_room = "RoomA"
	target.position = environment["target_position"]
	add_child(target)

	await _wait_physics_frames(5)

	enemy.current_target = target
	enemy.makepath()

	var start_position := enemy.global_position
	var max_height := start_position.y
	var max_forward_progress := 0.0
	for _i in 150:
		await get_tree().physics_frame
		max_height = maxf(max_height, enemy.global_position.y)
		max_forward_progress = maxf(max_forward_progress, start_position.z - enemy.global_position.z)

	if expect_climb:
		_assert(max_forward_progress > 4.5, "Grounded Doom stair chase should keep advancing through the stair corridor")
		_assert(max_height > start_position.y + 0.55, "Grounded Doom stair chase should gain height while climbing stairs")
		_assert(enemy.global_position.distance_to(target.global_position) < 1.4, "Grounded Doom stair chase should reach the elevated target area")
	else:
		_assert(max_height < start_position.y + 0.25, "Grounded Doom chase should not climb a tall wall as if it were stairs")
		_assert(enemy.global_position.distance_to(target.global_position) > 3.5, "Grounded Doom chase should not reach an elevated target through a tall blocking wall")

	target.free()
	enemy.free()
	environment["root"].free()
	await get_tree().process_frame


func _create_doom_stair_hardening_environment(use_stairs: bool) -> Dictionary:
	var root := Node3D.new()
	root.name = "DoomStairHardeningEnvironmentStairs" if use_stairs else "DoomStairHardeningEnvironmentWall"
	root.add_child(_create_static_box_body("BaseFloor", Vector3(0.0, -0.5, -1.5), Vector3(5.0, 1.0, 14.0)))
	root.add_child(_create_static_box_body("CorridorLeft", Vector3(-1.75, 0.75, -1.5), Vector3(0.5, 1.5, 14.0)))
	root.add_child(_create_static_box_body("CorridorRight", Vector3(1.75, 0.75, -1.5), Vector3(0.5, 1.5, 14.0)))
	var spawn_position := Vector3(0.0, 0.15, 3.2)
	var target_position := Vector3(0.0, 0.05, -5.2)
	if use_stairs:
		root.add_child(_create_static_box_body("Step1", Vector3(0.0, 0.125, 0.2), Vector3(2.9, 0.25, 0.8)))
		root.add_child(_create_static_box_body("Step2", Vector3(0.0, 0.375, -0.6), Vector3(2.9, 0.25, 0.8)))
		root.add_child(_create_static_box_body("Step3", Vector3(0.0, 0.625, -1.4), Vector3(2.9, 0.25, 0.8)))
		root.add_child(_create_static_box_body("TopPlatform", Vector3(0.0, 0.875, -2.7), Vector3(2.9, 0.5, 2.2)))
		target_position = Vector3(0.0, 1.05, -2.75)
	else:
		root.add_child(_create_static_box_body("TallWall", Vector3(0.0, 0.85, 0.1), Vector3(3.1, 1.7, 0.45)))
	return {
		"root": root,
		"spawn_position": spawn_position,
		"target_position": target_position,
	}


func _create_static_box_body(body_name: String, position: Vector3, size: Vector3, rotation_degrees := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	body.rotation_degrees = rotation_degrees

	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)
	return body


func _wait_physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
