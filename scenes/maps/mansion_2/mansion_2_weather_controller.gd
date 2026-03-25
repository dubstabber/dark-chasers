class_name Mansion2WeatherController
extends Node3D

const TIC_RATE := 35.0
const QUICK_FOLLOWUP_CHANCE := 50.0 / 256.0

@export var weather_zones_root_path: NodePath = NodePath("WeatherZones")
@export var world_environment_path: NodePath = NodePath("../NavigationRegion3D/WorldEnvironment")
@export var rain_particles_path: NodePath = NodePath("RainParticles")
@export var rain_audio_path: NodePath = NodePath("RainAudio")
@export var thunder_audio_path: NodePath = NodePath("ThunderAudio")
@export var rain_zones_root_path: NodePath = NodePath("RainZones")
@export var start_enabled := true

@export_group("Scheduler")
@export_range(5.0, 40.0, 0.1) var long_flash_min_seconds := 5.0
@export_range(5.0, 45.0, 0.1) var long_flash_max_seconds := 20.0
@export_range(1.0, 15.0, 0.1) var short_flash_min_seconds := 2.0
@export_range(1.0, 20.0, 0.1) var short_flash_max_seconds := 9.0
@export_range(0.2, 2.0, 0.05) var quick_followup_min_seconds := 16.0 / TIC_RATE
@export_range(0.2, 2.5, 0.05) var quick_followup_max_seconds := 31.0 / TIC_RATE
@export_range(0.0, 1.0, 0.01) var quick_followup_chance := QUICK_FOLLOWUP_CHANCE
@export_range(0.0, 1.0, 0.01) var short_interval_chance := 0.28

@export_group("Flash")
@export_range(0.0, 2.0, 0.01) var flash_background_boost := 0.48
@export_range(0.0, 2.0, 0.01) var flash_ambient_boost := 0.4
@export_range(4, 24, 1) var flash_decay_steps := 12
@export_range(0.01, 0.2, 0.01) var flash_decay_step_seconds := 0.045
@export_range(0.0, 1.0, 0.01) var indoor_flash_factor := 0.5
@export_range(0.0, 1.0, 0.01) var full_flash_multiplier := 1.0
@export_range(-80.0, 0.0, 0.1) var rain_volume_db := -16.0
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

@export_group("Rain Zones")
@export var use_rain_visual_zones := true
@export var use_legacy_rain_visual_fallback_when_no_zone := true
@export var use_rain_audio_zones := true
@export var use_legacy_rain_audio_fallback_when_no_zone := true
@export var use_rain_zones := true
@export_range(2.0, 120.0, 0.5) var rain_zone_radius := 36.0
@export_range(1.0, 80.0, 0.5) var rain_zone_inner_radius := 16.0
@export_range(1.0, 60.0, 0.5) var rain_zone_particles_height_offset := 20.0
@export_range(-80.0, 0.0, 0.1) var rain_loud_volume_db := -12.0
@export_range(-80.0, 0.0, 0.1) var rain_low_volume_db := -24.0
@export_range(-80.0, 0.0, 0.1) var rain_none_volume_db := -60.0

@export_group("Audio IDs")
@export var rain_sound_id: StringName = &"rain_loop"
@export var rain_sound_inner_id: StringName = &"rain_loop_sharp"
@export var thunder_sound_ids: Array[StringName] = [&"thunder_1", &"thunder_2", &"thunder_3", &"thunder_4", &"thunder_5", &"thunder_6", &"thunder_7"]

var _rng := RandomNumberGenerator.new()
var _next_flash_in_seconds := 0.0
var _decay_ticks_left := 0
var _decay_tick_timer := 0.0
var _is_indoor := false

var _environment: Environment
var _base_background_energy := 0.0
var _base_ambient_energy := 0.0

var _weather_zones_root: Node3D
var _rain_particles: GPUParticles3D
var _rain_audio: AudioStreamPlayer
var _thunder_audio: AudioStreamPlayer
var _player: Node3D
var _rain_zones_root: Node3D
var _rain_visual_zones: Array[Node] = []
var _rain_audio_zones: Array[Node] = []
var _weather_active := false
var _current_flash_background_boost := 0.0
var _current_flash_ambient_boost := 0.0
var _flash_decay_total_steps := 0
var _active_rain_zone_center := Vector3.ZERO
var _current_rain_sound_id: StringName = &""
var _current_lightning_tier: StringName = &""
var _current_rain_visual_mode: StringName = &""
var _current_rain_audio_tier: StringName = &""

