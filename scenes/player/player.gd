class_name Player extends CharacterBody3D

@warning_ignore("UNUSED_SIGNAL")
signal weapon_added(weapon: WeaponResource)

const JUMP_VELOCITY := 6.0
const WALKING_SPEED := 5.0
const SPRINTING_SPEED := 8.0
const CROUCHING_SPEED := 3.0

const HEAD_BOBBING_SPRINTING_SPEED = 22.0
const HEAD_BOBBING_WALKING_SPEED = 14.0
const HEAD_BOBBING_CROUNCHING_SPEED = 10.0

const HEAD_BOBBING_SPRINTING_INTENSITY = 0.2
const HEAD_BOBBING_WALKING_INTENSITY = 0.1
const HEAD_BOBBING_CROUNCHING_INTENSITY = 0.05

var mouse_sens := 0.25
var current_speed := 5.0
var current_room: String
var direction := Vector3.ZERO
var fov := false
var lerp_speed := 10.0
var air_lerp_speed := 3.0
var dead_lerp_speed := 2.0
var gravity: int = ProjectSettings.get_setting("physics/3d/default_gravity")
var killed := false
var death_throw := 10.5
var clip_mode := false
var transit_pos: Marker3D = null
var is_climbing := false
var killed_pos: Vector3
var is_crounching := false
var crouching_depth := -0.5
var last_velocity = Vector2.ZERO
var current_weapon: int

var walking := false
var sprinting := false
var crouching := false
var sliding := false
var can_step := true

var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 10.0

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

var blocked_movement := false

var moving_state := "idle"

var hud: CanvasLayer

var debug_camera: Camera3D # temporary

@onready var nek = $nek
@onready var head = $nek/head
@onready var eyes = $nek/head/eyes
@onready var camera_3d = $nek/head/eyes/Camera3D
@onready var color_rect = $nek/head/eyes/Camera3D/DeathRect
@onready var stay_col = $StandingCollisionShape
@onready var crounch_col = $CrouchingCollisionShape
@onready var crounch_ray_cast_3d = $CrounchRayCast3D
@onready var animation_player = $nek/head/eyes/AnimationPlayer
@onready var sprite_animation_player = $SpriteAnimationPlayer

@onready var interaction = $nek/head/eyes/Camera3D/Interaction
@onready var interact_sound = $InteractSound
@onready var footstep_surface_detector: FootstepSurfaceDetector = $FootstepSurfaceDetector


func _update_animation_state():
	if velocity.length() > 0.1:
		moving_state = "run"
		sprite_animation_player.play("move")
	else:
		moving_state = "idle"
		sprite_animation_player.play("RESET")


func _input(event):
	if blocked_movement:
		return
	if not killed:
		if event is InputEventMouseMotion:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	if event.is_action_pressed("switch-debug-camera"):
		if camera_3d.current:
			debug_camera.current = true
		else:
			camera_3d.current = true


