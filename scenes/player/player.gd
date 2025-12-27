class_name Player extends CharacterBody3D


@warning_ignore("UNUSED_SIGNAL")
signal weapon_added(weapon: WeaponResource)

var current_room: String
var gravity: int = ProjectSettings.get_setting("physics/3d/default_gravity")
var last_velocity = Vector2.ZERO

var blocked_movement := false

# Death message tracking (used by death component for HUD)
var _died_from_fall_damage := false
var _death_message: String = ""

var hud: CanvasLayer: set = set_hud

var debug_camera: Camera3D # temporary

@onready var camera_3d = $nek/head/eyes/Camera3D # PlayerCamera extends Camera3D
@onready var animation_player = $nek/head/eyes/AnimationPlayer
@onready var sprite_animation_player = $SpriteAnimationPlayer
@onready var footstep_surface_detector: FootstepSurfaceDetector = $FootstepSurfaceDetector
@onready var health_component: HealthComponent = $HealthComponent
@onready var armor_component = $ArmorComponent
@onready var ammo_component: PlayerAmmoComponent = $PlayerAmmoComponent
@onready var weapon_manager: WeaponManager = $WeaponManager
@onready var movement_component: PlayerMovementComponent = $PlayerMovementComponent
@onready var head_bobbing_component: HeadBobbingComponent = $HeadBobbingComponent
@onready var fall_damage_component: FallDamageComponent = $FallDamageComponent
@onready var death_component: PlayerDeathComponent = $PlayerDeathComponent
@onready var interaction_component: InteractionComponent = $InteractionComponent
@onready var sprite_animation_component: SpriteAnimationComponent = $SpriteAnimationComponent


func _ready():
	if not hud:
		_auto_discover_hud()

	if health_component:
		health_component.death_sound = Preloads.KILL_PLAYER_SOUND
		health_component.damage_taken.connect(_on_health_component_damage_taken)

	if armor_component:
		armor_component.max_armor = 100
		armor_component.current_armor = 0

	if weapon_manager:
		_setup_weapon_ammo_components()
	
	_setup_modular_components()


func _setup_modular_components() -> void:
	if head_bobbing_component:
		head_bobbing_component.footstep_triggered.connect(_on_footstep_triggered)
	
	if fall_damage_component:
		fall_damage_component.fatal_fall.connect(_on_fatal_fall)
	
	if death_component:
		if health_component:
			health_component.died.connect(death_component._on_health_died)
		death_component.death_animation_started.connect(_on_death_component_died)
	
	if sprite_animation_component and sprite_animation_player:
		sprite_animation_player.animation_finished.connect(sprite_animation_component.on_animation_finished)


func _on_footstep_triggered() -> void:
	if footstep_surface_detector:
		footstep_surface_detector.play_footstep()


func _on_fatal_fall() -> void:
	_died_from_fall_damage = true


func _input(event):
	if event.is_action_pressed("respawn"):
		respawn()
		return
	if blocked_movement:
		return
	if not is_dead():
		if event is InputEventMouseMotion:
			camera_3d.handle_mouse_look(event.relative)
	if event.is_action_pressed("switch-debug-camera"):
		if camera_3d.current:
			debug_camera.current = true
		else:
			camera_3d.current = true


func _physics_process(delta):
	if not is_on_floor() and not movement_component.clip_mode:
		velocity.y -= gravity * delta
	
	if blocked_movement:
		return
	
	if not is_dead():
		var input_dir = Input.get_vector("move-left", "move-right", "move-up", "move-down")
		movement_component.process_movement(delta, input_dir)
		camera_3d.set_sprint_fov(movement_component.is_sprinting())
		
		if Input.is_action_just_pressed("jump"):
			if movement_component.handle_jump():
				if not movement_component.clip_mode:
					animation_player.play("jump")
		elif Input.is_action_just_released("jump"):
			movement_component.handle_jump_release()
		
		if Input.is_action_just_pressed("crouch"):
			movement_component.handle_crouch_press()
		elif Input.is_action_just_released("crouch"):
			movement_component.handle_crouch_release()
		
		if is_on_floor() and last_velocity.y < -4.0:
			animation_player.play("landing")
		
		if Input.is_action_just_pressed("toggle-clip-mode"):
			var new_clip_mode = movement_component.toggle_clip_mode()
			if hud:
				hud._on_player_mode_changed("clip_mode", new_clip_mode)
		
		if Input.is_action_just_pressed("use"):
			_handle_use_input()
		
		last_velocity = velocity
		move_and_slide()
	

func _handle_use_input() -> void:
	"""Handle 'use' input - delegates to InteractionComponent"""
	if interaction_component:
		interaction_component.try_interact()


func kill(pos = null, death_message: String = ""):
	"""Kill the player instantly

	This method maintains backward compatibility while using the HealthComponent.
	It's called by enemies and environmental hazards to instantly kill the player.

	Args:
		pos: Optional position of the damage source for death animation direction
		death_message: Optional custom message to display in the HUD log
	"""
	if not is_dead():
		_death_message = death_message
		if death_component:
			if pos:
				death_component.set_killed_position(pos)
				death_component.set_death_direction((pos - position).normalized())
			death_component.kill_with_direction(pos if pos else Vector3.ZERO, death_message)
		elif health_component:
			health_component.kill()


