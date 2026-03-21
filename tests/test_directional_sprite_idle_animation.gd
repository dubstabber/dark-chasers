extends Node

var _failed := false


func _ready() -> void:
	print("=== DIRECTIONAL SPRITE IDLE ANIMATION TESTS ===")
	_test_idle_property_switch_returns_array_when_enabled()
	_test_idle_property_switch_returns_first_frame_when_disabled()
	_test_idle_animation_array_preserves_empty_slots_for_inspector_editing()
	_test_movement_array_preserves_empty_slots_for_inspector_editing()
	_test_idle_animation_frames_extend_atlas_width()
	_test_enemy_idle_animation_falls_back_to_idle_clip()
	_test_enemy_animation_component_auto_discovers_player_and_starts_idle()
	await _test_squatto_scene_autowires_and_starts_animations()
	if _failed:
		get_tree().quit(1)
		return
	print("=== DIRECTIONAL SPRITE IDLE ANIMATION TESTS PASSED ===")
	get_tree().quit()


func _test_idle_property_switch_returns_array_when_enabled() -> void:
	var sprite := DirectionalSprite3D.new()
	var frame_a := _create_test_texture(12, 20, Color.RED)
	var frame_b := _create_test_texture(12, 20, Color.GREEN)
	sprite.idle_uses_animation = true
	sprite.idle_sprites["front"] = [frame_a, frame_b]
	var idle_value = sprite._get(&"front_idle_sprite")
	_assert(idle_value is Array, "Animated idle property should be exposed as an array")
	_assert(idle_value.size() == 2, "Animated idle property should return all idle frames")


func _test_idle_property_switch_returns_first_frame_when_disabled() -> void:
	var sprite := DirectionalSprite3D.new()
	var frame_a := _create_test_texture(12, 20, Color.RED)
	var frame_b := _create_test_texture(12, 20, Color.GREEN)
	sprite.idle_sprites["front"] = [frame_a, frame_b]
	var idle_value = sprite._get(&"front_idle_sprite")
	_assert(idle_value == frame_a, "Single-frame idle mode should expose the first idle frame")


func _test_idle_animation_array_preserves_empty_slots_for_inspector_editing() -> void:
	var sprite := DirectionalSprite3D.new()
	sprite.idle_uses_animation = true
	var applied := sprite._set(&"front_idle_sprite", [null])
	var idle_value = sprite._get(&"front_idle_sprite")
	_assert(applied, "Animated idle property updates should be accepted")
	_assert(idle_value is Array, "Animated idle property should stay an array after inspector-style edits")
	_assert(idle_value.size() == 1, "Animated idle property should preserve empty placeholder slots")
	_assert(idle_value[0] == null, "Animated idle property should keep null placeholder slots for Add Element")


func _test_movement_array_preserves_empty_slots_for_inspector_editing() -> void:
	var sprite := DirectionalSprite3D.new()
	sprite._update_node_references()
	sprite.has_moving_state = true
	var applied := sprite._set(&"front_movement_sprites", [null])
	var movement_value = sprite._get(&"front_movement_sprites")
	_assert(applied, "Movement property updates should be accepted")
	_assert(movement_value is Array, "Movement property should stay an array after inspector-style edits")
	_assert(movement_value.size() == 1, "Movement property should preserve empty placeholder slots")
	_assert(movement_value[0] == null, "Movement property should keep null placeholder slots for Add Element")


func _test_idle_animation_frames_extend_atlas_width() -> void:
	var sprite := DirectionalSprite3D.new()
	var frame_a := _create_test_texture(16, 16, Color.RED)
	var frame_b := _create_test_texture(16, 16, Color.GREEN)
	var move_frame := _create_test_texture(16, 16, Color.BLUE)
	sprite.idle_uses_animation = true
	sprite.idle_sprites["front"] = [frame_a, frame_b]
	sprite.movement_sprites["front"] = [move_frame]
	var result := DirectionalAtlasGenerator.generate(
		sprite.direction_mode,
		["front"],
		sprite.idle_sprites,
		sprite.movement_sprites,
		sprite.shooting_sprites
	)
	_assert(result.max_sprite_size == Vector2i(16, 16), "Atlas max sprite size should include idle animation frames")
	_assert(result.texture != null, "Atlas generation should succeed for animated idle frames")
	_assert(result.texture.get_width() == 48, "Atlas width should include idle animation frames before movement frames")
	_assert(result.texture.get_height() == 16, "Atlas height should stay tied to direction count")


