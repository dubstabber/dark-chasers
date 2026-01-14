class_name FallDamageComponent
extends Node

## Monitors landing velocity and applies fall damage through HealthComponent

signal fall_damage_applied(amount: int)
signal fatal_fall()

@export_group("Damage Thresholds")
@export var safe_speed: float = 8.0
@export var min_damage_speed: float = 12.0
@export var damage_multiplier: float = 4.0
@export var max_damage: int = 1000

@export_group("Node References")
@export var player: CharacterBody3D
@export var health_component: HealthComponent

var was_airborne: bool = false
var died_from_fall: bool = false
var _previous_velocity_y: float = 0.0


func _ready():
	_validate_node_references()


func _validate_node_references() -> void:
	"""Validate that required node references are set and log warnings for missing ones"""
	if not player:
		push_warning("FallDamageComponent: 'player' is not set. Fall damage tracking will be disabled.")
	if not health_component:
		push_warning("FallDamageComponent: 'health_component' is not set. Fall damage application will be disabled.")


func _physics_process(_delta: float):
	if not player:
		return
	
	_update_fall_tracking()


func _update_fall_tracking() -> void:
	var currently_airborne = not player.is_on_floor()
	
	# Check for landing - use previous frame's velocity since current is already resolved
	if was_airborne and player.is_on_floor():
		_check_fall_damage(_previous_velocity_y)
	
	# Store velocity for next frame (before collision resolution)
	_previous_velocity_y = player.velocity.y
	was_airborne = currently_airborne


func _check_fall_damage(fall_velocity: float) -> void:
	if not health_component or health_component.is_dead:
		return
	
	# Convert to positive fall speed
	var fall_speed = abs(fall_velocity)
	
	# No damage below safe threshold
	if fall_speed < safe_speed:
		return
	
	# Calculate damage
	var damage_amount = 0
	if fall_speed >= min_damage_speed:
		damage_amount = int((fall_speed - safe_speed) * damage_multiplier)
		damage_amount = min(damage_amount, max_damage)
	
	if damage_amount > 0:
		# Check if this will be fatal
		if damage_amount >= health_component.current_health:
			died_from_fall = true
			fatal_fall.emit()
		
		health_component.take_damage(damage_amount)
		fall_damage_applied.emit(damage_amount)


func did_die_from_fall() -> bool:
	var result = died_from_fall
	died_from_fall = false
	return result


func reset() -> void:
	was_airborne = false
	died_from_fall = false
	_previous_velocity_y = 0.0