func _on_death_component_died():
	"""Called when death_component triggers death - handles HUD messages"""
	if _died_from_fall_damage and hud:
		hud.add_log("Player fell too far.")
		_died_from_fall_damage = false
	elif _death_message != "" and hud:
		hud.add_log(_death_message)
	_death_message = ""


func _on_health_component_damage_taken(_amount: int, _current_health: int):
	"""Called when the player takes damage

	This is where you can add player-specific damage effects like:
	- Screen shake
	- Damage indicators
	- Visual effects
	- Camera effects
	"""


func set_hud(new_hud: CanvasLayer):
	"""Setter for the HUD reference

	Connects HUD directly to player components for automatic updates.
	"""
	hud = new_hud
	if hud and hud.has_method("connect_to_player"):
		hud.connect_to_player(self)


func _auto_discover_hud() -> void:
	"""Auto-discover HUD via group if not explicitly set
	
	This provides a fallback mechanism for flexible level design. If the level
	doesn't explicitly set player.hud, the player can find the HUD by looking
	for nodes in the "hud" group. This makes the player more self-contained
	and reduces boilerplate in level scripts.
	
	Note: This is called in _ready() only if hud is not already set.
	"""
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		set_hud(hud_nodes[0])


func _setup_weapon_ammo_components():
	"""Set up ammo component references for all weapons in the weapon manager"""
	if not weapon_manager or not ammo_component:
		return

	for slot_index in range(1, 10): # Slots 1-9
		var slot_weapons = weapon_manager.get_slot_weapons(slot_index)
		for weapon in slot_weapons:
			weapon.ammo_component = ammo_component


func respawn(health_amount: int = -1):
	"""Respawn the player - delegates to death_component"""
	if death_component:
		death_component.respawn(health_amount)
	elif is_dead() and health_component:
		health_component.revive(health_amount)


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
	return false


func is_dead() -> bool:
	"""Check if player is dead

	Returns:
		bool: True if player is dead (health <= 0)
	"""
	if health_component:
		return health_component.is_dead
	return true


const MIN_HEALTH_TO_SPRINT := 30

func _can_sprint() -> bool:
	"""Check if player has enough health to sprint

	Returns:
		bool: True if player can sprint (health >= MIN_HEALTH_TO_SPRINT)
	"""
	if health_component:
		return health_component.current_health >= MIN_HEALTH_TO_SPRINT
	return true


## Armor Management Methods
## These methods provide a clean interface to the ArmorComponent

func add_armor(amount: int) -> bool:
	"""Add armor using the armor component

	Args:
		amount: Amount of armor to add

	Returns:
		bool: True if armor was added, False if at maximum or invalid amount
	"""
	if armor_component:
		return armor_component.add_armor(amount)
	return false


func get_armor() -> int:
	"""Get current armor value

	Returns:
		int: Current armor points
	"""
	if armor_component:
		return armor_component.get_armor()
	return 0


func get_max_armor() -> int:
	"""Get maximum armor value

	Returns:
		int: Maximum armor points
	"""
	if armor_component:
		return armor_component.get_max_armor()
	return 0


func has_armor() -> bool:
	"""Check if player has armor

	Returns:
		bool: True if player has armor > 0 and armor is not broken
	"""
	if armor_component:
		return armor_component.has_armor()
	return false


func get_armor_percentage() -> float:
	"""Get armor as a percentage of maximum

	Returns:
		float: Armor percentage (0.0 to 1.0)
	"""
	if armor_component:
		return armor_component.get_armor_percentage()
	return 0.0


## Ammo Management Methods
## These methods provide a clean interface to the WeaponManager for ammo operations

func add_ammo(amount: int, all_weapons: bool = false) -> bool:
	"""Add ammo to weapons using the component-based ammo system

	Args:
		amount: Amount of ammo to add
		all_weapons: If true, add ammo to all non-infinite weapons

	Returns:
		bool: True if ammo was added to at least one weapon, False otherwise
	"""
	if not weapon_manager or not ammo_component:
		return false

	var ammo_added = false
	var ammo_types_added = {} # Track which ammo types we've already added to

	if all_weapons:
		# Add ammo to all non-infinite weapons by ammo type
		for slot_index in range(1, 10): # Slots 1-9
			var slot_array = weapon_manager.get_slot_weapons(slot_index)
			for weapon in slot_array:
				if not weapon.infinite_ammo and weapon.ammo_type != "":
					if not ammo_types_added.has(weapon.ammo_type):
						if ammo_component.add_ammo(weapon.ammo_type, amount):
							ammo_added = true
							ammo_types_added[weapon.ammo_type] = true
	else:
		# Default: add ammo to current weapon's ammo type
		if weapon_manager.current_weapon and not weapon_manager.current_weapon.infinite_ammo:
			if weapon_manager.current_weapon.ammo_type != "":
				ammo_added = ammo_component.add_ammo(weapon_manager.current_weapon.ammo_type, amount)
			else:
				print("Current weapon '%s' has no ammo_type specified!" % weapon_manager.current_weapon.name)

	return ammo_added
