extends Node

## Tests for Phase 4: Movement/Input responsibility separation
## Verifies that:
## - PlayerMovementComponent no longer reads Input directly
## - Player owns _physics_process (gravity, move_and_slide, last_velocity)
## - PlayerInputComponent does NOT have its own _physics_process

func _ready():
	print("=== MOVEMENT INPUT SEPARATION TESTS ===")
	
	test_movement_component_no_input_polling()
	test_movement_accepts_input_state_params()
	test_movement_component_delegates_slide_state()
	test_input_component_passes_state()
	test_player_owns_physics_process()
	test_input_component_no_physics_process()
	test_player_owns_move_and_slide()
	test_movement_component_uses_standing_clearance_guard()
	
	print("=== ALL MOVEMENT INPUT SEPARATION TESTS COMPLETED ===")
	get_tree().quit()


func test_movement_component_no_input_polling():
	print("\n--- Testing PlayerMovementComponent has no Input polling ---")
	
	var script = load("res://scenes/components/movement/player_movement_component.gd") as GDScript
	assert(script != null, "PlayerMovementComponent script should load")
	
	var source = script.source_code
	
	# Verify no direct Input.is_action_pressed calls
	assert("Input.is_action_pressed" not in source, "PlayerMovementComponent should not poll Input.is_action_pressed")
	assert("Input.is_action_just_pressed" not in source, "PlayerMovementComponent should not poll Input.is_action_just_pressed")
	
	print("✓ PlayerMovementComponent has no Input polling")


func test_movement_accepts_input_state_params():
	print("\n--- Testing PlayerMovementComponent accepts input state params ---")
	
	var script = load("res://scenes/components/movement/player_movement_component.gd") as GDScript
	var source = script.source_code
	
	# Verify process_movement signature includes input state parameters
	assert("is_crouching_input: bool" in source, "process_movement should accept is_crouching_input param")
	assert("is_sprinting_input: bool" in source, "process_movement should accept is_sprinting_input param")
	
	print("✓ PlayerMovementComponent accepts input state parameters")


func test_movement_component_delegates_slide_state():
	print("\n--- Testing PlayerMovementComponent delegates slide state ---")
	
	var script = load("res://scenes/components/movement/player_movement_component.gd") as GDScript
	var source = script.source_code
	
	assert("PlayerSlideController.new()" in source, "PlayerMovementComponent should construct PlayerSlideController")
	assert("_slide_controller.start_slide" in source, "PlayerMovementComponent should delegate slide start")
	assert("_slide_controller.update" in source, "PlayerMovementComponent should delegate slide timer updates")
	assert("_slide_controller.get_slide_vector" in source, "PlayerMovementComponent should read slide vector from PlayerSlideController")
	
	print("✓ PlayerMovementComponent delegates slide state to PlayerSlideController")


func test_input_component_passes_state():
	print("\n--- Testing PlayerInputComponent passes input state ---")
	
	var script = load("res://scenes/components/input/player_input_component.gd") as GDScript
	var source = script.source_code
	
	# Verify PlayerInputComponent reads input and passes it
	assert("Input.is_action_pressed(\"crouch\")" in source, "PlayerInputComponent should read crouch input")
	assert("Input.is_action_pressed(\"sprint\")" in source, "PlayerInputComponent should read sprint input")
	assert("is_crouching, is_sprinting" in source or "is_crouching_input, is_sprinting_input" in source or "is_crouching, is_sprinting)" in source, "PlayerInputComponent should pass crouch/sprint state to movement")
	
	print("✓ PlayerInputComponent passes input state to movement component")


func test_player_owns_physics_process():
	print("\n--- Testing Player owns _physics_process ---")
	
	var script = load("res://scenes/player/player.gd") as GDScript
	var source = script.source_code
	
	assert("func _physics_process" in source, "Player should define _physics_process")
	assert("velocity.y -= gravity" in source, "Player should apply gravity")
	
	print("✓ Player owns _physics_process with gravity")


func test_input_component_no_physics_process():
	print("\n--- Testing PlayerInputComponent has no _physics_process ---")
	
	var script = load("res://scenes/components/input/player_input_component.gd") as GDScript
	var source = script.source_code
	
	assert("func _physics_process" not in source, "PlayerInputComponent should NOT define _physics_process")
	assert("process_physics_input" in source, "PlayerInputComponent should expose process_physics_input for Player to call")
	
	print("✓ PlayerInputComponent has no _physics_process (Player calls it)")


func test_player_owns_move_and_slide():
	print("\n--- Testing Player owns move_and_slide ---")
	
	var player_src = load("res://scenes/player/player.gd").source_code
	var input_src = load("res://scenes/components/input/player_input_component.gd").source_code
	
	assert("\n\tmove_and_slide()" in player_src, "Player should call move_and_slide()")
	assert("\n\tmove_and_slide()" not in input_src, "PlayerInputComponent should NOT call move_and_slide()")
	
	print("✓ Player owns move_and_slide (not input component)")


func test_movement_component_uses_standing_clearance_guard():
	print("\n--- Testing PlayerMovementComponent uses standing clearance guard ---")
	
	var movement_src = load("res://scenes/components/movement/player_movement_component.gd").source_code
	
	assert("if _can_stand_up():" in movement_src, "PlayerMovementComponent should gate uncrouching through _can_stand_up()")
	assert("PhysicsShapeQueryParameters3D.new()" in movement_src, "PlayerMovementComponent should build a shape query for standing clearance")
	assert("intersect_shape(query, 8)" in movement_src, "PlayerMovementComponent should verify standing collision shape clearance with intersect_shape")
	assert("var in_crouched_stance := _is_in_crouched_stance()" in movement_src, "PlayerMovementComponent should track physical crouch stance before applying stand-up clearance")
	assert("elif in_crouched_stance:" in movement_src, "PlayerMovementComponent should only use stand-up clearance while physically crouched")
	
	print("✓ PlayerMovementComponent uses standing clearance guard")
