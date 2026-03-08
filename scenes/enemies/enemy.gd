class_name Enemy extends CharacterBody3D

const EnemyNavigationHostControllerScript = preload("res://scenes/components/enemy/enemy_navigation_host_controller.gd")

enum NavigationMode {
	GODOT,
	DOOM,
}

@export var stats: EnemyStats ## Preferred: configure via resource for reusable enemy types
@export var navigation_mode: NavigationMode = NavigationMode.GODOT: set = set_navigation_mode
@export var requires_vertical_navigation := false
@export var current_room: String
@export var disappear_zones: Array[Area3D] ## Bridge: forwarded to EnemyDisappearZoneComponent at _ready()
@export var debug_prints := false

@export_group("Inline Overrides", "override_")
@export var override_is_wandering := false
@export var override_chase_player := true
@export var override_can_open_door := true
@export var override_speed: float = 7.0
@export var override_accel: float = 10.0
@export var override_death_message: String = ""
@export var override_jump_velocity: float = 12.0

var _blood_component: BloodEffectComponent
var _nav_component: EnemyNavigationComponent
var _ai_component: EnemyAIComponent
var _health_component: HealthComponent
var _wandering_component: EnemyWanderingComponent
var _room_pathing_component: RoomPathingComponent
var _transition_component: EnemyTransitionComponent
var _disappear_zone_component: EnemyDisappearZoneComponent
var _door_opener_component: EnemyDoorOpenerComponent
var _kill_zone_component: EnemyKillZoneComponent
var _motor_component: EnemyMotorComponent
var _brain_component: EnemyBrain
var _runtime_coordinator: EnemyRuntimeCoordinator = null
var _path_timing_controller := EnemyPathTimingController.new()
var _navigation_host_controller = EnemyNavigationHostControllerScript.new()
var _enemy_context: Node

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var players: Node3D
var current_target: CharacterBody3D
var waypoints: Array
var jump_speed := 0.0
var direction: Vector3
var map_transitions: Node3D
var ground_type: String
var moving_state := "idle"
@export var is_flying := false
var is_killed := false

# Stats accessors - prefer EnemyStats resource, fall back to inline overrides
var speed: float:
	get: return stats.speed if stats else override_speed
var accel: float:
	get: return stats.accel if stats else override_accel
var jump_velocity: float:
	get: return stats.jump_velocity if stats else override_jump_velocity
var chase_player: bool:
	get: return stats.chase_player if stats else override_chase_player
var can_open_door: bool:
	get: return stats.can_open_door if stats else override_can_open_door
var is_wandering: bool:
	get: return stats.is_wandering if stats else override_is_wandering
var death_message: String:
	get: return stats.death_message if stats else override_death_message

@onready var find_path_timer = $Timers/FindPathTimer
@onready var graphics = $Graphics
@onready var interaction_ray = $Interaction


func _ready():
	_setup_context()
	_setup_components()


func _setup_context() -> void:
	_enemy_context = Services.enemy_context
	if _enemy_context:
		players = _enemy_context.get_players_node()
		map_transitions = _enemy_context.get_transitions_node()
	# Note: EnemyContext handles group fallback internally; no need to duplicate here


func _setup_components() -> void:
	_blood_component = get_node_or_null("BloodEffectComponent")
	_room_pathing_component = get_node_or_null("RoomPathingComponent")
	_transition_component = get_node_or_null("EnemyTransitionComponent")
	_disappear_zone_component = get_node_or_null("EnemyDisappearZoneComponent")
	_door_opener_component = get_node_or_null("EnemyDoorOpenerComponent")
	_brain_component = get_node_or_null("EnemyBrain")
	if _door_opener_component:
		_door_opener_component.enabled = can_open_door
	_setup_motor_component()
	_setup_kill_zone_component()
	_setup_navigation_component()
	_setup_ai_component()
	_setup_health_component()
	_setup_wandering_component()
	_setup_transition_component()
	_setup_disappear_zone_component()
	_setup_runtime_coordinator()


func _setup_transition_component() -> void:
	if _transition_component:
			_transition_component.setup(_nav_component, _motor_component, _disappear_zone_component, _room_pathing_component)


func _setup_disappear_zone_component() -> void:
	if _disappear_zone_component:
		_sanitize_disappear_zones_export()
		# Keep designer-facing export list as configuration, but make the component authoritative at runtime.
		_disappear_zone_component.sync_with_enemy_zones(disappear_zones)


func _setup_runtime_coordinator() -> void:
	_runtime_coordinator = get_node_or_null("EnemyRuntimeCoordinator") as EnemyRuntimeCoordinator
	if not _runtime_coordinator:
		_runtime_coordinator = EnemyRuntimeCoordinator.new()
		_runtime_coordinator.name = "EnemyRuntimeCoordinator"
		add_child(_runtime_coordinator)

	_runtime_coordinator.setup(
		self,
		_ai_component,
		_motor_component,
		_nav_component,
		_wandering_component,
		_disappear_zone_component,
		_transition_component,
		_path_timing_controller,
		find_path_timer,
		is_flying,
		debug_prints
	)


func set_navigation_mode(value: NavigationMode) -> void:
	if navigation_mode == value:
		return
	navigation_mode = value
	_refresh_navigation_mode_runtime()


func _refresh_navigation_mode_runtime() -> void:
	if not is_node_ready():
		return

	_setup_navigation_component()
	_setup_transition_component()
	_setup_runtime_coordinator()

	if current_target or not waypoints.is_empty():
		makepath()


func _sanitize_disappear_zones_export() -> void:
	var unique: Array[Area3D] = []
	for z in disappear_zones:
		if is_instance_valid(z) and not unique.has(z):
			unique.append(z)
	disappear_zones = unique


