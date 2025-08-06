extends Node

## Comprehensive unit tests for the HealthComponent system
## Tests core health functionality, armor integration, signals, and edge cases

# Signal tracking helper class
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
	
	func get_last_args(signal_name: String) -> Array:
		return last_signal_args.get(signal_name, [])
	
	func reset():
		signals_received.clear()
		last_signal_args.clear()

var signal_tracker: SignalTracker

func _ready():
	print("=== HEALTH COMPONENT COMPREHENSIVE TESTS ===")
	signal_tracker = SignalTracker.new()
	
	# Core Health Functionality Tests
	test_health_initialization_default()
	test_health_initialization_custom()
	test_take_damage_basic()
	test_take_damage_clamping()
	test_healing_basic()
	test_healing_clamping()
	test_health_percentage_calculation()
	test_death_detection()
	
	# Health Property Setters Tests
	test_max_health_setter()
	test_current_health_setter()
	test_set_health_direct()
	
	# Invulnerability Tests
	test_invulnerability_flag()

	print("=== BASIC HEALTH COMPONENT TESTS COMPLETED ===")
	print("Note: Extended tests (invulnerability timer, kill/revive methods, signals, etc.)")
	print("are available in test_health_component_extended.gd and test_health_component_armor.gd")
	
	print("=== ALL HEALTH COMPONENT TESTS COMPLETED ===")

