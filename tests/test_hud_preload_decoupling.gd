extends Node

var _failed := false


class MockBitmapFontCatalog:
	extends BitmapFontCatalog

	var textures := {}

	func get_texture(character: String) -> Texture2D:
		if character.is_empty():
			return null
		return textures.get(character.left(1), null)


func _ready() -> void:
	print("=== HUD PRELOAD/PATH DECOUPLING TESTS ===")
	_test_hud_uses_class_name_helper_controllers()
	_test_hud_log_label_scene_is_exported_reference()
	_test_ui_bitmap_text_uses_catalog_backed_glyph_lookup()
	_test_ui_bitmap_text_sentinel_hide_behavior()
	print("=== HUD PRELOAD/PATH DECOUPLING TESTS COMPLETED ===")
	get_tree().quit(1 if _failed else 0)


func _test_hud_uses_class_name_helper_controllers() -> void:
	print("\n--- Testing HUD helper controller class_name usage ---")
	var source := FileAccess.get_file_as_string("res://scenes/hud.gd")
	_assert("HudPlayerBindingController.new()" in source, "HUD should instantiate HudPlayerBindingController via class_name")
	_assert("HudPlayerBindingControllerScript" not in source, "HUD should not use script-path preload alias for binding controller")
	_assert("HudEventTextController.new()" in source, "HUD should instantiate HudEventTextController via class_name")
	_assert("HudEventTextControllerScript" not in source, "HUD should not use script-path preload alias for event-text controller")
	print("✓ HUD uses class_name helper controllers")


func _test_hud_log_label_scene_is_exported_reference() -> void:
	print("\n--- Testing HUD log-label exported scene reference ---")
	var source := FileAccess.get_file_as_string("res://scenes/hud.gd")
	_assert("@export var log_label_scene: PackedScene" in source, "HUD should export log_label_scene")
	_assert("preload(\"res://scenes/ui/log_label.tscn\")" not in source, "HUD should not hardcode log_label preload")
	_assert("if not log_label_scene:" in source, "HUD should guard missing log_label_scene")

	var hud_scene_source := FileAccess.get_file_as_string("res://scenes/hud.tscn")
	_assert("log_label_scene = ExtResource" in hud_scene_source, "HUD scene should assign log_label_scene")
	_assert("res://scenes/ui/log_label.tscn" in hud_scene_source, "HUD scene should reference log_label.tscn")
	print("✓ HUD log-label reference is decoupled")


func _test_ui_bitmap_text_uses_catalog_backed_glyph_lookup() -> void:
	print("\n--- Testing UI bitmap text catalog-backed rendering ---")
	var source := FileAccess.get_file_as_string("res://fonts/ui_bitmap_text.gd")
	_assert("@export var ui_bitmap_font_catalog: BitmapFontCatalog" in source, "UI bitmap text should export ui_bitmap_font_catalog")
	_assert("_font_catalog.get_texture(digit)" in source, "UI bitmap text should resolve digit textures from catalog")
	_assert("uid://" not in source, "UI bitmap text should not use UID preload digit map")

	var script := load("res://fonts/ui_bitmap_text.gd") as GDScript
	var ui_value := script.new() as HBoxContainer
	var mock_catalog := MockBitmapFontCatalog.new()
	var tex_0 := load("res://images/fonts/STFSNUM0.png") as Texture2D
	var tex_1 := load("res://images/fonts/STFSNUM1.png") as Texture2D
	var tex_9 := load("res://images/fonts/STFSNUM9.png") as Texture2D
	mock_catalog.textures["0"] = tex_0
	mock_catalog.textures["1"] = tex_1
	mock_catalog.textures["9"] = tex_9

	ui_value.set_font_catalog(mock_catalog)
	ui_value.set_value_with_aooni_font(109)

	_assert(ui_value.get_child_count() == 3, "UI bitmap text should render one sprite per digit")
	_assert((ui_value.get_child(0) as TextureRect).texture == tex_1, "First rendered digit should use catalog texture for '1'")
	_assert((ui_value.get_child(1) as TextureRect).texture == tex_0, "Second rendered digit should use catalog texture for '0'")
	_assert((ui_value.get_child(2) as TextureRect).texture == tex_9, "Third rendered digit should use catalog texture for '9'")
	ui_value.free()
	print("✓ UI bitmap text renders digits via bitmap font catalog")


func _test_ui_bitmap_text_sentinel_hide_behavior() -> void:
	print("\n--- Testing UI bitmap text sentinel hide behavior ---")
	var script := load("res://fonts/ui_bitmap_text.gd") as GDScript
	var ui_value := script.new() as HBoxContainer
	var mock_catalog := MockBitmapFontCatalog.new()
	mock_catalog.textures["0"] = load("res://images/fonts/STFSNUM0.png") as Texture2D
	ui_value.set_font_catalog(mock_catalog)

	ui_value.set_value_with_aooni_font(0)
	_assert(ui_value.get_child_count() == 1, "Value 0 should render normally")

	ui_value.set_value_with_aooni_font(-1)
	_assert(ui_value.get_child_count() == 0, "Negative sentinel should hide digit sprites")
	ui_value.free()
	print("✓ Sentinel hide behavior remains intact")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
