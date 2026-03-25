extends SceneTree

const RAIN_VISUAL_MODE_VISIBLE := 0
const RAIN_VISUAL_MODE_HIDDEN := 1
const RAIN_AUDIO_TIER_LOUD := 0
const RAIN_AUDIO_TIER_MEDIUM := 1
const RAIN_AUDIO_TIER_LOW := 2
const RAIN_AUDIO_TIER_NONE := 3


func _init() -> void:
	print("=== MAP02 WEATHER CONTROLLER TESTS ===")
	_test_scheduler_ranges()
	_test_flash_lifecycle_restores_environment()
	_test_indoor_lightning_fallback_attenuates_environment_flash()
	_test_environment_flash_ignores_indoor_state()
	_test_map02_scene_weather_authoring()
	_test_rain_visual_zone_priority_override()
	_test_rain_visual_zone_can_differ_from_audio_zone()
	_test_rain_visual_legacy_fallback_toggle()
	_test_rain_audio_zone_priority_override()
	_test_rain_audio_zone_none_suppresses_audio()
	_test_rain_audio_zone_low_is_quieter_than_medium()
	print("=== MAP02 WEATHER CONTROLLER TESTS COMPLETED ===")
	quit(0)


func _build_controller(start_enabled := false) -> Node3D:
	var environment := Environment.new()
	environment.background_energy_multiplier = 0.51
	environment.ambient_light_energy = 0.13

	var controller_script := load("res://scenes/maps/mansion_2/mansion_2_weather_controller.gd") as GDScript
	var controller := Node3D.new()
	controller.name = "Controller"
	controller.set_script(controller_script)
	controller.set("start_enabled", start_enabled)
	controller.set("check_player_indoor_state", false)
	controller.set("use_rain_zones", false)
	controller.set("rain_sound_id", &"rain_loop")
	controller.set("rain_sound_inner_id", &"rain_loop_sharp")
	controller.set("thunder_sound_ids", Array([], TYPE_STRING_NAME, "", null))
	controller.set("_environment", environment)
	controller.set("_rain_particles", null)
	controller.set("_rain_audio", null)
	controller.set("_thunder_audio", null)
	controller.set("_base_background_energy", environment.background_energy_multiplier)
	controller.set("_base_ambient_energy", environment.ambient_light_energy)
	return controller


func _prime_controller(controller: Node3D) -> void:
	if controller == null:
		push_error("Controller should be valid")


func _attach_player(controller: Node3D, position: Vector3) -> Node3D:
	var player := Node3D.new()
	player.name = "Player"
	player.position = position
	controller.add_child(player)
	controller.set("_player", player)
	return player


func _ensure_weather_zones_root(controller: Node3D) -> Node3D:
	var existing_root := controller.get_node_or_null("WeatherZones") as Node3D
	if existing_root:
		controller.set("_weather_zones_root", existing_root)
		return existing_root
	var zone_root := Node3D.new()
	zone_root.name = "WeatherZones"
	controller.add_child(zone_root)
	controller.set("_weather_zones_root", zone_root)
	return zone_root


func _add_box_collision_shape(zone: Area3D, local_position: Vector3, zone_size: Vector3, collision_name := "CollisionShape3D") -> CollisionShape3D:
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = collision_name
	collision_shape.position = local_position
	var box_shape := BoxShape3D.new()
	box_shape.size = zone_size
	collision_shape.shape = box_shape
	zone.add_child(collision_shape)
	return collision_shape


func _make_rain_audio_zone(zone_priority: int, rain_audio_tier: int, zone_position: Vector3, zone_size: Vector3) -> Node:
	var zone_script := load("res://scenes/maps/mansion_2/weather_rain_audio_zone.gd") as GDScript
	var zone := Area3D.new()
	zone.name = "WeatherRainAudioZone"
	zone.set_script(zone_script)
	zone.priority = zone_priority
	zone.set("rain_audio_tier", rain_audio_tier)
	zone.position = zone_position
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = zone_size
	collision_shape.shape = box_shape
	zone.add_child(collision_shape)
	return zone


func _make_rain_visual_zone(zone_priority: int, rain_visibility_mode: int, zone_position: Vector3, zone_size: Vector3) -> Node:
	var zone_script := load("res://scenes/maps/mansion_2/weather_rain_visual_zone.gd") as GDScript
	var zone := Area3D.new()
	zone.name = "WeatherRainVisualZone"
	zone.set_script(zone_script)
	zone.priority = zone_priority
	zone.set("rain_visibility_mode", rain_visibility_mode)
	zone.position = zone_position
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = zone_size
	collision_shape.shape = box_shape
	zone.add_child(collision_shape)
	return zone