func _physics_process(delta):
	if not is_on_floor() and not clip_mode:
		velocity.y -= gravity * delta
	if blocked_movement:
		return
	if not killed:
		var input_dir = Input.get_vector("move-left", "move-right", "move-up", "move-down")
		if (Input.is_action_pressed("crouch") or sliding) and not clip_mode:
			current_speed = lerp(current_speed, CROUCHING_SPEED, delta * lerp_speed)
			head.position.y = lerp(head.position.y, crouching_depth, delta * lerp_speed)
			stay_col.disabled = true
			crounch_col.disabled = false
			
			if sprinting and input_dir != Vector2.ZERO:
				sliding = true
				slide_timer = slide_timer_max
				slide_vector = input_dir
			
			walking = false
			sprinting = false
			crouching = true
		elif not crounch_ray_cast_3d.is_colliding():
			stay_col.disabled = false
			crounch_col.disabled = true
			head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
			if Input.is_action_pressed("sprint") and velocity.length() > 0.1:
				current_speed = lerp(current_speed, SPRINTING_SPEED, delta * lerp_speed)
				camera_3d.fov += 2
				camera_3d.fov = clamp(camera_3d.fov, 85, 110)
				walking = false
				sprinting = true
				crouching = false
			else:
				current_speed = lerp(current_speed, WALKING_SPEED, delta * lerp_speed)
				camera_3d.fov = 85
				walking = true
				sprinting = false
				crouching = false
				
		if sliding:
			slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
		
		if sprinting:
			head_bobbing_current_intensity = HEAD_BOBBING_SPRINTING_INTENSITY
			head_bobbing_index += HEAD_BOBBING_SPRINTING_SPEED * delta
		elif walking:
			head_bobbing_current_intensity = HEAD_BOBBING_WALKING_INTENSITY
			head_bobbing_index += HEAD_BOBBING_WALKING_SPEED * delta
		elif crouching:
			head_bobbing_current_intensity = HEAD_BOBBING_CROUNCHING_INTENSITY
			head_bobbing_index += HEAD_BOBBING_CROUNCHING_SPEED * delta
		
		if is_on_floor() and not sliding and input_dir != Vector2.ZERO:
			head_bobbing_vector.y = sin(head_bobbing_index)
			head_bobbing_vector.x = sin(head_bobbing_index / 2)
			
			if head_bobbing_vector.y > -head_bobbing_current_intensity:
				can_step = true
			if head_bobbing_vector.y < -head_bobbing_current_intensity and can_step:
				can_step = false
				footstep_surface_detector.play_footstep()
			
			eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0), delta * lerp_speed)
			eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * (head_bobbing_current_intensity / 2.0), delta * lerp_speed)
		else:
			eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
			eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)
			
		if Input.is_action_just_pressed("jump") and clip_mode:
			velocity.y = current_speed
		elif Input.is_action_just_released("jump") and clip_mode:
			velocity.y = move_toward(velocity.y, 0, current_speed)
		
		if Input.is_action_just_pressed("crouch"):
			if clip_mode:
				velocity.y = - current_speed
		elif Input.is_action_just_released("crouch"):
			if clip_mode:
				velocity.y = 0
		
		if Input.is_action_just_pressed("jump") and is_on_floor():
			if not clip_mode:
				velocity.y = JUMP_VELOCITY
				sliding = false
				animation_player.play("jump")
		if is_on_floor():
			if last_velocity.y < -4.0:
				animation_player.play("landing")
			
		if is_on_floor():
			direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
		else:
			if input_dir != Vector2.ZERO:
				direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * air_lerp_speed)
			
		if sliding:
			direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
			current_speed = (slide_timer + 0.1) * slide_speed

		if Input.is_action_just_pressed("toggle-clip-mode"):
			clip_mode = not clip_mode
			if hud: hud._on_player_mode_changed("clip_mode", clip_mode)
			if clip_mode:
				collision_mask = 10
				velocity = Vector3.ZERO
			else:
				collision_mask = 14

		if Input.is_action_just_pressed("use"):
			var collider = interaction.get_collider()
			if collider:
				var root_node = collider.get_parent()
				if root_node is Openable or root_node.is_in_group("door"):
					if root_node.has_method("open_with_point"):
						root_node.open_with_point(interaction.get_collision_point())
					
				if collider.is_in_group("button"):
					collider.press(self)
			if transit_pos:
				position = transit_pos.global_position
				transit_pos = null
		
		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)
		if is_climbing and input_dir:
			velocity.y = current_speed
			
		# Update animation state based on movement
		_update_animation_state()

		last_velocity = velocity
		move_and_slide()
	else:
		if death_throw > 0:
			velocity = - direction * death_throw
			transform = transform.interpolate_with(transform.looking_at(killed_pos), lerp_speed * delta)
			move_and_slide()
			death_throw -= 0.1


func kill(pos = null):
	if not killed:
		if pos:
			direction = (pos - position).normalized()
			direction.y = 0
			killed_pos = pos
		killed = true
		color_rect.modulate.a = 0.7
		Utils.play_sound(Preloads.KILL_PLAYER_SOUND, self)
