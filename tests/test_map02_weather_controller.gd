extends SceneTree


func _init() -> void:
	print("=== MAP02 WEATHER CONTROLLER TESTS ===")
	_test_scheduler_ranges()
	_test_flash_lifecycle_restores_environment()
	_test_indoor_lightning_fallback_attenuates_environment_flash()
	_test_environment_flash_ignores_indoor_state()
	_test_thunder_players_are_ephemeral()
	_test_map02_scene_weather_authoring()
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
	controller.set("thunder_sound_ids", Array([], TYPE_STRING_NAME, "", null))
	controller.set("_environment", environment)
	controller.set("_base_background_energy", environment.background_energy_multiplier)
	controller.set("_base_ambient_energy", environment.ambient_light_energy)
	return controller


func _prime_controller(controller: Node3D) -> void:
	if controller == null:
		push_error("Controller should be valid")


func _test_scheduler_ranges() -> void:
	var controller := _build_controller(false)
	_prime_controller(controller)
	controller.call("debug_set_seed", 1337)
	controller.call("start_weather")

	for _i in range(50):
		controller.call("_schedule_next_flash", false)
		var next_flash := float(controller.call("debug_get_next_flash_seconds"))
		assert(next_flash >= 5.0 and next_flash <= 20.0, "Initial next flash must be in [5.0, 20.0] seconds")

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


func _test_thunder_players_are_ephemeral() -> void:
	var controller := _build_controller(false)
	_prime_controller(controller)
	get_root().add_child(controller)
	var thunder_stream := AudioStreamWAV.new()

	controller.call("_play_thunder_stream", thunder_stream)
	controller.call("_play_thunder_stream", thunder_stream)

	var thunder_players: Array[AudioStreamPlayer] = []
	for child in controller.get_children():
		if child is AudioStreamPlayer:
			thunder_players.append(child as AudioStreamPlayer)

	assert(thunder_players.size() == 2, "Each thunder playback should create its own AudioStreamPlayer child")
	for thunder_player in thunder_players:
		thunder_player.emit_signal("finished")
		assert(thunder_player.is_queued_for_deletion(), "Finished thunder players should queue_free themselves")

	controller.free()
	print("✓ Thunder players are spawned per strike and auto-cleaned")


func _test_map02_scene_weather_authoring() -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/maps/mansion_2/mansion_2.tscn")
	assert(not scene_text.is_empty(), "MAP02 scene text should be readable for weather authoring verification")
	assert(scene_text.contains("[node name=\"WeatherController\" type=\"Node3D\" parent=\".\"]"), "MAP02 scene should include WeatherController root")
	assert(not scene_text.contains("[node name=\"ThunderAudio\" type=\"AudioStreamPlayer\" parent=\"WeatherController\"]"), "MAP02 scene should not include shared ThunderAudio under WeatherController")
	assert(scene_text.contains("[node name=\"ReflectionProbe9\" type=\"ReflectionProbe\" parent=\"Decorations\"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 86.37787, 7.6006327, -5.5837784)"), "MAP02 scene should still keep the tuned large reflection probe used for weather lighting")
	print("✓ MAP02 scene keeps weather controller authoring without shared thunder node")
