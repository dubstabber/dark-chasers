extends Node

## Regression tests for DamageEffectsComponent
## Tests signal connections, setter behavior, and prevents recursive setter bugs

class SignalTracker:
	var signals_received = {}
	var last_signal_args = {}
	
	func track_signal(signal_name: String, args: Array = []):
		if not signals_received.has(signal_name):
			signals_received[signal_name] = 0
		signals_received[signal_name] += 1
		last_signal_args[signal_name] = args
	
	func was_signal_emitted(signal_name: String) -> bool:
		return signals_received.has(signal_name) and signals_received[signal_name] > 0
	
	func get_signal_count(signal_name: String) -> int:
		return signals_received.get(signal_name, 0)
	
	func reset():
		signals_received.clear()
		last_signal_args.clear()

var signal_tracker: SignalTracker

func _ready():
	print("=== DAMAGE EFFECTS COMPONENT TESTS ===")
	signal_tracker = SignalTracker.new()
	
	test_setter_no_recursion()
	test_health_component_signal_connection()
	test_health_component_reassignment()
	test_health_component_null_assignment()
	
	print("=== ALL DAMAGE EFFECTS COMPONENT TESTS COMPLETED ===")

func test_setter_no_recursion():
	print("\n--- Testing Setter Does Not Recurse ---")
	
	var damage_effects = preload("res://scenes/components/effects/damage_effects_component.gd").new()
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(damage_effects)
	add_child(health_comp)
	
	# This should NOT cause a stack overflow
	damage_effects.health_component = health_comp
	assert(damage_effects.health_component == health_comp, "Health component should be assigned")
	print("✓ Setter assignment works without recursion")
	
	# Test re-assignment (was causing recursion before fix)
	var health_comp2 = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp2)
	damage_effects.health_component = health_comp2
	assert(damage_effects.health_component == health_comp2, "Health component should be reassigned")
	print("✓ Setter reassignment works without recursion")
	
	health_comp.queue_free()
	health_comp2.queue_free()
	damage_effects.queue_free()

func test_health_component_signal_connection():
	print("\n--- Testing Health Component Signal Connection ---")
	
	var damage_effects = preload("res://scenes/components/effects/damage_effects_component.gd").new()
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(damage_effects)
	add_child(health_comp)
	
	# Assign health component
	damage_effects.health_component = health_comp
	
	# Check that signals are connected
	assert(health_comp.damage_taken.is_connected(damage_effects._on_damage_taken),
		"damage_taken signal should be connected")
	assert(health_comp.died.is_connected(damage_effects._on_died),
		"died signal should be connected")
	print("✓ Signals connected correctly after assignment")
	
	health_comp.queue_free()
	damage_effects.queue_free()

func test_health_component_reassignment():
	print("\n--- Testing Health Component Reassignment ---")
	
	var damage_effects = preload("res://scenes/components/effects/damage_effects_component.gd").new()
	var health_comp1 = preload("res://scenes/components/health/health_component.gd").new()
	var health_comp2 = preload("res://scenes/components/health/health_component.gd").new()
	add_child(damage_effects)
	add_child(health_comp1)
	add_child(health_comp2)
	
	# Assign first health component
	damage_effects.health_component = health_comp1
	assert(health_comp1.damage_taken.is_connected(damage_effects._on_damage_taken),
		"First health component signal should be connected")
	
	# Reassign to second health component
	damage_effects.health_component = health_comp2
	
	# Check old signals disconnected
	assert(not health_comp1.damage_taken.is_connected(damage_effects._on_damage_taken),
		"First health component signal should be disconnected")
	assert(not health_comp1.died.is_connected(damage_effects._on_died),
		"First health component died signal should be disconnected")
	
	# Check new signals connected
	assert(health_comp2.damage_taken.is_connected(damage_effects._on_damage_taken),
		"Second health component signal should be connected")
	assert(health_comp2.died.is_connected(damage_effects._on_died),
		"Second health component died signal should be connected")
	print("✓ Signal disconnect/reconnect on reassignment works correctly")
	
	health_comp1.queue_free()
	health_comp2.queue_free()
	damage_effects.queue_free()

func test_health_component_null_assignment():
	print("\n--- Testing Health Component Null Assignment ---")
	
	var damage_effects = preload("res://scenes/components/effects/damage_effects_component.gd").new()
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(damage_effects)
	add_child(health_comp)
	
	# Assign health component
	damage_effects.health_component = health_comp
	assert(damage_effects.health_component == health_comp, "Health component should be assigned")
	
	# Set to null (should disconnect signals)
	damage_effects.health_component = null
	
	assert(damage_effects.health_component == null, "Health component should be null")
	assert(not health_comp.damage_taken.is_connected(damage_effects._on_damage_taken),
		"Signal should be disconnected after null assignment")
	assert(not health_comp.died.is_connected(damage_effects._on_died),
		"Died signal should be disconnected after null assignment")
	print("✓ Null assignment disconnects signals correctly")
	
	health_comp.queue_free()
	damage_effects.queue_free()