func _ready() -> void:
	_rng.randomize()
	_bind_nodes()
	_cache_environment_state()
	if start_enabled:
		start_weather()

func _process(delta: float) -> void:
	if not _weather_active:
		return
	if check_player_indoor_state:
		_refresh_indoor_state()
	_update_rain_visibility()

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

	_weather_zones_root = get_node_or_null(weather_zones_root_path) as Node3D
	_rain_particles = get_node_or_null(rain_particles_path) as GPUParticles3D
	_rain_audio = get_node_or_null(rain_audio_path) as AudioStreamPlayer
	_thunder_audio = get_node_or_null(thunder_audio_path) as AudioStreamPlayer
	_rain_zones_root = get_node_or_null(rain_zones_root_path) as Node3D
	_player = _resolve_player_from_world_context()
	_refresh_rain_visual_zone_cache()
	_refresh_rain_audio_zone_cache()

func _cache_environment_state() -> void:
	if _environment == null:
		return
	_base_background_energy = _environment.background_energy_multiplier
	_base_ambient_energy = _environment.ambient_light_energy

func _refresh_rain_visual_zone_cache() -> void:
	_rain_visual_zones.clear()
	if _weather_zones_root == null:
		return
	_collect_rain_visual_zones(_weather_zones_root)

func _collect_rain_visual_zones(node: Node) -> void:
	for child in node.get_children():
		if child is WeatherRainVisualZone:
			_rain_visual_zones.append(child as Node)
		if child is Node:
			_collect_rain_visual_zones(child as Node)

func _refresh_rain_audio_zone_cache() -> void:
	_rain_audio_zones.clear()
	if _weather_zones_root == null:
		return
	_collect_rain_audio_zones(_weather_zones_root)

func _collect_rain_audio_zones(node: Node) -> void:
	for child in node.get_children():
		if child is WeatherRainAudioZone:
			_rain_audio_zones.append(child as Node)
		if child is Node:
			_collect_rain_audio_zones(child as Node)

func _start_rain_ambience() -> void:
	if _rain_audio == null:
		return

	_rain_audio.autoplay = false
	_rain_audio.stream_paused = false
	var audio_eval: Dictionary = _evaluate_rain_audio_state()
	_apply_rain_audio_state(audio_eval)
	if _rain_audio.stream:
		_rain_audio.play()

func start_weather() -> void:
	if _weather_active:
		return
	_weather_active = true
	_refresh_rain_visual_zone_cache()
	_refresh_rain_audio_zone_cache()
	_start_rain_ambience()
	_update_rain_visibility()
	_schedule_next_flash(false)

func stop_weather() -> void:
	_weather_active = false
	_decay_ticks_left = 0
	_restore_environment()
	if _rain_particles:
		_rain_particles.emitting = false
	if _rain_audio:
		_rain_audio.stop()
	_current_rain_sound_id = &""
	_current_rain_visual_mode = &""
	_current_rain_audio_tier = &""

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

func _update_rain_visibility() -> void:
	var zone_eval := _evaluate_rain_zone()
	var visual_eval: Dictionary = _evaluate_rain_visual_state(zone_eval)
	_current_rain_visual_mode = visual_eval["mode"] as StringName
	var should_emit := bool(visual_eval["visible"])
	if _rain_particles:
		_rain_particles.emitting = should_emit

	if should_emit:
		if _rain_particles:
			var particle_center := visual_eval["center"] as Vector3
			_rain_particles.global_position = particle_center + Vector3(0.0, rain_zone_particles_height_offset, 0.0)

	if _rain_audio:
		var audio_eval: Dictionary = _evaluate_rain_audio_state(zone_eval)
		_apply_rain_audio_state(audio_eval)

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
	if previous_flash_happened and _rng.randf() < quick_followup_chance:
		_next_flash_in_seconds = _rng.randf_range(quick_followup_min_seconds, quick_followup_max_seconds)
		return

	if _rng.randf() < short_interval_chance:
		_next_flash_in_seconds = _rng.randf_range(short_flash_min_seconds, short_flash_max_seconds)
	else:
		_next_flash_in_seconds = _rng.randf_range(long_flash_min_seconds, long_flash_max_seconds)

