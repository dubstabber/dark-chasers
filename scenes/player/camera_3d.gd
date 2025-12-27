class_name PlayerCamera
extends Camera3D

## Handles all camera-related functionality for the player:
## - Mouse look (pitch on head, yaw on player)
## - FOV changes during sprint
## - Death camera effects (lowering, orientation toward killer)

signal fov_changed(new_fov: float)

@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.25
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

@export_group("FOV Settings")
@export var base_fov: float = 85.0
@export var sprint_fov: float = 110.0
@export var fov_step: float = 2.0

@export_group("Death Camera")
@export var death_depth_multiplier: float = 1.7
@export var death_lerp_speed: float = 3.0

@export_group("Node References")
@export var head: Node3D
@export var player: CharacterBody3D
@export var auto_discover: bool = true

@onready var crosshair_rect: TextureRect = $CrosshairRect

var _crouching_depth: float = -0.5


func _ready():
	if auto_discover:
		_auto_discover_dependencies()


func _auto_discover_dependencies() -> void:
	"""Auto-discover player and head from parent hierarchy"""
	# Camera is at: Player/nek/head/eyes/Camera3D
	# So we traverse up to find head and player
	var eyes = get_parent()
	if eyes:
		head = eyes.get_parent() # head node
		if head:
			var nek = head.get_parent()
			if nek:
				var potential_player = nek.get_parent()
				if potential_player is CharacterBody3D:
					player = potential_player


func _physics_process(_delta: float) -> void:
	# Handle crosshair visibility when switching cameras
	var current_camera = get_viewport().get_camera_3d()
	if self != current_camera:
		if crosshair_rect.visible: crosshair_rect.hide()
	else:
		if not crosshair_rect.visible: crosshair_rect.show()


func handle_mouse_look(relative: Vector2) -> void:
	"""Handle mouse look input - rotates player (yaw) and head (pitch)
	
	Args:
		relative: Mouse motion relative vector from InputEventMouseMotion
	"""
	if not player or not head:
		return
	
	# Rotate player horizontally (yaw)
	player.rotate_y(deg_to_rad(-relative.x * mouse_sensitivity))
	
	# Rotate head vertically (pitch) with clamping
	head.rotate_x(deg_to_rad(-relative.y * mouse_sensitivity))
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))


func set_sprint_fov(is_sprinting: bool) -> void:
	"""Adjust FOV based on sprint state
	
	Args:
		is_sprinting: Whether the player is currently sprinting
	"""
	if is_sprinting:
		fov += fov_step
		fov = clamp(fov, base_fov, sprint_fov)
	else:
		fov = base_fov
	
	fov_changed.emit(fov)


func apply_death_camera_lowering(delta: float) -> void:
	"""Gradually lower camera during death animation
	
	Args:
		delta: Frame delta time for smooth interpolation
	"""
	if not head:
		return
	
	var death_camera_depth = _crouching_depth * death_depth_multiplier
	head.position.y = lerp(head.position.y, death_camera_depth, delta * death_lerp_speed)


func orient_toward_position(target_pos: Vector3, delta: float) -> void:
	"""Smoothly orient player to face a target position (e.g., killer)
	
	Args:
		target_pos: World position to look toward
		delta: Frame delta time for smooth interpolation
	"""
	if not player or target_pos == Vector3.ZERO:
		return
	
	var distance = (target_pos - player.position).length()
	if distance < 0.1:
		return
	
	var look_direction = (target_pos - player.position).normalized()
	var target_transform = Transform3D()
	target_transform.origin = player.position
	target_transform = target_transform.looking_at(player.position + look_direction, Vector3.UP)
	
	player.transform = player.transform.interpolate_with(target_transform, death_lerp_speed * delta)


func center_pitch() -> void:
	"""Center the head pitch to look straight ahead (for fall deaths)"""
	if head:
		head.rotation.x = 0.0


func reset_camera() -> void:
	"""Reset camera to default state (after respawn)"""
	if head:
		head.position.y = 0.0
		head.rotation.x = 0.0
	fov = base_fov


func set_crouching_depth(depth: float) -> void:
	"""Set the crouching depth used for death camera calculations"""
	_crouching_depth = depth
