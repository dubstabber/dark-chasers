class_name Mansion2WeatherController
extends Node3D

const TIC_RATE := 35.0
const QUICK_FOLLOWUP_CHANCE := 50.0 / 256.0
const LIGHTNING_FIRST_DELAY_MIN_SECONDS := 5.0
const LIGHTNING_FIRST_DELAY_MAX_SECONDS := 20.0
const LIGHTNING_SHORT_DELAY_MIN_SECONDS := 2.0
const LIGHTNING_SHORT_DELAY_MAX_SECONDS := 9.0
const LIGHTNING_QUICK_DELAY_MIN_TICS := 16
const LIGHTNING_QUICK_DELAY_MAX_TICS := 31

@export var world_environment_path: NodePath = NodePath("../NavigationRegion3D/WorldEnvironment")
@export var start_enabled := true

@export_group("Scheduler")
@export var use_engine_lightning_schedule := true

@export_group("Flash")
@export_range(0.0, 2.0, 0.01) var flash_background_boost := 0.48
@export_range(0.0, 2.0, 0.01) var flash_ambient_boost := 0.4
@export_range(4, 24, 1) var flash_decay_steps := 12
@export_range(0.01, 0.2, 0.01) var flash_decay_step_seconds := 1.0 / TIC_RATE
@export_range(0.0, 1.0, 0.01) var indoor_flash_factor := 0.5
@export_range(0.0, 1.0, 0.01) var full_flash_multiplier := 1.0
@export_range(-24.0, 0.0, 0.1) var thunder_base_volume_db := -7.0
@export_range(0.0, 6.0, 0.1) var thunder_volume_random_db := 2.0
@export_range(0.8, 1.2, 0.01) var thunder_pitch_min := 0.95
@export_range(0.8, 1.2, 0.01) var thunder_pitch_max := 1.05

@export_group("Lightning (environment flash)")
@export var use_indoor_lightning_fallback_when_no_zone := true

@export_group("Indoor Detection")
@export var check_player_indoor_state := true
@export_range(10.0, 300.0, 1.0) var sky_check_height := 140.0
@export_flags_3d_physics var indoor_ray_collision_mask := 1

@export_group("Audio IDs")
@export var thunder_sound_ids: Array[StringName] = [&"thunder_1", &"thunder_2", &"thunder_3", &"thunder_4", &"thunder_5", &"thunder_6", &"thunder_7"]

var _rng := RandomNumberGenerator.new()
var _next_flash_in_seconds := 0.0
var _decay_ticks_left := 0
var _decay_tick_timer := 0.0
var _is_indoor := false

var _environment: Environment
var _base_background_energy := 0.0
var _base_ambient_energy := 0.0

var _player: Node3D
var _weather_active := false
var _current_flash_background_boost := 0.0
var _current_flash_ambient_boost := 0.0
var _flash_decay_total_steps := 0
var _current_lightning_tier: StringName = &""
var _weather_tick_accumulator := 0.0
var _weather_tick_counter := 0

func _ready() -> void:
	_rng.randomize()
	_bind_nodes()
	_cache_environment_state()
	if start_enabled:
		start_weather()

func _process(delta: float) -> void:
	if not _weather_active:
		return
	_accumulate_weather_ticks(delta)
	if check_player_indoor_state:
		_refresh_indoor_state()

	if _decay_ticks_left > 0:
		_decay_tick_timer -= delta
		if _decay_tick_timer <= 0.0:
			_decay_tick_timer += flash_decay_step_seconds
			_apply_decay_step()
		return

	_next_flash_in_seconds -= delta
	if _next_flash_in_seconds <= 0.0:
		_start_lightning_flash()

func _exit_tree() -> void:
	_restore_environment()
	_weather_active = false

func _bind_nodes() -> void:
	var world_environment := get_node_or_null(world_environment_path) as WorldEnvironment
	_environment = world_environment.environment if world_environment else null

	_player = _resolve_player_from_world_context()

func _cache_environment_state() -> void:
	if _environment == null:
		return
	_base_background_energy = _environment.background_energy_multiplier
	_base_ambient_energy = _environment.ambient_light_energy