func _play_thunder() -> void:
	if _thunder_audio == null:
		return
	if thunder_sound_ids.is_empty():
		return

	var thunder_stream: AudioStream = null
	var available_ids := thunder_sound_ids.filter(func(id: StringName) -> bool: return id != &"")
	if not available_ids.is_empty():
		var sound_id: StringName = available_ids[_rng.randi_range(0, available_ids.size() - 1)]
		thunder_stream = _get_sound_from_catalog(sound_id)
	if thunder_stream == null:
		return

	_thunder_audio.stream = thunder_stream
	_thunder_audio.volume_db = thunder_base_volume_db + _rng.randf_range(0.0, thunder_volume_random_db)
	_thunder_audio.pitch_scale = _rng.randf_range(thunder_pitch_min, thunder_pitch_max)
	_thunder_audio.play()

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

func _is_player_in_rain_zone() -> bool:
	return bool(_evaluate_rain_zone()["inside"])

func _evaluate_rain_visual_state(legacy_rain_zone_eval: Dictionary = {}) -> Dictionary:
	if use_rain_visual_zones:
		var listener_position_value: Variant = _get_listener_position()
		if listener_position_value != null:
			var listener_position: Vector3 = listener_position_value as Vector3
			var active_zone := _find_highest_priority_weather_zone(_rain_visual_zones, listener_position)
			if active_zone != null:
				return {
					"has_zone": true,
					"visible": bool(active_zone.call("shows_visible_rain")),
					"center": active_zone.call("get_particles_center"),
					"mode": active_zone.call("get_rain_visibility_mode_name"),
				}
		if not use_legacy_rain_visual_fallback_when_no_zone:
			var fallback_center := Vector3.ZERO
			if listener_position_value != null:
				fallback_center = listener_position_value as Vector3
			return {"has_zone": false, "visible": false, "center": fallback_center, "mode": &"hidden"}
	return _evaluate_legacy_rain_visual_state(legacy_rain_zone_eval)

func _evaluate_legacy_rain_visual_state(legacy_rain_zone_eval: Dictionary = {}) -> Dictionary:
	var zone_eval: Dictionary = legacy_rain_zone_eval if not legacy_rain_zone_eval.is_empty() else _evaluate_rain_zone()
	var should_show_visible_rain := not _is_indoor and bool(zone_eval["inside"])
	return {
		"has_zone": false,
		"visible": should_show_visible_rain,
		"center": _active_rain_zone_center,
		"mode": &"legacy_visible" if should_show_visible_rain else &"legacy_hidden",
	}

func _evaluate_rain_audio_state(legacy_rain_zone_eval: Dictionary = {}) -> Dictionary:
	if use_rain_audio_zones:
		var listener_position_value: Variant = _get_listener_position()
		if listener_position_value != null:
			var listener_position: Vector3 = listener_position_value as Vector3
			var active_zone := _find_highest_priority_weather_zone(_rain_audio_zones, listener_position)
			if active_zone != null:
				var tier_name := active_zone.call("get_rain_audio_tier_name") as StringName
				return _make_rain_audio_state_from_tier(tier_name, true)
		if not use_legacy_rain_audio_fallback_when_no_zone:
			return _make_rain_audio_state_from_tier(&"rain_none", false)
	return _evaluate_legacy_rain_audio_state(legacy_rain_zone_eval)

func _evaluate_legacy_rain_audio_state(legacy_rain_zone_eval: Dictionary = {}) -> Dictionary:
	var zone_eval: Dictionary = legacy_rain_zone_eval if not legacy_rain_zone_eval.is_empty() else _evaluate_rain_zone()
	var inside := bool(zone_eval["inside"])
	var inner := bool(zone_eval["inner"])
	var tier_name: StringName = &"rain_none"
	if inside:
		if inner:
			tier_name = &"rain_loud"
		elif _is_indoor:
			tier_name = &"rain_low"
		else:
			tier_name = &"rain_medium"
	return _make_rain_audio_state_from_tier(tier_name, false)

