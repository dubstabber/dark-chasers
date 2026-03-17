class_name EnemyMotorComponent
extends Node

## Handles enemy movement physics.
## Extracts velocity calculation and movement from enemy.gd.

@export var speed: float = 7.0
@export var accel: float = 10.0
@export var is_flying: bool = false
@export_group("Stair Step")
@export var stair_step_enabled := true
@export var stair_step_max_height: float = 0.32
@export var stair_step_min_horizontal_speed: float = 0.1
@export var stair_step_down_probe_distance: float = 0.4
@export var stair_step_debug := false
@export var stair_step_helper: StairStepHelper

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var jump_speed: float = 0.0
var direction: Vector3 = Vector3.ZERO

var _owner_enemy: CharacterBody3D = null


func _ready() -> void:
	_owner_enemy = owner as CharacterBody3D


func apply_gravity(delta: float) -> void:
	if not _owner_enemy:
		return
	
	if not _owner_enemy.is_on_floor() and not is_flying:
		_owner_enemy.velocity.y -= gravity * delta


func move_toward_position(target_pos: Vector3, delta: float) -> void:
	if not _owner_enemy:
		return
	
	var horizontal_direction = Vector3(
		target_pos.x - _owner_enemy.global_position.x,
		0,
		target_pos.z - _owner_enemy.global_position.z
	).normalized()
	
	direction = horizontal_direction
	var target_velocity = horizontal_direction * (speed + jump_speed)
	_owner_enemy.velocity.x = lerp(_owner_enemy.velocity.x, target_velocity.x, accel * delta)
	_owner_enemy.velocity.z = lerp(_owner_enemy.velocity.z, target_velocity.z, accel * delta)


func move_in_direction(move_direction: Vector3, delta: float) -> void:
	if not _owner_enemy:
		return
	
	direction = move_direction.normalized()
	var target_velocity = direction * (speed + jump_speed)
	_owner_enemy.velocity.x = lerp(_owner_enemy.velocity.x, target_velocity.x, accel * delta)
	_owner_enemy.velocity.z = lerp(_owner_enemy.velocity.z, target_velocity.z, accel * delta)


func stop() -> void:
	if not _owner_enemy:
		return
	_owner_enemy.velocity.x = 0.0
	_owner_enemy.velocity.z = 0.0


func apply_jump(velocity_y: float) -> void:
	if not _owner_enemy:
		return
	_owner_enemy.velocity.y = velocity_y


func look_forward() -> void:
	if not _owner_enemy or not _owner_enemy.velocity:
		return
	_owner_enemy.rotation.y = atan2(_owner_enemy.velocity.x, _owner_enemy.velocity.z) + PI


func move_and_slide(delta: float) -> void:
	if not _owner_enemy:
		return
	var up_direction := _owner_enemy.up_direction.normalized()
	var intended_horizontal_velocity := _owner_enemy.velocity.slide(up_direction)
	var stepped_up := false
	if stair_step_enabled and stair_step_helper and not is_flying:
		stepped_up = stair_step_helper.try_step_up(
			_owner_enemy,
			delta,
			stair_step_max_height,
			stair_step_min_horizontal_speed,
			stair_step_down_probe_distance,
			stair_step_debug
		)
	_owner_enemy.move_and_slide()
	if stepped_up:
		_owner_enemy.apply_floor_snap()
		var current_vertical_velocity := _owner_enemy.velocity.dot(up_direction)
		var current_horizontal_velocity := _owner_enemy.velocity.slide(up_direction)
		if intended_horizontal_velocity.length_squared() > 0.0 and current_horizontal_velocity.length_squared() + 0.0001 < intended_horizontal_velocity.length_squared():
			_owner_enemy.velocity = intended_horizontal_velocity + (up_direction * current_vertical_velocity)


func is_on_floor() -> bool:
	if _owner_enemy:
		return _owner_enemy.is_on_floor()
	return false
