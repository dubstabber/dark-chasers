extends SceneTree

func _init() -> void:
	print("=== BUTTON IMAGE LIBRARY TESTS ===")
	_test_lookup_and_fallback()
	print("=== BUTTON IMAGE LIBRARY TESTS COMPLETED ===")
	quit(0)


func _test_lookup_and_fallback() -> void:
	var lib: ButtonImageLibrary = load("res://scenes/resources/button_image_library.tres")
	assert(lib != null, "Should load ButtonImageLibrary")

	assert(lib.get_texture("lever", false) != null, "lever up should exist")
	assert(lib.get_texture("lever", true) != null, "lever down should exist")
	assert(lib.get_texture("circle", false) != null, "circle up should exist")
	assert(lib.get_texture("circle", true) != null, "circle down should exist")

	# Unknown types should fall back to circle (legacy-friendly behavior)
	assert(lib.get_texture("unknown", false) == lib.get_texture("circle", false), "unknown type should fall back to circle up")
	print("✓ ButtonImageLibrary lookup and fallback")
