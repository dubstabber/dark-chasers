class_name PlayerInputComponent
extends Node

## Handles all player input: mouse look, movement keys, jump, crouch, use, respawn

signal respawn_requested()
signal use_pressed()
signal clip_mode_toggled(enabled: bool)
signal debug_camera_toggled()

@export_group("Node References")
@export var player: Player
@export var camera: Node3D # PlayerCamera
@export var movement_component: PlayerMovementComponent
@export var interaction_component: InteractionComponent
@export var animation_player: AnimationPlayer


func _ready():
	_validate_node_references()


func _validate_node_references() -> void:
	"""Validate that required node references are set and log warnings for missing ones"""
	if not player:
		push_warning("PlayerInputComponent: 'player' is not set. Input handling will be disabled.")
	if not camera:
		push_warning("PlayerInputComponent: 'camera' is not set. Mouse look will be disabled.")
	if not movement_component:
		push_warning("PlayerInputComponent: 'movement_component' is not set. Movement input will be disabled.")
	if not interaction_component:
		push_warning("PlayerInputComponent: 'interaction_component' is not set. Use input will be disabled.")
	if not animation_player:
		push_warning("PlayerInputComponent: 'animation_player' is not set. Jump/landing animations will be disabled.")


func _input(event: InputEvent) -> void:
	if not player:
		return

	if event.is_action_pressed("respawn"):
		respawn_requested.emit()
		return
	
	if _is_movement_blocked():
		return
	
	if not _is_player_dead():
		if event is InputEventMouseMotion and camera:
			camera.handle_mouse_look(event.relative)
	
	if event.is_action_pressed("switch-debug-camera"):
		_toggle_debug_camera()


## Called by Player._physics_process each frame.
## Gravity, move_and_slide(), and last_velocity are now owned by Player.
func process_physics_input(delta: float) -> void:
	if not player or not movement_component:
		return
	
	if _is_movement_blocked():
		_stop_all_movement()
		return
	
	if not _is_player_dead():
		_process_movement_input(delta)
		_process_action_input()


func _process_movement_input(delta: float) -> void:
	var input_dir = Input.get_vector("move-left", "move-right", "move-up", "move-down")
	var is_crouching = Input.is_action_pressed("crouch")
	var is_sprinting = Input.is_action_pressed("sprint")
	movement_component.process_movement(delta, input_dir, is_crouching, is_sprinting)

	# Use PlayerCameraInterface for sprint FOV
	PlayerCameraInterface.set_sprint_fov(camera, movement_component.is_sprinting())
	
	if Input.is_action_just_pressed("jump"):
		if movement_component.handle_jump():
			if not movement_component.clip_mode and animation_player:
				animation_player.play("jump")
	elif Input.is_action_just_released("jump"):
		movement_component.handle_jump_release()
	
	if Input.is_action_just_pressed("crouch"):
		movement_component.handle_crouch_press()
	elif Input.is_action_just_released("crouch"):
		movement_component.handle_crouch_release()
	
	if player.is_on_floor() and _get_last_velocity_y() < -4.0:
		if animation_player:
			animation_player.play("landing")


func _process_action_input() -> void:
	if Input.is_action_just_pressed("toggle-clip-mode"):
		var new_clip_mode = movement_component.toggle_clip_mode()
		clip_mode_toggled.emit(new_clip_mode)
		Services.event_bus.emit(GameEventTypes.PLAYER_MODE_CHANGED, {
			"mode": "clip_mode",
			"value": new_clip_mode,
			"player": player
		}, self)
	
	if Input.is_action_just_pressed("use"):
		if interaction_component:
			interaction_component.try_interact()
		use_pressed.emit()


func _toggle_debug_camera() -> void:
	Services.camera_manager.toggle_debug_camera()
	debug_camera_toggled.emit()


func _is_movement_blocked() -> bool:
	if player:
		return player.blocked_movement
	return false


func _is_player_dead() -> bool:
	if player:
		return player.is_dead()
	return false


func _get_gravity() -> float:
	if player:
		return player.gravity
	return ProjectSettings.get_setting("physics/3d/default_gravity")


func _get_last_velocity_y() -> float:
	if player:
		return player.last_velocity.y
	return 0.0


func _stop_all_movement() -> void:
	if player:
		player.velocity.x = 0
		player.velocity.z = 0
	if movement_component:
		movement_component.direction = Vector3.ZERO