func _attach_rain_visual_zones(controller: Node3D, zones: Array[Node]) -> Node3D:
	var zone_root := _ensure_weather_zones_root(controller)
	var rain_visual_root := zone_root.get_node_or_null("RainVisualZones") as Node3D
	if rain_visual_root == null:
		rain_visual_root = Node3D.new()
		rain_visual_root.name = "RainVisualZones"
		zone_root.add_child(rain_visual_root)
	for zone in zones:
		rain_visual_root.add_child(zone)
	controller.call("_refresh_rain_visual_zone_cache")
	return rain_visual_root


func _attach_rain_audio_zones(controller: Node3D, zones: Array[Node]) -> Node3D:
	var zone_root := _ensure_weather_zones_root(controller)
	var rain_audio_root := zone_root.get_node_or_null("RainAudioZones") as Node3D
	if rain_audio_root == null:
		rain_audio_root = Node3D.new()
		rain_audio_root.name = "RainAudioZones"
		zone_root.add_child(rain_audio_root)
	for zone in zones:
		rain_audio_root.add_child(zone)
	controller.call("_refresh_rain_audio_zone_cache")
	return rain_audio_root


func _test_scheduler_ranges() -> void:
	var controller := _build_controller(false)
	_prime_controller(controller)
	controller.call("debug_set_seed", 1337)
	controller.call("start_weather")

	for _i in range(50):
		controller.call("_schedule_next_flash", false)
		var next_flash := float(controller.call("debug_get_next_flash_seconds"))
		assert(next_flash >= 2.0 and next_flash <= 20.0, "Normal next flash must be in [2.0, 20.0] seconds")

	for _j in range(50):
		controller.call("_schedule_next_flash", true)
		var next_after_flash := float(controller.call("debug_get_next_flash_seconds"))
		assert(next_after_flash >= (16.0 / 35.0) and next_after_flash <= 20.0, "Post-flash interval must match quick/short/long modeled bounds")

	controller.free()
	print("✓ Scheduler interval bounds match modeled MAP02 behavior")


func _test_flash_lifecycle_restores_environment() -> void:
	var controller := _build_controller(false)
	_prime_controller(controller)
	controller.call("debug_set_seed", 2026)
	controller.call("start_weather")
	var before := controller.call("debug_get_environment_levels") as Vector2

	controller.call("debug_set_indoor_state", false)
	controller.call("debug_force_flash_now")
	controller.call("_process", 0.016)

	var flashed := controller.call("debug_get_environment_levels") as Vector2
	assert(flashed.x > before.x and flashed.y > before.y, "Flash must raise environment levels")
	assert(int(controller.call("debug_get_decay_ticks_left")) > 0, "Flash should start a decay sequence")

	for _k in range(20):
		controller.call("_process", 0.06)

	var restored := controller.call("debug_get_environment_levels") as Vector2
	assert(is_equal_approx(restored.x, before.x), "Background energy should restore after decay")
	assert(is_equal_approx(restored.y, before.y), "Ambient energy should restore after decay")

	controller.free()
	print("✓ Flash lifecycle boosts and restores environment")


func _test_indoor_lightning_fallback_attenuates_environment_flash() -> void:
	var outdoor_controller := _build_controller(false)
	_prime_controller(outdoor_controller)
	outdoor_controller.call("debug_set_seed", 7)
	outdoor_controller.call("start_weather")
	var outdoor_before := outdoor_controller.call("debug_get_environment_levels") as Vector2
	outdoor_controller.call("debug_set_indoor_state", false)
	outdoor_controller.call("debug_force_flash_now")
	outdoor_controller.call("_process", 0.016)
	var outdoor_after := outdoor_controller.call("debug_get_environment_levels") as Vector2
	var outdoor_boost := outdoor_after.x - outdoor_before.x
	assert(outdoor_controller.call("debug_get_current_lightning_tier") == &"full_flash", "Outdoor lightning should use the full flash tier")
	outdoor_controller.free()

	var indoor_controller := _build_controller(false)
	_prime_controller(indoor_controller)
	indoor_controller.call("debug_set_seed", 7)
	indoor_controller.call("start_weather")
	var indoor_before := indoor_controller.call("debug_get_environment_levels") as Vector2
	indoor_controller.call("debug_set_indoor_state", true)
	indoor_controller.call("debug_force_flash_now")
	indoor_controller.call("_process", 0.016)
	var indoor_after := indoor_controller.call("debug_get_environment_levels") as Vector2
	var indoor_boost := indoor_after.x - indoor_before.x
	assert(indoor_controller.call("debug_get_current_lightning_tier") == &"indoor_fallback", "Indoor lightning should use the fallback tier when enabled")
	indoor_controller.free()

	assert(outdoor_boost > indoor_boost, "Indoor fallback should attenuate the environment flash")
	assert(indoor_boost > 0.0, "Indoor fallback should still allow a reduced lightning flash")
	print("✓ Indoor lightning fallback attenuates environment flash when enabled")


