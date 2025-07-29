class_name Player extends CharacterBody3D

## Player controller with integrated health system
##
## This player controller includes movement, interaction, and health management
## through a HealthComponent. The health system provides damage handling,
## healing, death mechanics, and invulnerability frames.
##
## Health Integration:
## - Uses HealthComponent for all health-related operations
## - Delegates damage/healing to the health component
## - Connects health component signals for death and damage events
## - Maintains backward compatibility with existing kill() method

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

# Fall damage configuration
const FALL_DAMAGE_SAFE_SPEED = 8.0 # No damage below this fall speed
const FALL_DAMAGE_MIN_SPEED = 12.0 # Minimum speed to start taking damage
const FALL_DAMAGE_MULTIPLIER = 2.0 # Damage scaling factor
const FALL_DAMAGE_MAX = 50 # Maximum fall damage per impact

# Damage blink effect configuration
const DAMAGE_BLINK_COLOR = Color(1.0, 0.0, 0.0, 0.3) # Red damage tint
const DAMAGE_BLINK_FADE_IN_TIME = 0.1 # Quick fade to damage color
const DAMAGE_BLINK_HOLD_TIME = 0.15 # Hold damage color briefly
const DAMAGE_BLINK_FADE_OUT_TIME = 0.8 # Smooth fade back to transparent
const DAMAGE_BLINK_ORIGINAL_MODULATE = Color(1.0, 1.0, 1.0, 0.0) # DeathRect default state

# Death animation configuration
const DEATH_THROW_SPEED = 7.0 # Speed for enemy-caused death throw animation

var mouse_sens := 0.25
var current_speed := 5.0
var current_room: String
var direction := Vector3.ZERO
var fov := false
var lerp_speed := 10.0
var air_lerp_speed := 3.0
var dead_lerp_speed := 3.0
var gravity: int = ProjectSettings.get_setting("physics/3d/default_gravity")
var killed := false # Legacy death state - kept for death animation compatibility
var death_throw := DEATH_THROW_SPEED
var clip_mode := false
var transit_pos: Marker3D = null
var is_climbing := false
var killed_pos: Vector3 = Vector3.ZERO
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

# Fall damage tracking
var was_airborne := false # Track if player was in the air last frame
var fall_start_velocity := 0.0 # Track velocity when starting to fall

# Damage blink effect
var damage_blink_tween: Tween

var hud: CanvasLayer: set = set_hud

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
@onready var health_component: HealthComponent = $HealthComponent
@onready var weapon_manager: WeaponManager = $WeaponManager


func _ready():
	# Configure and connect health component
	# The HealthComponent handles all health logic, damage, healing, and death
	if health_component:
		# Configure health settings
		health_component.invulnerability_duration = 0.5 # Brief invulnerability after taking damage

		# Configure audio
		health_component.death_sound = Preloads.KILL_PLAYER_SOUND
		# Note: damage_sound and heal_sound can be set later if needed

		# Connect signals
		health_component.died.connect(_on_health_component_died)
		health_component.damage_taken.connect(_on_health_component_damage_taken)
		health_component.health_changed.connect(_on_health_component_health_changed)

		# Initialize health display (will be called again when HUD is connected)
		_initialize_health_display()

	# Connect weapon manager signals for ammo display
	if weapon_manager:
		weapon_manager.weapon_ammo_changed.connect(_on_weapon_ammo_changed)
		weapon_manager.weapon_switched.connect(_on_weapon_switched)


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
	if not is_dead():
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
	if not is_dead():
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

			# Fall damage detection - check if we just landed from a fall
			if was_airborne and not clip_mode:
				_check_fall_damage(last_velocity.y)
			
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

		# Update fall tracking state
		_update_fall_tracking()

		last_velocity = velocity
		move_and_slide()
	else:
		# Death animation: different behavior based on death cause
		if death_throw > 0:
			# Apply gradual camera lowering for all death types (simulate collapsing)
			_apply_death_camera_lowering(delta)

			# Different movement behavior based on death cause
			if killed_pos != Vector3.ZERO:
				# Enemy-caused death: throw player backward away from enemy
				velocity = - direction * death_throw

				# Apply smooth camera rotation to face the enemy during death throw
				var distance_to_enemy = (killed_pos - position).length()
				if distance_to_enemy > 0.1:
					# Create target transform that looks at the enemy
					var look_direction = (killed_pos - position).normalized()
					var target_transform = Transform3D()
					target_transform.origin = position
					target_transform = target_transform.looking_at(position + look_direction, Vector3.UP)

					# Smoothly interpolate toward the target transform
					transform = transform.interpolate_with(target_transform, dead_lerp_speed * delta)
			else:
				# Fall damage death: no movement, just collapse in place
				# Stop all movement - player should stay where they died
				velocity = Vector3.ZERO

			move_and_slide()
			death_throw -= 0.1