func test_health_initialization_default():
	print("\n--- Testing Health Initialization (Default Values) ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	
	# Test default values
	assert(health_comp.max_health == 100, "Default max_health should be 100")
	assert(health_comp.current_health == 100, "Default current_health should be 100")
	assert(health_comp.can_overheal == false, "Default can_overheal should be false")
	assert(health_comp.overheal_limit == 150, "Default overheal_limit should be 150")
	assert(health_comp.is_dead == false, "Should not be dead initially")
	assert(health_comp.invulnerable == false, "Should not be invulnerable initially")
	print("✓ Default initialization values correct")
	
	health_comp.queue_free()

func test_health_initialization_custom():
	print("\n--- Testing Health Initialization (Custom Values) ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	
	# Set custom values
	health_comp.max_health = 200
	health_comp.current_health = 150
	health_comp.can_overheal = true
	health_comp.overheal_limit = 250
	
	assert(health_comp.max_health == 200, "Custom max_health should be 200")
	assert(health_comp.current_health == 150, "Custom current_health should be 150")
	assert(health_comp.can_overheal == true, "Custom can_overheal should be true")
	assert(health_comp.overheal_limit == 250, "Custom overheal_limit should be 250")
	print("✓ Custom initialization values correct")
	
	health_comp.queue_free()

func test_take_damage_basic():
	print("\n--- Testing Basic Damage Taking ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 100
	
	# Test basic damage
	var result = health_comp.take_damage(30)
	assert(result == true, "Should return true when damage is applied")
	assert(health_comp.current_health == 70, "Health should be reduced to 70")
	assert(health_comp.is_dead == false, "Should not be dead after non-lethal damage")
	print("✓ Basic damage taking works")
	
	# Test lethal damage
	result = health_comp.take_damage(80)
	assert(result == true, "Should return true when lethal damage is applied")
	assert(health_comp.current_health == 0, "Health should be 0 after lethal damage")
	assert(health_comp.is_dead == true, "Should be dead after lethal damage")
	print("✓ Lethal damage works")
	
	health_comp.queue_free()

func test_take_damage_clamping():
	print("\n--- Testing Damage Clamping ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 50
	
	# Test excessive damage (should clamp to 0)
	health_comp.take_damage(100)
	assert(health_comp.current_health == 0, "Health should not go below 0")
	print("✓ Health clamping to 0 works")
	
	health_comp.queue_free()

func test_healing_basic():
	print("\n--- Testing Basic Healing ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 50
	health_comp.max_health = 100
	
	# Test basic healing
	var result = health_comp.heal(30)
	assert(result == true, "Should return true when healing is applied")
	assert(health_comp.current_health == 80, "Health should be increased to 80")
	print("✓ Basic healing works")
	
	# Test healing to full
	result = health_comp.heal(30)
	assert(result == true, "Should return true when healing to full")
	assert(health_comp.current_health == 100, "Health should be at max (100)")
	print("✓ Healing to full health works")
	
	health_comp.queue_free()

func test_healing_clamping():
	print("\n--- Testing Healing Clamping ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 90
	health_comp.max_health = 100
	health_comp.can_overheal = false
	
	# Test excessive healing (should clamp to max_health)
	var result = health_comp.heal(50)
	assert(result == true, "Should return true when healing is applied")
	assert(health_comp.current_health == 100, "Health should not exceed max_health")
	print("✓ Health clamping to max works")
	
	# Test healing when already at full health
	result = health_comp.heal(10)
	assert(result == false, "Should return false when already at full health")
	assert(health_comp.current_health == 100, "Health should remain at max")
	print("✓ No healing when at full health works")
	
	health_comp.queue_free()

func test_health_percentage_calculation():
	print("\n--- Testing Health Percentage Calculation ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.max_health = 100

	# Test various health percentages
	health_comp.current_health = 100
	assert(abs(health_comp.get_health_percentage() - 1.0) < 0.001, "100% health should return 1.0")

	health_comp.current_health = 50
	assert(abs(health_comp.get_health_percentage() - 0.5) < 0.001, "50% health should return 0.5")

	health_comp.current_health = 0
	assert(abs(health_comp.get_health_percentage() - 0.0) < 0.001, "0% health should return 0.0")

	health_comp.current_health = 25
	assert(abs(health_comp.get_health_percentage() - 0.25) < 0.001, "25% health should return 0.25")
	print("✓ Health percentage calculation works")

	health_comp.queue_free()

func test_death_detection():
	print("\n--- Testing Death Detection ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 1

	# Test alive state
	assert(health_comp.is_alive() == true, "Should be alive with health > 0")
	assert(health_comp.is_dead == false, "is_dead flag should be false")

	# Test death
	health_comp.take_damage(1)
	assert(health_comp.is_alive() == false, "Should not be alive with health = 0")
	assert(health_comp.is_dead == true, "is_dead flag should be true")
	print("✓ Death detection works")

	health_comp.queue_free()

func test_max_health_setter():
	print("\n--- Testing Max Health Setter ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)

	# Connect signal to track emissions
	signal_tracker.reset()
	health_comp.health_changed.connect(func(current, max_health): signal_tracker.track_signal("health_changed", [current, max_health]))

	# Test setting max health
	health_comp.current_health = 100
	health_comp.max_health = 150
	assert(health_comp.max_health == 150, "Max health should be set to 150")
	assert(signal_tracker.was_signal_emitted("health_changed"), "health_changed signal should be emitted")

	# Test setting max health below current health (without overheal)
	health_comp.can_overheal = false
	health_comp.current_health = 100
	health_comp.max_health = 80
	assert(health_comp.max_health == 80, "Max health should be set to 80")
	assert(health_comp.current_health == 80, "Current health should be clamped to new max")

	# Test minimum max health (should be at least 1)
	health_comp.max_health = 0
	assert(health_comp.max_health == 1, "Max health should be clamped to minimum of 1")

	health_comp.max_health = -10
	assert(health_comp.max_health == 1, "Negative max health should be clamped to 1")
	print("✓ Max health setter works correctly")

	health_comp.queue_free()

func test_current_health_setter():
	print("\n--- Testing Current Health Setter ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.max_health = 100

	# Connect signal to track emissions
	signal_tracker.reset()
	health_comp.health_changed.connect(func(current, max_health): signal_tracker.track_signal("health_changed", [current, max_health]))
	health_comp.died.connect(func(): signal_tracker.track_signal("died"))

	# Test setting current health
	health_comp.current_health = 75
	assert(health_comp.current_health == 75, "Current health should be set to 75")
	assert(signal_tracker.was_signal_emitted("health_changed"), "health_changed signal should be emitted")

	# Test setting health to 0 (should trigger death)
	signal_tracker.reset()
	health_comp.current_health = 0
	assert(health_comp.current_health == 0, "Current health should be 0")
	assert(health_comp.is_dead == true, "Should be marked as dead")
	assert(signal_tracker.was_signal_emitted("died"), "died signal should be emitted")

	# Test clamping negative values
	health_comp.is_dead = false # Reset death state for testing
	health_comp.current_health = -50
	assert(health_comp.current_health == 0, "Negative health should be clamped to 0")
	print("✓ Current health setter works correctly")

	health_comp.queue_free()

func test_set_health_direct():
	print("\n--- Testing Direct Health Setting ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.max_health = 100

	# Connect signal to track emissions
	signal_tracker.reset()
	health_comp.health_changed.connect(func(current, max_health): signal_tracker.track_signal("health_changed", [current, max_health]))
	health_comp.died.connect(func(): signal_tracker.track_signal("died"))

	# Test direct health setting
	health_comp.set_health(60)
	assert(health_comp.current_health == 60, "Health should be set directly to 60")
	assert(signal_tracker.was_signal_emitted("health_changed"), "health_changed signal should be emitted")

	# Test setting to 0 (should trigger death)
	signal_tracker.reset()
	health_comp.set_health(0)
	assert(health_comp.current_health == 0, "Health should be set to 0")
	assert(health_comp.is_dead == true, "Should be marked as dead")
	assert(signal_tracker.was_signal_emitted("died"), "died signal should be emitted")
	print("✓ Direct health setting works correctly")

	health_comp.queue_free()

func test_invulnerability_flag():
	print("\n--- Testing Invulnerability Flag ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 100
	health_comp.invulnerable = true

	# Test damage while invulnerable
	var result = health_comp.take_damage(50)
	assert(result == false, "Should return false when invulnerable")
	assert(health_comp.current_health == 100, "Health should not change when invulnerable")
	print("✓ Invulnerability flag works")

	# Test damage when not invulnerable
	health_comp.invulnerable = false
	result = health_comp.take_damage(30)
	assert(result == true, "Should return true when not invulnerable")
	assert(health_comp.current_health == 70, "Health should change when not invulnerable")
	print("✓ Removing invulnerability works")

	health_comp.queue_free()