func _test_environment_flash_ignores_indoor_state() -> void:
	var outdoor_controller := _build_controller(false)
	_prime_controller(outdoor_controller)
	outdoor_controller.set("use_indoor_lightning_fallback_when_no_zone", false)
	outdoor_controller.call("debug_set_seed", 42)
	outdoor_controller.call("start_weather")
	var outdoor_before := outdoor_controller.call("debug_get_environment_levels") as Vector2
	outdoor_controller.call("debug_set_indoor_state", false)
	outdoor_controller.call("debug_force_flash_now")
	outdoor_controller.call("_process", 0.016)
	var outdoor_after := outdoor_controller.call("debug_get_environment_levels") as Vector2
	var outdoor_boost := outdoor_after.x - outdoor_before.x
	outdoor_controller.free()

	var indoor_controller := _build_controller(false)
	_prime_controller(indoor_controller)
	indoor_controller.set("use_indoor_lightning_fallback_when_no_zone", false)
	indoor_controller.call("debug_set_seed", 42)
	indoor_controller.call("start_weather")
	var indoor_before := indoor_controller.call("debug_get_environment_levels") as Vector2
	indoor_controller.call("debug_set_indoor_state", true)
	indoor_controller.call("debug_force_flash_now")
	indoor_controller.call("_process", 0.016)
	var indoor_after := indoor_controller.call("debug_get_environment_levels") as Vector2
	var indoor_boost := indoor_after.x - indoor_before.x
	indoor_controller.free()
	assert(is_equal_approx(indoor_boost, outdoor_boost), "Environment flash should be the same regardless of indoor state")
	assert(outdoor_boost > 0.0, "Environment flash should always boost when no authored zones exist")
	print("✓ Environment flash fires at full strength regardless of indoor state")


func _test_map02_scene_weather_authoring() -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/maps/mansion_2/mansion_2.tscn")
	assert(not scene_text.is_empty(), "MAP02 scene text should be readable for weather authoring verification")
	assert(scene_text.contains("[node name=\"LightningZones\" type=\"Node3D\" parent=\"WeatherController/WeatherZones\"]"), "MAP02 scene should include the authored lightning zone root")
	assert(scene_text.contains("[node name=\"RainAudioZones\" type=\"Node3D\" parent=\"WeatherController/WeatherZones\"]"), "MAP02 scene should include the authored rain-audio zone root")
	assert(scene_text.contains("[node name=\"RainVisualZones\" type=\"Node3D\" parent=\"WeatherController/WeatherZones\"]"), "MAP02 scene should include the authored rain-visual zone root")
	assert(scene_text.count('type="ReflectionProbe" parent="WeatherController/WeatherZones/LightningZones"') == 2, "MAP02 scene should author two ReflectionProbes under LightningZones")
	assert(scene_text.count('type="Area3D" parent="WeatherController/WeatherZones/LightningZones"') == 0, "MAP02 scene should no longer use authored lightning-zone Area3D volumes")
	assert(scene_text.count('type="Area3D" parent="WeatherController/WeatherZones/RainAudioZones"') == 7, "MAP02 scene should author the expected rain-audio zone set")
	assert(scene_text.count('type="Area3D" parent="WeatherController/WeatherZones/RainVisualZones"') == 7, "MAP02 scene should author the expected rain-visual zone set")
	assert(scene_text.contains("[node name=\"ReflectionProbe\" type=\"ReflectionProbe\" parent=\"WeatherController/WeatherZones/LightningZones\"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 86.37787, 7.6006327, -5.5837784)"), "MAP02 scene should keep the main hall lightning ReflectionProbe")
	assert(scene_text.contains("[node name=\"ReflectionProbe2\" type=\"ReflectionProbe\" parent=\"WeatherController/WeatherZones/LightningZones\"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 87.547226, 7.0142565, 5.460824)\nblend_distance = 11.0"), "MAP02 scene should keep the partial lightning ReflectionProbe with tuned blend distance")
	assert(scene_text.contains("[node name=\"Zone_BasementHoleLow\" type=\"Area3D\" parent=\"WeatherController/WeatherZones/RainAudioZones\"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 51.15332, 6.92608, -1.7114701)\ncollision_layer = 0\ncollision_mask = 0\npriority = 5\nscript = ExtResource(\"165_rain_audio_zone\")\nrain_audio_tier = 2"), "MAP02 scene should author a low-rain basement-hole audio override")
	assert(scene_text.contains("[node name=\"Zone_BasementHoleVisible\" type=\"Area3D\" parent=\"WeatherController/WeatherZones/RainVisualZones\"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 51.15332, 6.92608, -1.7114701)\ncollision_layer = 0\ncollision_mask = 0\npriority = 5\nscript = ExtResource(\"166_rain_visual_zone\")"), "MAP02 scene should author a visible-rain basement-hole override")
	assert(scene_text.contains("[node name=\"Zone_MainHallHidden\" type=\"Area3D\" parent=\"WeatherController/WeatherZones/RainVisualZones\"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 64, 6, -14)\ncollision_layer = 0\ncollision_mask = 0\npriority = 2\nscript = ExtResource(\"166_rain_visual_zone\")\nrain_visibility_mode = 1"), "MAP02 scene should author a sheltered main-hall visible-rain zone")
	print("✓ MAP02 scene includes ReflectionProbe lightning masking plus authored rain-audio and rain-visual coverage")


