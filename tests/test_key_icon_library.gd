extends SceneTree

func _init() -> void:
	print("=== KEY ICON LIBRARY TESTS ===")
	_test_lookup_and_fallbacks()
	print("=== KEY ICON LIBRARY TESTS COMPLETED ===")
	quit(0)


func _test_lookup_and_fallbacks() -> void:
	var lib: KeyIconLibrary = load("res://scenes/resources/key_icon_library.tres")
	assert(lib != null, "Should load KeyIconLibrary")

	assert(lib.get_texture("ruby") != null, "ruby should have a texture")
	assert(lib.get_texture("silver") != null, "silver should have a texture")

	# Legacy behavior: 'useless' has a special message but uses silver texture.
	assert(lib.get_pickup_message("useless") == "Congratulations! You just picked up the useless key!", "useless key message should match")
	assert(lib.get_texture("useless") == lib.get_texture("silver"), "useless key should fall back to silver texture")

	assert(lib.get_pickup_message("unknown") == "Picked up a key.", "unknown keys should use default pickup message")
	print("✓ KeyIconLibrary lookup and fallbacks")
