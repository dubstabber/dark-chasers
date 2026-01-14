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
@export var eyes: Node3D
@export var player: CharacterBody3D
@export var movement_component: PlayerMovementComponent

@export_group("Settings")
@export var lerp_speed: float = 10.0

var bob_vector: Vector2 = Vector2.ZERO
var bob_index: float = 0.0
var current_intensity: float = 0.0
var can_step: bool = true
var enabled: bool = true


func _ready():
	_validate_node_references()


func _validate_node_references() -> void:
	"""Validate that required node references are set and log warnings for missing ones"""
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
	
	if is_grounded and not is_sliding and is_moving:
		bob_vector.y = sin(bob_index)
		bob_vector.x = sin(bob_index / 2)
		
		# Trigger footstep at bob valleys
		if bob_vector.y > -current_intensity:
			can_step = true
		if bob_vector.y < -current_intensity and can_step:
			can_step = false
			footstep_triggered.emit()
		
		eyes.position.y = lerp(eyes.position.y, bob_vector.y * (current_intensity / 2.0), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, bob_vector.x * (current_intensity / 2.0), delta * lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled and eyes:
		eyes.position.x = 0.0
		eyes.position.y = 0.0


func reset() -> void:
	bob_vector = Vector2.ZERO
	bob_index = 0.0
	can_step = true
	if eyes:
		eyes.position.x = 0.0
		eyes.position.y = 0.0
