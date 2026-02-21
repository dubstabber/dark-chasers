extends Node

## Tests for Phase 6: Asset registries and consistency cleanups
## Verifies typed catalogs, audio standardization, and logic fixes

func _ready():
	print("=== ASSET REGISTRIES TESTS ===")
	
	test_particle_catalog_exists()
	test_services_has_catalog_accessor()
	test_armor_component_uses_utils_audio()
	test_image_enemy_scaling_logic()
	
	print("=== ALL ASSET REGISTRIES TESTS COMPLETED ===")
	get_tree().quit()


func test_particle_catalog_exists():
	print("\n--- Testing ParticleCatalog Resource ---")
	
	var catalog = load("res://scenes/resources/particle_catalog.tres") as ParticleCatalog
	assert(catalog != null, "ParticleCatalog should load")
	
	# Verify arrays are populated
	assert(catalog.small_wood_images.size() > 0, "small_wood_images should have entries")
	assert(catalog.big_wood_images.size() > 0, "big_wood_images should have entries")
	assert(catalog.paper_scrap_images.size() > 0, "paper_scrap_images should have entries")
	assert(catalog.glass_scrap_images.size() > 0, "glass_scrap_images should have entries")
	assert(catalog.doom_decal_images.size() > 0, "doom_decal_images should have entries")
	
	print("✓ ParticleCatalog exists and has populated arrays")


func test_services_has_catalog_accessor():
	print("\n--- Testing Services Catalog Accessors ---")
	
	var script = load("res://scenes/services/services.gd") as GDScript
	var source = script.source_code
	
	assert("func get_particle_catalog()" in source, "Services should have get_particle_catalog method")
	assert("func get_vfx_catalog()" in source, "Services should have get_vfx_catalog method")
	assert("var preloads:" not in source, "Services should no longer expose a preloads service")
	
	print("✓ Services exposes catalog accessors without legacy preloads path")


func test_armor_component_uses_utils_audio():
	print("\n--- Testing ArmorComponent Uses Utils Audio ---")
	
	var script = load("res://scenes/components/armor/armor_component.gd") as GDScript
	var source = script.source_code
	
	# Verify no ad-hoc AudioStreamPlayer.new()
	assert("AudioStreamPlayer.new()" not in source, "ArmorComponent should not create ad-hoc AudioStreamPlayers")
	
	# Verify Services.utils.play_sound is used
	assert("Services.utils.play_sound" in source, "ArmorComponent should use Services.utils.play_sound")
	
	print("✓ ArmorComponent uses Services.utils.play_sound instead of ad-hoc audio")


func test_image_enemy_scaling_logic():
	print("\n--- Testing ImageEnemy Scaling Logic ---")
	
	var script = load("res://scenes/enemies/image_enemy.gd") as GDScript
	var source = script.source_code
	
	# Verify always-true condition is fixed
	assert("size.x > sizeto or size.y > sizeto or size.x <= sizeto" not in source, "ImageEnemy should not have always-true condition")
	
	# Verify TARGET_SPRITE_SIZE constant exists
	assert("TARGET_SPRITE_SIZE" in source, "ImageEnemy should have TARGET_SPRITE_SIZE constant")
	
	# Verify cleaner scaling logic
	assert("largest_dimension" in source or "maxf(size.x, size.y)" in source, "ImageEnemy should use proper max dimension calculation")
	
	print("✓ ImageEnemy scaling logic is correct")