func start_weather() -> void:
	if _weather_active:
		return
	_weather_active = true
	_weather_tick_accumulator = 0.0
	_weather_tick_counter = 0
	_schedule_next_flash(false)

func stop_weather() -> void:
	_weather_active = false
	_decay_ticks_left = 0
	_restore_environment()

func _refresh_indoor_state() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player_from_world_context()
		if _player == null:
			_is_indoor = false
			return

	var space_state := get_world_3d().direct_space_state
	var start := _player.global_position + Vector3(0.0, 0.5, 0.0)
	var target := start + Vector3.UP * sky_check_height
	var query := PhysicsRayQueryParameters3D.create(start, target, indoor_ray_collision_mask)
	query.exclude = [_player]
	var hit := space_state.intersect_ray(query)
	_is_indoor = not hit.is_empty()

func _start_lightning_flash() -> void:
	var flash_intensity := _rng.randf_range(0.0, 1.0)
	_current_flash_background_boost = lerpf(flash_background_boost * 0.7, flash_background_boost, flash_intensity)
	_current_flash_ambient_boost = lerpf(flash_ambient_boost * 0.7, flash_ambient_boost, flash_intensity)
	_decay_ticks_left = _rng.randi_range(8, 15)
	_flash_decay_total_steps = _decay_ticks_left
	var flash_multiplier := _get_active_lightning_multiplier()

	_apply_environment_flash(1.0, flash_multiplier)

	_play_thunder()
	_decay_tick_timer = flash_decay_step_seconds
	_schedule_next_flash(true)

func _apply_decay_step() -> void:
	_decay_ticks_left -= 1

	var t := float(_decay_ticks_left) / float(max(1, _flash_decay_total_steps))
	var flash_multiplier := _get_active_lightning_multiplier()
	_apply_environment_flash(t, flash_multiplier)

	if _decay_ticks_left <= 0:
		_restore_environment()

func _restore_environment() -> void:
	if _environment == null:
		return
	_current_lightning_tier = _evaluate_lightning_zone()["tier"] as StringName
	_restore_environment_levels()

func _restore_environment_levels() -> void:
	if _environment == null:
		return
	_environment.background_energy_multiplier = _base_background_energy
	_environment.ambient_light_energy = _base_ambient_energy

func _schedule_next_flash(previous_flash_happened: bool) -> void:
	if use_engine_lightning_schedule:
		_schedule_next_flash_engine(previous_flash_happened)
		return
	_schedule_next_flash_engine(previous_flash_happened)

func _schedule_next_flash_engine(previous_flash_happened: bool) -> void:
	if not previous_flash_happened:
		_next_flash_in_seconds = float(_rng.randi_range(int(LIGHTNING_FIRST_DELAY_MIN_SECONDS), int(LIGHTNING_FIRST_DELAY_MAX_SECONDS)))
		return

	if _rng.randi_range(0, 255) < int(QUICK_FOLLOWUP_CHANCE * 256.0):
		_next_flash_in_seconds = float(_rng.randi_range(LIGHTNING_QUICK_DELAY_MIN_TICS, LIGHTNING_QUICK_DELAY_MAX_TICS)) / TIC_RATE
		return

	if _rng.randi_range(0, 255) < 128 and (_weather_tick_counter & 32) == 0:
		_next_flash_in_seconds = float(_rng.randi_range(int(LIGHTNING_SHORT_DELAY_MIN_SECONDS), int(LIGHTNING_SHORT_DELAY_MAX_SECONDS)))
	else:
		_next_flash_in_seconds = float(_rng.randi_range(int(LIGHTNING_FIRST_DELAY_MIN_SECONDS), int(LIGHTNING_FIRST_DELAY_MAX_SECONDS)))

func _play_thunder() -> void:
	if thunder_sound_ids.is_empty():
		return

	var thunder_stream: AudioStream = null
	var available_ids := thunder_sound_ids.filter(func(id: StringName) -> bool: return id != &"")
	if not available_ids.is_empty():
		var sound_id: StringName = available_ids[_rng.randi_range(0, available_ids.size() - 1)]
		thunder_stream = _get_sound_from_catalog(sound_id)
	if thunder_stream == null:
		return

	_play_thunder_stream(thunder_stream)

