class_name PlayerInputComponent
extends Node

## Handles all player input: mouse look, movement keys, jump, crouch, use, respawn

signal respawn_requested()
signal use_pressed()
signal clip_mode_toggled(enabled: bool)
signal debug_camera_toggled()

@export_group("Node References")
@export var player: CharacterBody3D
@export var camera: Node3D # PlayerCamera
@export var movement_component: PlayerMovementComponent
@export var interaction_component: InteractionComponent
@export var animation_player: AnimationPlayer
@export var hud: CanvasLayer


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


func _physics_process(delta: float) -> void:
	if not player or not movement_component:
		return
	
	if not player.is_on_floor() and not movement_component.clip_mode:
		player.velocity.y -= _get_gravity() * delta
	
	if _is_movement_blocked():
		_stop_all_movement()
		return
	
	if not _is_player_dead():
		_process_movement_input(delta)
		_process_action_input()
	
	_update_last_velocity()
	player.move_and_slide()


func _process_movement_input(delta: float) -> void:
	var input_dir = Input.get_vector("move-left", "move-right", "move-up", "move-down")
	movement_component.process_movement(delta, input_dir)
	
	if camera and camera.has_method("set_sprint_fov"):
		camera.set_sprint_fov(movement_component.is_sprinting())
	
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
		if hud and hud.has_method("_on_player_mode_changed"):
			hud._on_player_mode_changed("clip_mode", new_clip_mode)
	
	if Input.is_action_just_pressed("use"):
		if interaction_component:
			interaction_component.try_interact()
		use_pressed.emit()


func _toggle_debug_camera() -> void:
	if not camera or not player:
		return
	
	# Get debug_camera from player (set by level script after _ready)
	var debug_cam = player.debug_camera if "debug_camera" in player else null
	if not debug_cam:
		return
	
	# Use CameraManager for centralized camera switching
	if CameraManager.is_camera_active(camera):
		CameraManager.set_active_camera(debug_cam)
	else:
		CameraManager.set_active_camera(camera)
	debug_camera_toggled.emit()


func set_hud(new_hud: CanvasLayer) -> void:
	hud = new_hud


func _is_movement_blocked() -> bool:
	if player and "blocked_movement" in player:
		return player.blocked_movement
	return false


func _is_player_dead() -> bool:
	if player and player.has_method("is_dead"):
		return player.is_dead()
	return false


func _get_gravity() -> float:
	if player and "gravity" in player:
		return player.gravity
	return ProjectSettings.get_setting("physics/3d/default_gravity")


func _get_last_velocity_y() -> float:
	if player and "last_velocity" in player:
		return player.last_velocity.y
	return 0.0


func _update_last_velocity() -> void:
	if player and "last_velocity" in player:
		player.last_velocity = player.velocity


func _stop_all_movement() -> void:
	if player:
		player.velocity.x = 0
		player.velocity.z = 0
	if movement_component:
		movement_component.direction = Vector3.ZERO