func kill(pos = null):
	"""Kill the player instantly

	This method maintains backward compatibility while using the HealthComponent.
	It's called by enemies and environmental hazards to instantly kill the player.

	Args:
		pos: Optional position of the damage source for death animation direction
	"""
	if not is_dead():
		if pos:
			direction = (pos - position).normalized()
			direction.y = 0
			killed_pos = pos

		# Use health component to handle death if available
		if health_component:
			health_component.kill()
		else:
			# Fallback to old system
			killed = true
			color_rect.modulate.a = 0.7
			Utils.play_sound(Preloads.KILL_PLAYER_SOUND, self)


## Health System Integration
##
## The player uses a HealthComponent for all health-related functionality:
## - Health management (current/max health, damage, healing)
## - Death handling with proper signals and audio
## - Invulnerability frames after taking damage
## - Integration with existing game systems (enemies, health items)
##
## Key Integration Points:
## - take_damage() method delegates to HealthComponent
## - kill() method uses HealthComponent.kill() for instant death
## - Health items automatically work with HealthComponent
## - Enemy kill zones work through the kill() method
## - Death animations and effects handled through signal connections
## - Weapon death animations: stops bobbing and plays weapon lowering animation
## - Fall damage system: monitors landing velocity and applies damage accordingly
## - Damage blink effect: visual feedback through DeathRect color tinting

## Health Component Signal Handlers
## These methods are called by the HealthComponent when health events occur

func _on_health_component_died():
	"""Called when the health component signals death

	Handles the visual death effects while the HealthComponent handles
	the death logic, audio, and state management.
	"""
	if not killed:
		killed = true

		# Handle weapon death animations immediately
		_handle_weapon_death_animations()

		# Handle camera orientation for death animation
		_setup_death_camera_orientation()

		# Configure collision shapes for death state
		_configure_death_collision()

		# Apply persistent death screen overlay
		_apply_death_overlay()
		# Note: Death sound is handled by the health component


func _on_health_component_damage_taken(_amount: int, _current_health: int):
	"""Called when the player takes damage

	This is where you can add player-specific damage effects like:
	- Screen shake
	- Damage indicators
	- Visual effects
	- Camera effects
	"""
	# Play damage blink effect for visual feedback
	_play_damage_blink_effect()


func _on_health_component_health_changed(current_health: int, max_health: int):
	"""Called when health changes (damage or healing)

	This is where you can update UI elements like:
	- Health bars
	- Health indicators
	- HUD elements
	"""
	# Update HUD health display
	if hud and hud.has_method("update_health_display"):
		hud.update_health_display(current_health, max_health)


func _initialize_health_display():
	"""Initialize the health display in the HUD

	This method ensures the HUD shows the correct health value when the player
	is first created or when the HUD connection is established.
	"""
	if hud and hud.has_method("update_health_display") and health_component:
		hud.update_health_display(health_component.current_health, health_component.max_health)


func set_hud(new_hud: CanvasLayer):
	"""Setter for the HUD reference

	Automatically initializes the health and ammo displays when the HUD is connected.
	"""
	hud = new_hud
	_initialize_health_display()
	_initialize_ammo_display()


