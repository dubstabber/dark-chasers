class_name Player extends CharacterBody3D


@warning_ignore("UNUSED_SIGNAL")
signal weapon_added(weapon: WeaponResource)

var current_room: String
var gravity: int = ProjectSettings.get_setting("physics/3d/default_gravity")
var last_velocity: Vector3 = Vector3.ZERO

var blocked_movement := false

# Death message tracking (used by death component for HUD)
var _died_from_fall_damage := false
var _death_message: String = ""

var hud: CanvasLayer: set = set_hud

@onready var camera_3d = $nek/head/eyes/Camera3D # PlayerCamera extends Camera3D
@onready var animation_player = $nek/head/eyes/AnimationPlayer
@onready var sprite_animation_player = $SpriteAnimationPlayer
@onready var footstep_surface_detector = $FootstepSurfaceDetector
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
@onready var input_component: PlayerInputComponent = $PlayerInputComponent
@onready var damage_effects_component: DamageEffectsComponent = $DamageEffectsComponent


func _ready():
	if not hud:
		_auto_discover_hud()

	if health_component:
		health_component.death_sound = Services.get_sfx_catalog().get_sound(&"kill_player")

	if armor_component:
		armor_component.max_armor = 100
		armor_component.current_armor = 0

	_setup_modular_components()


func _physics_process(delta: float) -> void:
	# Player owns the physics step (gravity, move_and_slide, last_velocity).
	# Input gathering and movement math are delegated to components.
	if not movement_component:
		return

	# Apply gravity
	if not is_on_floor() and not movement_component.clip_mode:
		velocity.y -= gravity * delta

	# Let input component gather input and feed movement component
	if input_component:
		input_component.process_physics_input(delta)

	# Record velocity before move for landing detection etc.
	last_velocity = velocity

	# Execute the actual physics move
	move_and_slide()


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
	
	if input_component:
		input_component.respawn_requested.connect(respawn)


func _on_footstep_triggered() -> void:
	if footstep_surface_detector:
		footstep_surface_detector.play_footstep()


func _on_fatal_fall() -> void:
	_died_from_fall_damage = true


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


func set_hud(new_hud: CanvasLayer):
	"""Setter for the HUD reference

	Connects HUD directly to player components for automatic updates.
	"""
	hud = new_hud
	# HUD is a known scene with connect_to_player method
	if hud:
		hud.connect_to_player(self)


func get_hud_health_component() -> HealthComponent:
	return health_component


func get_hud_armor_component() -> ArmorComponent:
	return armor_component


func get_hud_ammo_component() -> PlayerAmmoComponent:
	return ammo_component


func get_hud_weapon_manager() -> WeaponManager:
	return weapon_manager


func get_hud_damage_effects_component() -> DamageEffectsComponent:
	return damage_effects_component


func get_hud_camera() -> Camera3D:
	return camera_3d


func _auto_discover_hud() -> void:
	"""Auto-discover HUD via group if not explicitly set
	
	This provides a fallback mechanism for flexible level design. If the level
	doesn't explicitly set player.hud, the player can find the HUD by looking
	for nodes in the "hud" group.
	
	Note: This is called in _ready() only if hud is not already set.
	Prefer explicit wiring via Level.setup_player() instead.
	"""
	if not OS.is_debug_build():
		push_warning("Player: HUD not set explicitly. Use Level.setup_player() for explicit wiring.")
		return
	
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		push_warning("Player: Auto-discovered HUD via group fallback. Prefer explicit wiring.")
		set_hud(hud_nodes[0])


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


func get_aim_point() -> Vector3:
	"""Get the position enemies should aim at (camera position)
	
	This provides a standardized interface for enemy targeting,
	decoupling enemies from knowing about the camera_3d property.
	
	Returns:
		Vector3: Global position of the player's viewpoint
	"""
	if camera_3d:
		return camera_3d.global_position
	return global_position + Vector3(0, 1.6, 0)


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
## These methods delegate to the WeaponManager for ammo operations

func add_ammo(amount: int, all_weapons: bool = false) -> bool:
	"""Add ammo to weapons - delegates to WeaponManager"""
	if weapon_manager:
		return weapon_manager.add_ammo_to_weapons(amount, all_weapons)
	return false
