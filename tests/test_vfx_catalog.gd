extends Node

func _ready() -> void:
	print("=== VFX CATALOG TESTS ===")
	_test_lookup()
	print("=== VFX CATALOG TESTS COMPLETED ===")
	get_tree().quit()


func _test_lookup() -> void:
	var catalog: VfxCatalog = load("res://scenes/resources/vfx_catalog.tres")
	assert(catalog != null, "VfxCatalog should load")

	assert(catalog.get_scene(&"red_blood_particle") != null, "red_blood_particle should be present")
	assert(catalog.get_scene(&"blue_blood_particle") != null, "blue_blood_particle should be present")
	assert(catalog.get_scene(&"blood_splat_decal") != null, "blood_splat_decal should be present")
	assert(catalog.get_scrap_scene() != null, "scrap scene should be present")
	assert(catalog.get_scene(&"missing_scene") == null, "missing id should return null")
	print("✓ VfxCatalog lookup and fallback")