func _setup_motor_component() -> void:
	_motor_component = get_node_or_null("EnemyMotorComponent")
	assert(_motor_component != null, "Enemy '%s' requires an EnemyMotorComponent child node" % name)
	_motor_component.speed = speed
	_motor_component.accel = accel
	_motor_component.is_flying = is_flying


func _setup_kill_zone_component() -> void:
	_kill_zone_component = get_node_or_null("KillZone")
	if _kill_zone_component:
		_kill_zone_component.death_message = death_message
		_kill_zone_component.player_killed.connect(_on_kill_zone_player_killed)


func _on_kill_zone_player_killed(_player: Node3D) -> void:
	current_target = null
	velocity = Vector3.ZERO


func _setup_navigation_component() -> void:
	_nav_component = _navigation_host_controller.refresh_navigation_component(
		name,
		_nav_component,
		_navigation_host_controller.get_navigation_components(self),
		_get_navigation_mode_id(),
		is_flying,
		requires_vertical_navigation,
		Callable(self, "_on_navigation_target_reached"),
		Callable(self, "_on_navigation_link_reached"),
		Callable(self, "_on_navigation_waypoint_reached"),
		Callable(self, "_push_navigation_warning")
	)


func _get_navigation_mode_id() -> StringName:
	match navigation_mode:
		NavigationMode.DOOM:
			return &"doom"
		_:
			return &"godot"


func _push_navigation_warning(message: String) -> void:
	push_warning(message)


func _setup_ai_component() -> void:
	_ai_component = get_node_or_null("EnemyAIComponent")
	if _ai_component:
		_ai_component.chase_player = chase_player
		_ai_component.target_acquired.connect(_on_target_acquired)
		_ai_component.target_died.connect(_on_target_died)


func _setup_health_component() -> void:
	_health_component = get_node_or_null("HealthComponent")
	if _health_component:
		_health_component.died.connect(_on_died)


func _setup_wandering_component() -> void:
	_wandering_component = get_node_or_null("EnemyWanderingComponent")
	if _wandering_component:
		_wandering_component.set_debug(debug_prints)
		_wandering_component.direction_changed.connect(_on_wandering_direction_changed)
		if is_wandering:
			_wandering_component.start_wandering()


func _on_wandering_direction_changed(new_dir: Vector3) -> void:
	direction = new_dir


func _on_died() -> void:
	is_killed = true
	velocity = Vector3.ZERO


func has_health_component() -> bool:
	return _health_component != null


func get_health_component() -> HealthComponent:
	return _health_component


func _physics_process(delta):
	if _brain_component and _brain_component.is_ability_active():
		return

	if _runtime_coordinator:
		_runtime_coordinator.process_physics(delta)


func _on_target_acquired(target: Node3D) -> void:
	if _runtime_coordinator:
		_runtime_coordinator.on_target_acquired(target)


func _on_target_died() -> void:
	if _runtime_coordinator:
		_runtime_coordinator.on_target_died()


func makepath() -> void:
	if _transition_component:
		_transition_component.makepath()
		return

	if not _nav_component:
		return

	if current_target:
		_nav_component.set_target(current_target.global_position)
	elif not waypoints.is_empty():
		_nav_component.set_target(waypoints[0])


func add_disappear_zone(area: Area3D) -> void:
	if not is_instance_valid(area):
		return
	# Keep the exported list mirrored for inspector/debuggability.
	if not disappear_zones.has(area):
		disappear_zones.append(area)
	if _disappear_zone_component:
		_disappear_zone_component.add_zone(area)


func restart_pathfinding(delay: float = 0.1) -> void:
	find_path_timer.wait_time = delay
	find_path_timer.start()


func _on_find_path_timer_timeout():
	if _runtime_coordinator:
		_runtime_coordinator.on_find_path_timer_timeout()


func _on_interaction_timer_timeout():
	if not _door_opener_component or not _should_attempt_door_interaction():
		return

	if not _door_opener_component.check_and_open_door() and is_wandering:
		if _door_opener_component.is_facing_door():
			direction = Vector3(-direction.x, 0, -direction.z)


func _should_attempt_door_interaction() -> bool:
	if current_target != null:
		return true
	if not waypoints.is_empty():
		return true
	if _wandering_component and _wandering_component.is_wandering():
		return true
	return false


func _on_navigation_target_reached() -> void:
	if _runtime_coordinator:
		_runtime_coordinator.on_navigation_target_reached()


func _on_navigation_link_reached(details: Dictionary) -> void:
	if _nav_component:
		_nav_component.handle_link_reached(details, _motor_component, gravity, jump_velocity)


func _on_navigation_waypoint_reached(details: Dictionary) -> void:
	if _nav_component:
		_nav_component.handle_waypoint_reached(details, _motor_component)


func take_damage(amount: int) -> void:
	take_damage_at_position(amount, global_position + Vector3(0, 1.0, 0))


func take_damage_at_position(amount: int, hit_pos: Vector3) -> void:
	if _health_component:
		_health_component.take_damage(amount)
	if _blood_component:
		_blood_component.spawn_splatter(hit_pos, Vector3.ZERO)


func take_damage_with_direction(amount: int, hit_pos: Vector3, shot_direction: Vector3) -> void:
	if _health_component:
		_health_component.take_damage(amount)
	if _blood_component:
		_blood_component.spawn_splatter(hit_pos, shot_direction)
		_blood_component.trace_to_walls(amount, hit_pos, shot_direction)


func get_target_position() -> Vector3:
	if current_target:
		return current_target.global_position
	return global_position


func set_navigation_enabled(enabled: bool) -> void:
	if _nav_component:
		_nav_component.set_navigation_active(enabled)


func get_navigation_enabled() -> bool:
	if _nav_component:
		return _nav_component.is_navigation_active()
	return false
