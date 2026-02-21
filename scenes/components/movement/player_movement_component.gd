class_name PlayerMovementComponent
extends Node

## Handles all player movement: walking, sprinting, crouching, sliding, jumping, climbing, clip mode

signal movement_state_changed(state: MovementState)
signal speed_changed(current_speed: float)
signal grounded_changed(is_grounded: bool)
signal slide_started()
signal slide_ended()

enum MovementState {IDLE, WALKING, SPRINTING, CROUCHING, SLIDING, CLIMBING, AIRBORNE}

@export_group("Speed Settings")
@export var walking_speed: float = 5.0
@export var sprinting_speed: float = 8.0
@export var crouching_speed: float = 3.0
@export var jump_velocity: float = 6.0

@export_group("Lerp Settings")
@export var lerp_speed: float = 10.0
@export var air_lerp_speed: float = 3.0

@export_group("Slide Settings")
@export var slide_speed: float = 10.0
@export var slide_duration: float = 1.0

@export_group("Crouch Settings")
@export var crouching_depth: float = -0.5

@export_group("Sprint Requirements")
@export var min_health_to_sprint: int = 30

@export_group("Node References")
@export var player: CharacterBody3D
@export var head: Node3D
@export var standing_collision: CollisionShape3D
@export var crouching_collision: CollisionShape3D
@export var crouch_raycast: RayCast3D
@export var health_component: HealthComponent

var current_speed: float = 5.0
var direction: Vector3 = Vector3.ZERO
var current_state: MovementState = MovementState.IDLE
var previous_state: MovementState = MovementState.IDLE

var slide_timer: float = 0.0
var slide_vector: Vector2 = Vector2.ZERO

var is_climbing: bool = false
var clip_mode: bool = false

# Track sprinting state (persists across frames like old code)
var _is_sprinting: bool = false

# Track sprinting state for FOV (persists through jumps)
var _was_sprinting_before_airborne: bool = false

var _initial_collision_mask: int
var _was_grounded: bool = true


func _ready():
	_validate_node_references()
	if player:
		_initial_collision_mask = player.collision_mask


func _validate_node_references() -> void:
	"""Validate that required node references are set and log warnings for missing ones"""
	if not player:
		push_warning("PlayerMovementComponent: 'player' is not set. Movement will be disabled.")
	if not head:
		push_warning("PlayerMovementComponent: 'head' is not set. Head bobbing during crouch will be disabled.")
	if not standing_collision:
		push_warning("PlayerMovementComponent: 'standing_collision' is not set. Collision switching will be disabled.")
	if not crouching_collision:
		push_warning("PlayerMovementComponent: 'crouching_collision' is not set. Collision switching will be disabled.")
	if not crouch_raycast:
		push_warning("PlayerMovementComponent: 'crouch_raycast' is not set. Standing up detection will be disabled.")
	if not health_component:
		push_warning("PlayerMovementComponent: 'health_component' is not set. Sprint health check will be disabled.")


func _physics_process(_delta: float):
	if not player:
		return
	
	# Gravity and move_and_slide() are owned by Player._physics_process
	
	# Track grounded state changes
	var currently_grounded = player.is_on_floor()
	if currently_grounded != _was_grounded:
		grounded_changed.emit(currently_grounded)
		_was_grounded = currently_grounded


func process_movement(delta: float, input_dir: Vector2, is_crouching_input: bool = false, is_sprinting_input: bool = false) -> void:
	"""Process movement with input state passed from PlayerInputComponent
	
	Args:
		delta: Frame delta time
		input_dir: Movement direction from input
		is_crouching_input: Whether crouch is being held
		is_sprinting_input: Whether sprint is being held
	"""
	if not player:
		return
	
	_update_crouch_state(delta, input_dir, is_crouching_input, is_sprinting_input)
	_update_slide(delta)
	_update_direction(delta, input_dir)
	_apply_movement()
	_update_climbing(input_dir)
	_update_movement_state()