func _test_rain_visual_zone_priority_override() -> void:
	var controller := _build_controller(false)
	_prime_controller(controller)
	_attach_player(controller, Vector3.ZERO)
	_attach_rain_visual_zones(
		controller,
		[
			_make_rain_visual_zone(1, RAIN_VISUAL_MODE_VISIBLE, Vector3.ZERO, Vector3(12.0, 6.0, 12.0)),
			_make_rain_visual_zone(5, RAIN_VISUAL_MODE_HIDDEN, Vector3.ZERO, Vector3(2.0, 2.0, 2.0)),
		]
	)
	var eval := controller.call("debug_evaluate_rain_visual_state") as Dictionary
	assert(bool(eval["has_zone"]), "Visible-rain evaluation should report the authored active zone")
	assert(not bool(eval["visible"]), "Higher-priority hidden visual zones should suppress visible rain")
	assert(eval["mode"] == &"hidden", "Higher-priority hidden visual zones should set the active visual mode")
	controller.free()
	print("✓ Rain-visual zones respect highest-priority visibility overrides")


func _test_rain_visual_zone_can_differ_from_audio_zone() -> void:
	var controller := _build_controller(false)
	_prime_controller(controller)
	_attach_player(controller, Vector3.ZERO)
	_attach_rain_visual_zones(
		controller,
		[
			_make_rain_visual_zone(1, RAIN_VISUAL_MODE_VISIBLE, Vector3.ZERO, Vector3(10.0, 6.0, 10.0)),
		]
	)
	_attach_rain_audio_zones(
		controller,
		[
			_make_rain_audio_zone(1, RAIN_AUDIO_TIER_NONE, Vector3.ZERO, Vector3(10.0, 6.0, 10.0)),
		]
	)
	var visual_eval := controller.call("debug_evaluate_rain_visual_state") as Dictionary
	var audio_eval := controller.call("debug_evaluate_rain_audio_state") as Dictionary
	assert(bool(visual_eval["visible"]), "Visible-rain zones should be able to enable particles")
	assert(audio_eval["tier"] == &"rain_none", "Rain-audio zones should still be able to mute audible rain")
	controller.free()
	print("✓ Visible rain can differ from audible rain when authored separately")