func _play_thunder_stream(thunder_stream: AudioStream) -> void:
	var thunder_player := AudioStreamPlayer.new()
	thunder_player.stream = thunder_stream
	thunder_player.volume_db = thunder_base_volume_db + _rng.randf_range(0.0, thunder_volume_random_db)
	thunder_player.pitch_scale = _rng.randf_range(thunder_pitch_min, thunder_pitch_max)
	add_child(thunder_player)
	thunder_player.finished.connect(thunder_player.queue_free)
	if thunder_player.is_inside_tree():
		thunder_player.play()
	else:
		thunder_player.call_deferred("play")

func _accumulate_weather_ticks(delta: float) -> void:
	_weather_tick_accumulator += delta
	var tic_duration := 1.0 / TIC_RATE
	while _weather_tick_accumulator >= tic_duration:
		_weather_tick_accumulator -= tic_duration
		_weather_tick_counter += 1

func _get_sound_from_catalog(sound_id: StringName) -> AudioStream:
	if sound_id == &"":
		return null
	if not is_inside_tree():
		return null
	var services := get_node_or_null("/root/Services")
	if services == null:
		return null
	var catalog = services.get_sfx_catalog()
	if catalog == null:
		return null
	return catalog.get_sound(sound_id)

func _get_active_lightning_multiplier() -> float:
	var eval := _evaluate_lightning_zone()
	_current_lightning_tier = eval["tier"] as StringName
	return float(eval["multiplier"])

func _evaluate_lightning_zone() -> Dictionary:
	var fallback_tier: StringName = &"full_flash"
	var fallback_multiplier := full_flash_multiplier
	if use_indoor_lightning_fallback_when_no_zone and _is_indoor:
		fallback_tier = &"indoor_fallback"
		fallback_multiplier = indoor_flash_factor
	return {"has_zone": false, "multiplier": fallback_multiplier, "tier": fallback_tier}

func _resolve_player_from_world_context() -> Node3D:
	if not is_inside_tree():
		return null
	var services := get_node_or_null("/root/Services")
	if services == null:
		return null
	var world_context = services.world_context
	if world_context == null:
		return null
	var level: Node3D = world_context.get_level_node() as Node3D
	if level == null:
		return null
	var players_value: Variant = level.get("players")
	if not (players_value is Node):
		return null
	var players_node: Node = players_value as Node
	if players_node == null or players_node.get_child_count() == 0:
		return null
	var player: Node = players_node.get_child(0)
	if player is Node3D:
		return player as Node3D
	return null

func _apply_environment_flash(normalized_strength: float, flash_multiplier: float) -> void:
	if _environment == null:
		return
	var effective_background := _current_flash_background_boost * flash_multiplier * normalized_strength
	var effective_ambient := _current_flash_ambient_boost * flash_multiplier * normalized_strength
	_environment.background_energy_multiplier = _base_background_energy + effective_background
	_environment.ambient_light_energy = _base_ambient_energy + effective_ambient

func debug_get_environment_levels() -> Vector2:
	if _environment == null:
		return Vector2.ZERO
	return Vector2(_environment.background_energy_multiplier, _environment.ambient_light_energy)

func debug_set_seed(rng_seed: int) -> void:
	_rng.seed = rng_seed

func debug_set_indoor_state(indoor: bool) -> void:
	_is_indoor = indoor

func debug_force_flash_now() -> void:
	_next_flash_in_seconds = 0.0

func debug_get_next_flash_seconds() -> float:
	return _next_flash_in_seconds

func debug_get_decay_ticks_left() -> int:
	return _decay_ticks_left

func debug_get_current_lightning_tier() -> StringName:
	return _current_lightning_tier

func debug_evaluate_lightning_multiplier() -> float:
	return _get_active_lightning_multiplier()

func debug_evaluate_lightning_state() -> Dictionary:
	return _evaluate_lightning_zone()
