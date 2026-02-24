extends SceneTree

func _init() -> void:
	print("=== SFX CATALOG TESTS ===")
	_test_lookup()
	print("=== SFX CATALOG TESTS COMPLETED ===")
	quit(0)


func _test_lookup() -> void:
	var catalog: SfxCatalog = load("res://scenes/resources/sfx_catalog.tres")
	assert(catalog != null, "SfxCatalog should load")

	assert(catalog.get_sound(&"key_collected") != null, "key_collected should be present")
	assert(catalog.get_sound(&"water_splash") != null, "water_splash should be present")
	assert(catalog.get_sound(&"kill_player") != null, "kill_player should be present")
	assert(catalog.get_sound(&"event_trigger") != null, "event_trigger should be present")
	assert(catalog.get_sound(&"spawn") != null, "spawn should be present")
	assert(catalog.get_sound(&"bar_shake") != null, "bar_shake should be present")
	assert(catalog.get_sound(&"wall_cut") != null, "wall_cut should be present")
	assert(catalog.get_sound(&"creep_ambience") != null, "creep_ambience should be present")
	assert(catalog.get_sound(&"ao_see") != null, "ao_see should be present")
	assert(catalog.get_sound(&"d_running") != null, "d_running should be present")
	assert(catalog.get_sound(&"missing_sound") == null, "missing id should return null")
	print("✓ SfxCatalog lookup and fallback")