## Weapon System Signal Handlers
## These methods are called by the WeaponManager when weapon/ammo events occur

func _on_weapon_ammo_changed(current_ammo: int, max_ammo: int):
	"""Called when the current weapon's ammo changes

	Updates the HUD ammo display with the new ammo values.
	"""
	if hud and hud.has_method("update_ammo_display"):
		hud.update_ammo_display(current_ammo, max_ammo)


func _on_weapon_switched(weapon: WeaponResource):
	"""Called when the player switches weapons

	Updates the HUD to show the new weapon's ammo count.
	"""
	if hud and hud.has_method("update_ammo_display"):
		hud.update_ammo_display(weapon.current_ammo, weapon.max_ammo)


func _initialize_ammo_display():
	"""Initialize the ammo display in the HUD

	This method ensures the HUD shows the correct ammo value when the player
	is first created or when the HUD connection is established.
	"""
	if hud and hud.has_method("update_ammo_display") and weapon_manager and weapon_manager.current_weapon:
		var weapon = weapon_manager.current_weapon
		hud.update_ammo_display(weapon.current_ammo, weapon.max_ammo)


func _handle_weapon_death_animations():
	"""Handle weapon-specific animations when the player dies

	This method implements the following weapon death effects:
	1. Stops weapon bobbing animations
	2. Plays weapon pullout animation in reverse (weapon lowering effect)
	3. Ensures immediate response to death for better visual feedback
	"""
	if not weapon_manager:
		return

	# 1. Stop weapon bobbing animations
	weapon_manager.disable_weapon_bobbing()

	# 2. Play weapon pullout animation in reverse if available
	if weapon_manager.current_weapon and weapon_manager.current_weapon.pullout_anim_name:
		var weapon_animation_player = weapon_manager.animation_player
		if weapon_animation_player:
			# Stop any current animation
			weapon_animation_player.stop()

			# Play the pullout animation backwards to create weapon lowering effect
			weapon_animation_player.play_backwards(weapon_manager.current_weapon.pullout_anim_name)

	# 3. Stop any auto-hitting behavior
	weapon_manager.is_auto_hitting = false


func _handle_weapon_revival():
	"""Handle weapon-specific animations when the player is revived

	This method restores normal weapon functionality:
	1. Re-enables weapon bobbing animations
	2. Resets weapon state
	3. Plays weapon pullout animation to "re-equip" current weapon
	4. Resets death animation state
	5. Re-enables collision shapes
	6. Resets camera position and death overlay
	"""
	if not weapon_manager:
		return

	weapon_manager.reset_weapon_on_revival()

	# Reset death animation state
	killed_pos = Vector3.ZERO
	death_throw = DEATH_THROW_SPEED

	# Re-enable collision shapes
	_enable_revival_collision()

	# Reset camera position and death overlay
	_reset_death_effects()


func _setup_death_camera_orientation():
	"""Setup proper camera orientation for death animation

	Handles two scenarios:
	1. Enemy-caused death: Orient camera toward the enemy that killed the player
	2. Fall damage death: Center head pitch only, no horizontal rotation
	"""
	# Check if we have a valid enemy position (killed_pos was set by kill() method)
	if killed_pos != Vector3.ZERO:
		# Enemy-caused death: Orient camera toward the enemy
		_orient_camera_toward_enemy()
	else:
		# Fall damage or other non-enemy death: Only center the head pitch
		# Keep killed_pos as Vector3.ZERO to prevent any camera rotation in death animation
		_center_head_pitch_for_fall_death()


func _center_head_pitch_for_fall_death():
	"""Center the head pitch for fall damage deaths

	For fall damage deaths, we only want to center the vertical look angle
	to look straight ahead horizontally. We preserve the current horizontal
	orientation (yaw) and don't rotate toward any target.
	"""
	if not head:
		return

	# Only center the head's X rotation (pitch) to look straight ahead
	# Don't change the player's Y rotation (yaw) - preserve horizontal orientation
	head.rotation.x = 0.0