func _test_enemy_idle_animation_falls_back_to_idle_clip() -> void:
	var animation_player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	var idle_animation := Animation.new()
	idle_animation.resource_name = "idle"
	idle_animation.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(&"idle", idle_animation)
	animation_player.add_animation_library(&"", library)
	var component := EnemyAnimationComponent.new()
	component.animation_player = animation_player
	component.idle_animation = "RESET"
	_assert(component._get_idle_animation_name() == "idle", "Enemy animation component should prefer an authored idle clip over RESET fallback")


func _test_enemy_animation_component_auto_discovers_player_and_starts_idle() -> void:
	var enemy_root := Node.new()
	var graphics := Node.new()
	graphics.name = "Graphics"
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	var library := AnimationLibrary.new()
	var idle_animation := Animation.new()
	idle_animation.resource_name = "idle"
	idle_animation.loop_mode = Animation.LOOP_LINEAR
	var move_animation := Animation.new()
	move_animation.resource_name = "move"
	move_animation.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(&"idle", idle_animation)
	library.add_animation(&"move", move_animation)
	animation_player.add_animation_library(&"", library)
	var component := EnemyAnimationComponent.new()
	enemy_root.add_child(graphics)
	graphics.add_child(animation_player)
	enemy_root.add_child(component)
	add_child(enemy_root)
	await get_tree().process_frame
	component._physics_process(0.016)
	_assert(component.animation_player == animation_player, "Enemy animation component should auto-discover the AnimationPlayer")
	_assert(animation_player.current_animation == "idle", "Enemy animation component should start idle playback on first idle update")
	component._apply_animation_state(true)
	_assert(animation_player.current_animation == "move", "Enemy animation component should switch to move playback when moving")
	enemy_root.queue_free()


func _test_squatto_scene_autowires_and_starts_animations() -> void:
	var squatto_scene := load("res://scenes/enemies/squatto.tscn") as PackedScene
	_assert(squatto_scene != null, "Squatto scene should load for animated-idle regression coverage")
	if squatto_scene == null:
		return
	var squatto := squatto_scene.instantiate()
	add_child(squatto)
	await get_tree().process_frame
	var component := squatto.get_node_or_null("EnemyAnimationComponent") as EnemyAnimationComponent
	var directional_sprite := squatto.get_node_or_null("Graphics/DirectionalSprite3D") as DirectionalSprite3D
	_assert(component != null, "Squatto should have an EnemyAnimationComponent")
	_assert(directional_sprite != null, "Squatto should have a DirectionalSprite3D")
	if component == null:
		squatto.queue_free()
		return
	if directional_sprite == null:
		squatto.queue_free()
		return
	if squatto is Enemy:
		squatto.velocity = Vector3.ZERO
	component.update_animation_state()
	_assert(component.animation_player != null, "Squatto enemy animation component should auto-discover its AnimationPlayer")
	if component.animation_player != null:
		component.animation_player.advance(0.25)
		var idle_frame := _get_material_frame(directional_sprite)
		_assert(idle_frame > 0 and idle_frame < 4, "Squatto idle animation should advance within the authored idle frame range (current_animation=%s, is_playing=%s, frame=%d)" % [component.animation_player.current_animation, str(component.animation_player.is_playing()), idle_frame])
	if squatto is Enemy:
		squatto.velocity = Vector3(1.0, 0.0, 0.0)
	component.update_animation_state()
	if component.animation_player != null:
		component.animation_player.advance(0.25)
		var move_frame := _get_material_frame(directional_sprite)
		_assert(move_frame >= 4, "Squatto move animation should advance into the authored movement frame range (current_animation=%s, is_playing=%s, frame=%d)" % [component.animation_player.current_animation, str(component.animation_player.is_playing()), move_frame])
	squatto.queue_free()
	await get_tree().process_frame


func _get_material_frame(sprite: DirectionalSprite3D) -> int:
	var material := sprite.material_override as ShaderMaterial
	if material == null:
		return -1
	return int(material.get_shader_parameter("current_frame"))


func _create_test_texture(width: int, height: int, color: Color) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