func _test_rain_visual_legacy_fallback_toggle() -> void:
	var fallback_controller := _build_controller(false)
	_prime_controller(fallback_controller)
	_attach_player(fallback_controller, Vector3.ZERO)
	var fallback_eval := fallback_controller.call("debug_evaluate_rain_visual_state") as Dictionary
	assert(not bool(fallback_eval["has_zone"]), "Legacy fallback should not claim an authored visual zone")
	assert(bool(fallback_eval["visible"]), "Visible-rain legacy fallback should preserve current outdoor particle behavior")
	fallback_controller.free()

	var no_fallback_controller := _build_controller(false)
	_prime_controller(no_fallback_controller)
	_attach_player(no_fallback_controller, Vector3.ZERO)
	no_fallback_controller.set("use_legacy_rain_visual_fallback_when_no_zone", false)
	var no_fallback_eval := no_fallback_controller.call("debug_evaluate_rain_visual_state") as Dictionary
	assert(not bool(no_fallback_eval["visible"]), "Visible-rain fallback should be suppressible when no authored visual zone applies")
	assert(no_fallback_eval["mode"] == &"hidden", "Disabled visible-rain fallback should report a hidden state")
	no_fallback_controller.free()
	print("✓ Visible-rain legacy fallback can be preserved or disabled")


func _test_rain_audio_zone_priority_override() -> void:
	var controller := _build_controller(false)
	_prime_controller(controller)
	_attach_player(controller, Vector3.ZERO)
	_attach_rain_audio_zones(
		controller,
		[
			_make_rain_audio_zone(1, RAIN_AUDIO_TIER_NONE, Vector3.ZERO, Vector3(12.0, 6.0, 12.0)),
			_make_rain_audio_zone(5, RAIN_AUDIO_TIER_LOUD, Vector3.ZERO, Vector3(2.0, 2.0, 2.0)),
		]
	)
	var eval := controller.call("debug_evaluate_rain_audio_state") as Dictionary
	assert(bool(eval["has_zone"]), "Rain-audio evaluation should report the authored active zone")
	assert(eval["tier"] == &"rain_loud", "Higher-priority local rain-audio override should win")
	assert(eval["sound_id"] == &"rain_loop_sharp", "Loud rain-audio tier should choose the sharp rain loop")
	controller.free()
	print("✓ Rain-audio zones respect highest-priority local overrides")


func _test_rain_audio_zone_none_suppresses_audio() -> void:
	var controller := _build_controller(false)
	_prime_controller(controller)
	_attach_player(controller, Vector3.ZERO)
	_attach_rain_audio_zones(
		controller,
		[
			_make_rain_audio_zone(1, RAIN_AUDIO_TIER_NONE, Vector3.ZERO, Vector3(10.0, 6.0, 10.0)),
		]
	)
	var eval := controller.call("debug_evaluate_rain_audio_state") as Dictionary
	assert(eval["tier"] == &"rain_none", "Rain-none zones should suppress rain audio")
	assert(eval["sound_id"] == &"", "Rain-none zones should not request an audible rain loop")
	assert(is_equal_approx(float(eval["volume_db"]), -60.0), "Rain-none zones should map to the configured muted volume")
	controller.free()
	print("✓ Rain-none zones suppress authored rain ambience")


func _test_rain_audio_zone_low_is_quieter_than_medium() -> void:
	var medium_controller := _build_controller(false)
	_prime_controller(medium_controller)
	_attach_player(medium_controller, Vector3.ZERO)
	_attach_rain_audio_zones(
		medium_controller,
		[
			_make_rain_audio_zone(1, RAIN_AUDIO_TIER_MEDIUM, Vector3.ZERO, Vector3(10.0, 6.0, 10.0)),
		]
	)
	var medium_eval := medium_controller.call("debug_evaluate_rain_audio_state") as Dictionary
	medium_controller.free()

	var low_controller := _build_controller(false)
	_prime_controller(low_controller)
	_attach_player(low_controller, Vector3.ZERO)
	_attach_rain_audio_zones(
		low_controller,
		[
			_make_rain_audio_zone(1, RAIN_AUDIO_TIER_LOW, Vector3.ZERO, Vector3(10.0, 6.0, 10.0)),
		]
	)
	var low_eval := low_controller.call("debug_evaluate_rain_audio_state") as Dictionary
	low_controller.free()

	assert(medium_eval["tier"] == &"rain_medium", "Medium rain-audio zones should map to the medium tier")
	assert(low_eval["tier"] == &"rain_low", "Low rain-audio zones should map to the low tier")
	assert(float(low_eval["volume_db"]) < float(medium_eval["volume_db"]), "Low rain-audio zones should be quieter than medium zones")
	assert(low_eval["sound_id"] == &"rain_loop", "Low rain-audio zones should keep the muffled base rain loop")
	print("✓ Low rain-audio zones attenuate ambience relative to medium zones")