func _configure_death_collision():
	"""Configure collision shapes for death state

	Disables the standing collision shape but keeps the crouching collision shape
	active to prevent the player from falling through the map or going outside
	the playable area during death animations. The smaller crouching shape is
	more appropriate for a collapsed/dead player state.
	"""
	if stay_col:
		stay_col.disabled = true
	if crounch_col:
		crounch_col.disabled = false # Keep crouching collision active for death state


func _apply_death_overlay():
	"""Apply persistent death screen overlay

	Sets the DeathRect to show the red death overlay and ensures it persists
	throughout the entire death sequence. Stops any damage blink effects that
	might interfere with the death overlay.
	"""
	if not color_rect:
		return

	# Stop any damage blink tween that might interfere with death overlay
	if damage_blink_tween:
		damage_blink_tween.kill()
		damage_blink_tween = null

	# Apply persistent death overlay (red tint with 0.7 alpha)
	color_rect.modulate = Color(1.0, 0.0, 0.0, 0.7)


func _apply_death_camera_lowering(delta: float):
	"""Apply gradual camera lowering during death throw animation

	Simulates the player collapsing/falling to the ground by gradually
	lowering the camera position. Uses the same lerping system as crouching
	but targets a lower position to simulate death collapse.

	Args:
		delta: Frame delta time for smooth interpolation
	"""
	if not head:
		return

	# Target position for death camera lowering (lower than crouching)
	var death_camera_depth = crouching_depth * 1.7

	# Gradually lower the camera using the same lerp system as crouching
	head.position.y = lerp(head.position.y, death_camera_depth, delta * dead_lerp_speed)


func _enable_revival_collision():
	"""Restore normal collision shapes when player is revived

	Restores normal collision detection for physics interactions.
	Enables the standing collision shape and disables the crouching collision
	shape to return to the normal alive state.
	"""
	if stay_col:
		stay_col.disabled = false # Enable standing collision for normal gameplay
	if crounch_col:
		crounch_col.disabled = true # Disable crouching collision (normal state)


func _reset_death_effects():
	"""Reset camera position and death overlay when player is revived

	Restores normal camera position and clears the death screen overlay.
	This ensures the player returns to a normal state after revival.
	"""
	# Reset head position to normal (not lowered)
	if head:
		head.position.y = 0.0

	# Clear death overlay and restore transparent state
	if color_rect:
		color_rect.modulate = DAMAGE_BLINK_ORIGINAL_MODULATE


func _orient_camera_toward_enemy():
	"""Prepare camera orientation for enemy death animation

	This method is called when an enemy kills the player to set up the death animation.
	The actual camera rotation is handled gradually by the death animation loop using
	transform.looking_at() interpolation for smooth movement.

	Note: We don't apply immediate rotation here to avoid conflicts with the
	death animation loop's transform interpolation.
	"""
	# The death animation loop will handle the actual camera rotation using:
	# transform.looking_at(killed_pos) with interpolation
	# This ensures smooth rotation toward the enemy during the death throw
	pass


## Fall Damage System
## Monitors player landing velocity and applies damage through HealthComponent

func _update_fall_tracking():
	"""Update fall tracking state to detect when player transitions from air to ground"""
	var currently_airborne = not is_on_floor()

	# Track transition from airborne to grounded for fall damage detection
	was_airborne = currently_airborne


func _check_fall_damage(fall_velocity: float):
	"""Check if fall damage should be applied based on landing velocity

	Args:
		fall_velocity: The vertical velocity when landing (negative value)
	"""
	if is_dead():
		return

	# Convert to positive fall speed for easier calculation
	var fall_speed = abs(fall_velocity)

	# Check if fall speed exceeds safe threshold
	if fall_speed < FALL_DAMAGE_SAFE_SPEED:
		return

	# Calculate fall damage
	var damage_amount = 0
	if fall_speed >= FALL_DAMAGE_MIN_SPEED:
		damage_amount = int((fall_speed - FALL_DAMAGE_SAFE_SPEED) * FALL_DAMAGE_MULTIPLIER)
		damage_amount = min(damage_amount, FALL_DAMAGE_MAX)

	if damage_amount > 0:
		take_damage(damage_amount)


