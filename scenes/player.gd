extends CharacterBody3D

signal mode_changed(mode, value)

const JUMP_VELOCITY = 4.5

@export var SPEED = 5.0
@export var sensivity = 0.3

var current_room: String
var map: Node3D
var direction: Vector3
var fov := false
var lerp_speed := 2
var gravity: int = ProjectSettings.get_setting("physics/3d/default_gravity")
var killed := false
var death_throw := 10.5
var clip_mode := false
var transit_pos: Marker3D = null
var is_climbing := false
var killed_pos: Vector3

@onready var camera_3d = $Camera3D
@onready var color_rect = $Camera3D/ColorRect


func _ready():
	map = get_tree().get_first_node_in_group("map")
	camera_3d.fov = 85


func _input(event):
	if !killed:
		if event is InputEventMouseMotion:
			camera_3d.rotation_degrees.x -= event.relative.y * sensivity
			camera_3d.rotation_degrees.x = clamp(camera_3d.rotation_degrees.x, -90, 90)
			rotation_degrees.y -= event.relative.x * sensivity


func _physics_process(delta):
	if !killed:
		if not is_on_floor() and not clip_mode:
			velocity.y -= gravity * delta
		if Input.is_action_just_pressed("jump") and is_on_floor() and not clip_mode:
			velocity.y = JUMP_VELOCITY
		if Input.is_action_just_pressed("jump") and clip_mode:
			velocity.y = SPEED
		elif Input.is_action_just_released("jump") and clip_mode:
			velocity.y = move_toward(velocity.y, 0, SPEED)
		if Input.is_action_pressed("run"):
			camera_3d.fov += 2
			camera_3d.fov = clamp(camera_3d.fov, 85, 110)
			SPEED = 8.0
		if Input.is_action_just_released("run"):
			camera_3d.fov = 85
			SPEED = 5.0
		if Input.is_action_just_pressed("crounch"):
			if clip_mode:
				velocity.y = -SPEED
			else:
				#TODO: implement crounching
				pass
		elif Input.is_action_just_released("crounch"):
			if clip_mode:
				velocity.y = move_toward(velocity.y, 0, SPEED)

		if Input.is_action_just_pressed("toggle-clip-mode"):
			clip_mode = not clip_mode
			mode_changed.emit("clip_mode", clip_mode)
			if collision_mask == 14:
				collision_mask = 10
				velocity.y = 0
			else:
				collision_mask = 14

		if Input.is_action_just_pressed("use"):
			if transit_pos:
				position = transit_pos.global_position
				transit_pos = null

		var input_dir = Input.get_vector("move-left", "move-right", "move-up", "move-down")
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
		if is_climbing and input_dir:
			velocity.y = SPEED
		move_and_slide()
	else:
		if death_throw > 0:
			velocity = -direction * death_throw
			transform = transform.interpolate_with(transform.looking_at(killed_pos), lerp_speed * delta)
			move_and_slide()
			death_throw -= 0.1


func get_camera() -> Camera3D:
	return $Camera3D


func kill(pos):
	direction = (pos - position).normalized()
	direction.y = 0
	killed = true
	color_rect.modulate.a = 0.7
	killed_pos = pos