func _make_rain_audio_state_from_tier(tier_name: StringName, has_zone: bool) -> Dictionary:
	var sound_id: StringName = rain_sound_id
	var volume_db := rain_volume_db
	match tier_name:
		&"rain_loud":
			sound_id = rain_sound_inner_id if rain_sound_inner_id != &"" else rain_sound_id
			volume_db = rain_loud_volume_db
		&"rain_low":
			sound_id = rain_sound_id
			volume_db = rain_low_volume_db
		&"rain_none":
			sound_id = &""
			volume_db = rain_none_volume_db
		_:
			sound_id = rain_sound_id
			volume_db = rain_volume_db
	return {
		"has_zone": has_zone,
		"tier": tier_name,
		"sound_id": sound_id,
		"volume_db": volume_db,
	}

func _apply_rain_audio_state(audio_eval: Dictionary) -> void:
	if _rain_audio == null:
		return
	_current_rain_audio_tier = audio_eval["tier"] as StringName
	var sound_id := audio_eval["sound_id"] as StringName
	if sound_id != &"":
		_apply_rain_stream(sound_id)
	_rain_audio.volume_db = float(audio_eval["volume_db"])

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

func _find_highest_priority_weather_zone(zones: Array[Node], listener_position: Vector3) -> Node:
	var best_zone: Node = null
	var best_priority := -2147483648
	for zone in zones:
		if zone == null or not is_instance_valid(zone):
			continue
		if not bool(zone.call("contains_listener_position", listener_position)):
			continue
		var zone_priority: int = int(zone.call("get_zone_priority"))
		if best_zone == null or zone_priority > best_priority:
			best_zone = zone
			best_priority = zone_priority
	return best_zone

func _get_listener_position() -> Variant:
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player_from_world_context()
		if _player == null:
			return null
	return _get_node_world_position(_player)

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

func _get_node_world_position(node_3d: Node3D) -> Vector3:
	if node_3d.is_inside_tree():
		return node_3d.global_position

	var world_transform := node_3d.transform
	var current := node_3d.get_parent()
	while current is Node3D:
		world_transform = (current as Node3D).transform * world_transform
		current = current.get_parent()
	return world_transform.origin

func _evaluate_rain_zone() -> Dictionary:
	if not use_rain_zones:
		if _player and is_instance_valid(_player):
			_active_rain_zone_center = _get_node_world_position(_player)
		return {"inside": true, "inner": true}
	if _player == null or not is_instance_valid(_player):
		return {"inside": false, "inner": false}
	if _rain_zones_root == null:
		return {"inside": false, "inner": false}

	var player_pos := _get_node_world_position(_player)
	var nearest_distance := INF
	var nearest_center := Vector3.ZERO
	for child in _rain_zones_root.get_children():
		if child is Node3D:
			var zone := child as Node3D
			var distance := _get_node_world_position(zone).distance_to(player_pos)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_center = _get_node_world_position(zone)

	if nearest_distance == INF:
		return {"inside": false, "inner": false}

	_active_rain_zone_center = nearest_center
	var inside: bool = nearest_distance <= rain_zone_radius
	var inner_radius: float = min(rain_zone_inner_radius, rain_zone_radius)
	var inner: bool = nearest_distance <= inner_radius
	return {"inside": inside, "inner": inner}

func _apply_rain_stream(sound_id: StringName) -> void:
	if _rain_audio == null:
		return
	if sound_id == _current_rain_sound_id and _rain_audio.stream != null:
		return

	var rain_stream: AudioStream = _get_sound_from_catalog(sound_id)
	if rain_stream == null:
		return
	_rain_audio.stream = rain_stream
	_current_rain_sound_id = sound_id
	if _weather_active and not _rain_audio.playing:
		_rain_audio.play()

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

func debug_get_current_rain_audio_tier() -> StringName:
	return _current_rain_audio_tier

func debug_get_current_rain_visual_mode() -> StringName:
	return _current_rain_visual_mode

func debug_evaluate_rain_visual_state() -> Dictionary:
	return _evaluate_rain_visual_state()

func debug_evaluate_rain_audio_state() -> Dictionary:
	return _evaluate_rain_audio_state()