func _update_crouch_state(delta: float, input_dir: Vector2, is_crouching_input: bool, is_sprinting_input: bool) -> void:
	var currently_sliding = current_state == MovementState.SLIDING
	
	if (is_crouching_input or currently_sliding) and not clip_mode:
		current_speed = lerp(current_speed, crouching_speed, delta * lerp_speed)
		
		if head:
			head.position.y = lerp(head.position.y, crouching_depth, delta * lerp_speed)
		
		if standing_collision:
			standing_collision.disabled = true
		if crouching_collision:
			crouching_collision.disabled = false
		
		# Start sliding if was sprinting and pressing crouch with movement
		# Check _is_sprinting BEFORE resetting it (matches old player.gd behavior)
		if _is_sprinting and input_dir != Vector2.ZERO and not currently_sliding:
			_start_slide(input_dir)
		
		# Reset sprint flag after slide check (like old code line 278)
		_is_sprinting = false
		
		# Only set CROUCHING if we didn't just start sliding
		# Must check current_state, not currently_sliding (which is stale)
		if current_state != MovementState.SLIDING:
			_set_state(MovementState.CROUCHING)
	
	elif not crouch_raycast or not crouch_raycast.is_colliding():
		if standing_collision:
			standing_collision.disabled = false
		if crouching_collision:
			crouching_collision.disabled = true
		
		if head:
			head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		
		if is_sprinting_input and player.velocity.length() > 0.1 and _can_sprint():
			current_speed = lerp(current_speed, sprinting_speed, delta * lerp_speed)
			_set_state(MovementState.SPRINTING)
			_is_sprinting = true
			_was_sprinting_before_airborne = true
		else:
			current_speed = lerp(current_speed, walking_speed, delta * lerp_speed)
			_is_sprinting = false
			_was_sprinting_before_airborne = false
			if input_dir != Vector2.ZERO:
				_set_state(MovementState.WALKING)
			else:
				_set_state(MovementState.IDLE)


func _update_slide(delta: float) -> void:
	if current_state == MovementState.SLIDING:
		slide_timer -= delta
		if slide_timer <= 0:
			_end_slide()


func _start_slide(input_dir: Vector2) -> void:
	slide_timer = slide_duration
	slide_vector = input_dir
	_set_state(MovementState.SLIDING)
	slide_started.emit()


func _end_slide() -> void:
	slide_timer = 0.0
	_set_state(MovementState.CROUCHING)
	slide_ended.emit()


func _update_direction(delta: float, input_dir: Vector2) -> void:
	if not player:
		return
	
	if clip_mode:
		if input_dir != Vector2.ZERO:
			direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		else:
			direction = Vector3.ZERO
			player.velocity.x = 0
			player.velocity.z = 0
	elif current_state == MovementState.SLIDING:
		direction = (player.transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
		current_speed = (slide_timer + 0.1) * slide_speed
	elif player.is_on_floor():
		direction = lerp(direction, (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * air_lerp_speed)


func _apply_movement() -> void:
	if not player:
		return
	
	if direction:
		player.velocity.x = direction.x * current_speed
		player.velocity.z = direction.z * current_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, current_speed)
	
	# Handle climbing
	if is_climbing and direction != Vector3.ZERO:
		player.velocity.y = current_speed


func _update_climbing(input_dir: Vector2) -> void:
	if is_climbing and input_dir != Vector2.ZERO:
		player.velocity.y = current_speed


func _update_movement_state() -> void:
	if not player.is_on_floor() and current_state != MovementState.CLIMBING:
		_set_state(MovementState.AIRBORNE)


func _set_state(new_state: MovementState) -> void:
	if new_state != current_state:
		previous_state = current_state
		current_state = new_state
		movement_state_changed.emit(current_state)
		speed_changed.emit(current_speed)


func _can_sprint() -> bool:
	if health_component:
		return health_component.current_health >= min_health_to_sprint
	return true


func handle_jump() -> bool:
	if not player:
		return false
	
	if clip_mode:
		player.velocity.y = current_speed
		return true
	elif player.is_on_floor():
		player.velocity.y = jump_velocity
		if current_state == MovementState.SLIDING:
			_end_slide()
		return true
	return false


func handle_jump_release() -> void:
	if clip_mode:
		player.velocity.y = move_toward(player.velocity.y, 0, current_speed)


func handle_crouch_press() -> void:
	if clip_mode:
		player.velocity.y = - current_speed


func handle_crouch_release() -> void:
	if clip_mode:
		player.velocity.y = 0


func toggle_clip_mode() -> bool:
	clip_mode = not clip_mode
	
	if clip_mode:
		# Disable collision with Walls (layer 3) and Weapon Passthrough Walls (layer 5)
		player.set_collision_mask_value(3, false)
		player.set_collision_mask_value(5, false)
		player.velocity = Vector3.ZERO
	else:
		player.collision_mask = _initial_collision_mask
	
	return clip_mode


func set_climbing(value: bool) -> void:
	is_climbing = value
	if value:
		_set_state(MovementState.CLIMBING)


func get_movement_state() -> MovementState:
	return current_state


func is_moving() -> bool:
	return player.velocity.length() > 0.1


func is_sprinting() -> bool:
	# Return true if sprinting OR if we were sprinting before becoming airborne
	# This keeps FOV consistent during jumps while sprinting
	return current_state == MovementState.SPRINTING or (current_state == MovementState.AIRBORNE and _was_sprinting_before_airborne)


func is_crouching() -> bool:
	return current_state == MovementState.CROUCHING


func is_sliding() -> bool:
	return current_state == MovementState.SLIDING


func is_grounded() -> bool:
	return player.is_on_floor() if player else false


func get_current_speed() -> float:
	return current_speed


func get_direction() -> Vector3:
	return direction


func set_direction(new_direction: Vector3) -> void:
	direction = new_direction
