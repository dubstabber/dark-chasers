extends Node

## Tests for Phase 4: Movement/Input responsibility separation
## Verifies that PlayerMovementComponent no longer reads Input directly

func _ready():
	print("=== MOVEMENT INPUT SEPARATION TESTS ===")
	
	test_movement_component_no_input_polling()
	test_movement_accepts_input_state_params()
	test_input_component_passes_state()
	
	print("=== ALL MOVEMENT INPUT SEPARATION TESTS COMPLETED ===")


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


func test_input_component_passes_state():
	print("\n--- Testing PlayerInputComponent passes input state ---")
	
	var script = load("res://scenes/components/input/player_input_component.gd") as GDScript
	var source = script.source_code
	
	# Verify PlayerInputComponent reads input and passes it
	assert("Input.is_action_pressed(\"crouch\")" in source, "PlayerInputComponent should read crouch input")
	assert("Input.is_action_pressed(\"sprint\")" in source, "PlayerInputComponent should read sprint input")
	assert("is_crouching, is_sprinting" in source or "is_crouching_input, is_sprinting_input" in source or "is_crouching, is_sprinting)" in source, "PlayerInputComponent should pass crouch/sprint state to movement")
	
	print("✓ PlayerInputComponent passes input state to movement component")