func _play_damage_blink_effect():
	"""Play a red blink effect on the DeathRect when taking damage

	Creates a smooth fade-in, hold, fade-out sequence using modulate property:
	1. Quick fade to red damage color with visible alpha
	2. Brief hold at damage color
	3. Smooth fade back to transparent

	Note: Uses modulate property since DeathRect has modulate.a = 0 by default,
	making color changes invisible. Death overlay also uses modulate.a = 0.7.

	Handles rapid damage events correctly by always restoring to the true
	original transparent state, preventing residual red tinting.

	Does not play if player is dead to avoid interfering with death overlay.
	"""
	if not color_rect or is_dead():
		return

	# Stop any existing blink tween
	if damage_blink_tween:
		damage_blink_tween.kill()

	# Create new tween for the blink effect
	damage_blink_tween = create_tween()

	# Use the defined constant for the true original state (transparent)
	# This ensures consistency with the scene configuration

	# Chain the tween sequence properly
	# 1. Fade in to damage color (red with visible alpha)
	damage_blink_tween.tween_property(color_rect, "modulate", DAMAGE_BLINK_COLOR, DAMAGE_BLINK_FADE_IN_TIME)

	# 2. Hold at damage color (using tween_interval instead of tween_delay)
	damage_blink_tween.tween_interval(DAMAGE_BLINK_HOLD_TIME)

	# 3. Fade out to transparent (always use the true original state)
	damage_blink_tween.tween_property(color_rect, "modulate", DAMAGE_BLINK_ORIGINAL_MODULATE, DAMAGE_BLINK_FADE_OUT_TIME)

	# 4. Ensure we end up in the correct state (redundant safety check)
	damage_blink_tween.tween_callback(func():
		if not is_dead():
			color_rect.modulate = DAMAGE_BLINK_ORIGINAL_MODULATE
	)


func configure_fall_damage(safe_speed: float = FALL_DAMAGE_SAFE_SPEED,
						   min_speed: float = FALL_DAMAGE_MIN_SPEED,
						   multiplier: float = FALL_DAMAGE_MULTIPLIER,
						   max_damage: int = FALL_DAMAGE_MAX):
	"""Configure fall damage parameters at runtime

	Args:
		safe_speed: Maximum fall speed without damage
		min_speed: Minimum speed to start taking damage
		multiplier: Damage scaling factor
		max_damage: Maximum damage per fall
	"""
	# Note: These would need to be instance variables to be configurable
	# For now, this serves as documentation of the configurable parameters
	print("Fall damage configured: safe=", safe_speed, " min=", min_speed, " mult=", multiplier, " max=", max_damage)


## Health Management Methods
## These methods provide a clean interface to the HealthComponent

func take_damage(amount: int) -> bool:
	"""Take damage using the health component

	Args:
		amount: Amount of damage to take

	Returns:
		bool: True if damage was applied, False if blocked (invulnerable, dead, etc.)
	"""
	if health_component:
		return health_component.take_damage(amount)
	return false


func heal(amount: int) -> bool:
	"""Heal using the health component

	Args:
		amount: Amount of health to restore

	Returns:
		bool: True if healing was applied, False if at full health or dead
	"""
	if health_component:
		return health_component.heal(amount)
	return false


func get_health() -> int:
	"""Get current health value

	Returns:
		int: Current health points
	"""
	if health_component:
		return health_component.get_health()
	return 0


func get_max_health() -> int:
	"""Get maximum health value

	Returns:
		int: Maximum health points
	"""
	if health_component:
		return health_component.get_max_health()
	return 0


func is_alive() -> bool:
	"""Check if player is alive

	Returns:
		bool: True if player is alive and has health > 0
	"""
	if health_component:
		return health_component.is_alive()
	return not killed


func is_dead() -> bool:
	"""Check if player is dead

	Returns:
		bool: True if player is dead (health <= 0)
	"""
	if health_component:
		return health_component.is_dead
	return killed
