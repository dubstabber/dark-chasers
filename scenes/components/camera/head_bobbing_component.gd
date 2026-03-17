class_name HeadBobbingComponent
extends Node

## Handles head bobbing effect based on player movement state

signal footstep_triggered()

@export_group("Bob Speed")
@export var sprinting_speed: float = 22.0
@export var walking_speed: float = 14.0
@export var crouching_speed: float = 10.0

@export_group("Bob Intensity")
@export var sprinting_intensity: float = 0.2
@export var walking_intensity: float = 0.1
@export var crouching_intensity: float = 0.05

@export_group("Node References")
@export var camera_root: Node3D
@export var eyes: Node3D
@export var player: CharacterBody3D
@export var movement_component: PlayerMovementComponent

@export_group("Settings")
@export var lerp_speed: float = 10.0
@export var stair_step_smoothing_enabled: bool = true
@export var stair_step_up_threshold: float = 0.04
@export var stair_step_max_compensation: float = 0.36
@export var stair_step_recovery_speed: float = 14.0
@export var stair_step_bob_suppression_decay_speed: float = 10.0
@export var stair_step_sprint_bob_suppression_multiplier: float = 1.35

var bob_vector: Vector2 = Vector2.ZERO
var bob_index: float = 0.0
var current_intensity: float = 0.0
var can_step: bool = true
var enabled: bool = true
var _step_vertical_offset: float = 0.0
var _step_bob_suppression: float = 0.0
var _camera_root_base_y: float = 0.0
var _last_player_global_y: float = 0.0
var _has_player_height_sample := false


func _ready():
	_resolve_camera_root()
	_validate_node_references()
	if camera_root:
		_camera_root_base_y = camera_root.position.y
	if player:
		_last_player_global_y = player.global_position.y
		_has_player_height_sample = true


func _resolve_camera_root() -> void:
	if camera_root:
		return
	if eyes and eyes.get_parent() and eyes.get_parent().get_parent():
		camera_root = eyes.get_parent().get_parent() as Node3D


func _validate_node_references() -> void:
	"""Validate that required node references are set and log warnings for missing ones"""
	if not camera_root:
		push_warning("HeadBobbingComponent: 'camera_root' is not set. Stair-step camera smoothing will be limited.")
	if not eyes:
		push_warning("HeadBobbingComponent: 'eyes' is not set. Head bobbing will be disabled.")
	if not player:
		push_warning("HeadBobbingComponent: 'player' is not set. Head bobbing will be disabled.")
	if not movement_component:
		push_warning("HeadBobbingComponent: 'movement_component' is not set. Sprint/crouch bobbing detection will be disabled.")


func _physics_process(delta: float):
	if not enabled or not eyes or not player:
		return
	
	_update_bob_parameters(delta)
	_update_step_smoothing(delta)
	_apply_camera_root_offset()
	_apply_bob(delta)


func _update_bob_parameters(delta: float) -> void:
	# Read state from movement component
	var is_sprinting = movement_component.is_sprinting() if movement_component else false
	var is_crouching = movement_component.is_crouching() if movement_component else false
	var is_moving = player.velocity.length() > 0.1
	
	if is_sprinting and is_moving:
		current_intensity = sprinting_intensity
		bob_index += sprinting_speed * delta
	elif is_crouching and is_moving:
		current_intensity = crouching_intensity
		bob_index += crouching_speed * delta
	elif is_moving:
		current_intensity = walking_intensity
		bob_index += walking_speed * delta
	else:
		current_intensity = 0.0


func _apply_bob(delta: float) -> void:
	var is_grounded = player.is_on_floor()
	var is_sliding = movement_component.is_sliding() if movement_component else false
	var is_moving = player.velocity.length() > 0.1
	var target_y := 0.0
	var target_x := 0.0
	var bob_scale := 1.0 - _step_bob_suppression
	
	if is_grounded and not is_sliding and is_moving:
		bob_vector.y = sin(bob_index)
		bob_vector.x = sin(bob_index / 2)
		
		# Trigger footstep at bob valleys
		if bob_vector.y > -current_intensity:
			can_step = true
		if bob_vector.y < -current_intensity and can_step:
			can_step = false
			footstep_triggered.emit()
		
		target_y += bob_vector.y * (current_intensity / 2.0) * bob_scale
		target_x = bob_vector.x * (current_intensity / 2.0) * bob_scale
	eyes.position.y = lerp(eyes.position.y, target_y, delta * lerp_speed)
	eyes.position.x = lerp(eyes.position.x, target_x, delta * lerp_speed)


func _apply_camera_root_offset() -> void:
	if camera_root:
		camera_root.position.y = _camera_root_base_y + _step_vertical_offset


func _update_step_smoothing(delta: float) -> void:
	if not player:
		return
	var current_player_y := player.global_position.y
	if not _has_player_height_sample:
		_last_player_global_y = current_player_y
		_has_player_height_sample = true
		return
	var vertical_delta := current_player_y - _last_player_global_y
	_last_player_global_y = current_player_y
	if stair_step_smoothing_enabled and player.is_on_floor():
		if vertical_delta > stair_step_up_threshold and vertical_delta <= stair_step_max_compensation:
			_step_vertical_offset -= vertical_delta
			var suppression := inverse_lerp(stair_step_up_threshold, stair_step_max_compensation, vertical_delta)
			if movement_component and movement_component.is_sprinting():
				suppression *= stair_step_sprint_bob_suppression_multiplier
			_step_bob_suppression = maxf(_step_bob_suppression, clampf(suppression, 0.0, 1.0))
	_step_vertical_offset = lerp(_step_vertical_offset, 0.0, delta * stair_step_recovery_speed)
	_step_bob_suppression = lerp(_step_bob_suppression, 0.0, delta * stair_step_bob_suppression_decay_speed)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled and eyes:
		eyes.position.x = 0.0
		eyes.position.y = 0.0
	_step_vertical_offset = 0.0
	_step_bob_suppression = 0.0
	_apply_camera_root_offset()


func reset() -> void:
	bob_vector = Vector2.ZERO
	bob_index = 0.0
	can_step = true
	_step_vertical_offset = 0.0
	_step_bob_suppression = 0.0
	if player:
		_last_player_global_y = player.global_position.y
		_has_player_height_sample = true
	_apply_camera_root_offset()
	if eyes:
		eyes.position.x = 0.0
		eyes.position.y = 0.0
