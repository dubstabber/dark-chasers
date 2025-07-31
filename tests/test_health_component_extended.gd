extends Node

## Extended unit tests for the HealthComponent system
## Tests invulnerability timers, death/revival, signals, edge cases, and armor integration

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
	print("=== HEALTH COMPONENT EXTENDED TESTS ===")
	signal_tracker = SignalTracker.new()
	
	# Invulnerability Timer Tests
	test_invulnerability_timer()
	
	# Death and Revival Tests
	test_kill_method()
	test_revive_method()
	test_death_with_delay()
	
	# Signal Emission Tests
	test_health_changed_signals()
	test_damage_taken_signals()
	test_healing_signals()
	test_death_signals()
	
	# Edge Cases Tests
	test_zero_and_negative_damage()
	test_zero_and_negative_healing()
	test_overheal_functionality()
	test_multiple_death_calls()
	
	# Armor Integration Tests
	test_armor_integration_basic()
	test_armor_integration_no_armor()
	test_armor_integration_full_absorption()
	
	# Utility Methods Tests
	test_utility_methods()
	
	print("=== ALL EXTENDED HEALTH COMPONENT TESTS COMPLETED ===")

func test_invulnerability_timer():
	print("\n--- Testing Invulnerability Timer ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 100
	health_comp.invulnerability_duration = 1.0
	
	# Take damage to start invulnerability timer
	var result = health_comp.take_damage(10)
	assert(result == true, "First damage should be applied")
	assert(health_comp.current_health == 90, "Health should be reduced")
	assert(health_comp.invulnerability_timer > 0.0, "Invulnerability timer should be active")
	
	# Try to take damage while timer is active
	result = health_comp.take_damage(10)
	assert(result == false, "Damage should be blocked during invulnerability")
	assert(health_comp.current_health == 90, "Health should not change during invulnerability")
	
	# Simulate timer expiration
	health_comp.invulnerability_timer = 0.0
	result = health_comp.take_damage(10)
	assert(result == true, "Damage should be applied after timer expires")
	assert(health_comp.current_health == 80, "Health should be reduced after timer expires")
	print("✓ Invulnerability timer works")
	
	health_comp.queue_free()

func test_kill_method():
	print("\n--- Testing Kill Method ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 100
	
	# Connect signals
	signal_tracker.reset()
	health_comp.died.connect(func(): signal_tracker.track_signal("died"))
	health_comp.health_depleted.connect(func(): signal_tracker.track_signal("health_depleted"))
	
	# Test kill method
	health_comp.kill()
	assert(health_comp.current_health == 0, "Health should be 0 after kill")
	assert(health_comp.is_dead == true, "Should be marked as dead")
	assert(signal_tracker.was_signal_emitted("died"), "died signal should be emitted")
	assert(signal_tracker.was_signal_emitted("health_depleted"), "health_depleted signal should be emitted")
	
	# Test calling kill on already dead entity
	signal_tracker.reset()
	health_comp.kill()
	assert(signal_tracker.get_signal_count("died") == 0, "died signal should not be emitted again")
	print("✓ Kill method works correctly")
	
	health_comp.queue_free()

func test_revive_method():
	print("\n--- Testing Revive Method ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.max_health = 100
	health_comp.current_health = 0
	health_comp.is_dead = true
	
	# Connect signals
	signal_tracker.reset()
	health_comp.health_changed.connect(func(current, max_health): signal_tracker.track_signal("health_changed", [current, max_health]))
	
	# Test revive with default health (max_health)
	health_comp.revive()
	assert(health_comp.is_dead == false, "Should not be dead after revival")
	assert(health_comp.current_health == 100, "Should be revived with max health")
	assert(signal_tracker.was_signal_emitted("health_changed"), "health_changed signal should be emitted")
	
	# Test revive with custom health amount
	health_comp.is_dead = true
	health_comp.current_health = 0
	health_comp.revive(50)
	assert(health_comp.is_dead == false, "Should not be dead after revival")
	assert(health_comp.current_health == 50, "Should be revived with custom health")
	
	# Test revive on living entity (should do nothing)
	var old_health = health_comp.current_health
	health_comp.revive(75)
	assert(health_comp.current_health == old_health, "Health should not change when reviving living entity")
	print("✓ Revive method works correctly")
	
	health_comp.queue_free()

func test_death_with_delay():
	print("\n--- Testing Death with Delay ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 1
	health_comp.destroy_on_death = true
	health_comp.death_delay = 0.1 # Short delay for testing
	
	# Create a parent node to test destruction
	var parent_node = Node.new()
	add_child(parent_node)
	parent_node.add_child(health_comp)
	
	# Kill the entity
	health_comp.kill()
	assert(health_comp.is_dead == true, "Should be marked as dead immediately")
	assert(is_instance_valid(parent_node), "Parent should still exist immediately after death")
	
	# Wait for death delay
	await get_tree().create_timer(0.2).timeout
	assert(not is_instance_valid(parent_node), "Parent should be destroyed after death delay")
	print("✓ Death with delay works correctly")

func test_health_changed_signals():
	print("\n--- Testing Health Changed Signals ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.max_health = 100
	health_comp.current_health = 100
	
	# Connect signal
	signal_tracker.reset()
	health_comp.health_changed.connect(func(current, max_health): signal_tracker.track_signal("health_changed", [current, max_health]))
	
	# Test signal emission on damage
	health_comp.take_damage(25)
	assert(signal_tracker.was_signal_emitted("health_changed"), "health_changed should emit on damage")
	var args = signal_tracker.get_last_args("health_changed")
	assert(args[0] == 75, "Signal should report correct current health")
	assert(args[1] == 100, "Signal should report correct max health")
	
	# Test signal emission on healing
	signal_tracker.reset()
	health_comp.heal(10)
	assert(signal_tracker.was_signal_emitted("health_changed"), "health_changed should emit on healing")
	args = signal_tracker.get_last_args("health_changed")
	assert(args[0] == 85, "Signal should report correct current health after healing")
	
	# Test signal emission on direct health setting
	signal_tracker.reset()
	health_comp.set_health(50)
	assert(signal_tracker.was_signal_emitted("health_changed"), "health_changed should emit on direct health setting")
	args = signal_tracker.get_last_args("health_changed")
	assert(args[0] == 50, "Signal should report correct health after direct setting")
	print("✓ Health changed signals work correctly")
	
	health_comp.queue_free()

func test_damage_taken_signals():
	print("\n--- Testing Damage Taken Signals ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 100

	# Connect signal
	signal_tracker.reset()
	health_comp.damage_taken.connect(func(amount, current): signal_tracker.track_signal("damage_taken", [amount, current]))

	# Test signal emission on damage
	health_comp.take_damage(30)
	assert(signal_tracker.was_signal_emitted("damage_taken"), "damage_taken should emit on damage")
	var args = signal_tracker.get_last_args("damage_taken")
	assert(args[0] == 30, "Signal should report correct damage amount")
	assert(args[1] == 70, "Signal should report correct current health")

	# Test no signal emission when damage is blocked
	signal_tracker.reset()
	health_comp.invulnerable = true
	health_comp.take_damage(20)
	assert(not signal_tracker.was_signal_emitted("damage_taken"), "damage_taken should not emit when invulnerable")
	print("✓ Damage taken signals work correctly")

	health_comp.queue_free()

func test_healing_signals():
	print("\n--- Testing Healing Signals ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 50
	health_comp.max_health = 100

	# Connect signal
	signal_tracker.reset()
	health_comp.healed.connect(func(amount, current): signal_tracker.track_signal("healed", [amount, current]))

	# Test signal emission on healing
	health_comp.heal(25)
	assert(signal_tracker.was_signal_emitted("healed"), "healed should emit on healing")
	var args = signal_tracker.get_last_args("healed")
	assert(args[0] == 25, "Signal should report correct healing amount")
	assert(args[1] == 75, "Signal should report correct current health")

	# Test no signal emission when healing is not applied
	signal_tracker.reset()
	health_comp.current_health = 100 # Full health
	health_comp.heal(10)
	assert(not signal_tracker.was_signal_emitted("healed"), "healed should not emit when at full health")

	# Test no signal emission when dead
	signal_tracker.reset()
	health_comp.is_dead = true
	health_comp.heal(20)
	assert(not signal_tracker.was_signal_emitted("healed"), "healed should not emit when dead")
	print("✓ Healing signals work correctly")

	health_comp.queue_free()

func test_death_signals():
	print("\n--- Testing Death Signals ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 10

	# Connect signals
	signal_tracker.reset()
	health_comp.died.connect(func(): signal_tracker.track_signal("died"))
	health_comp.health_depleted.connect(func(): signal_tracker.track_signal("health_depleted"))

	# Test death signals on lethal damage
	health_comp.take_damage(15)
	assert(signal_tracker.was_signal_emitted("died"), "died signal should emit on death")
	assert(signal_tracker.was_signal_emitted("health_depleted"), "health_depleted signal should emit on death")

	# Test no duplicate signals on subsequent death calls
	signal_tracker.reset()
	health_comp.take_damage(10) # Already dead, should not emit again
	assert(not signal_tracker.was_signal_emitted("died"), "died signal should not emit again")
	assert(not signal_tracker.was_signal_emitted("health_depleted"), "health_depleted signal should not emit again")
	print("✓ Death signals work correctly")

	health_comp.queue_free()

func test_zero_and_negative_damage():
	print("\n--- Testing Zero and Negative Damage ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 100

	# Connect signal
	signal_tracker.reset()
	health_comp.damage_taken.connect(func(amount, current): signal_tracker.track_signal("damage_taken", [amount, current]))

	# Test zero damage
	var result = health_comp.take_damage(0)
	assert(result == false, "Zero damage should return false")
	assert(health_comp.current_health == 100, "Health should not change with zero damage")
	assert(not signal_tracker.was_signal_emitted("damage_taken"), "damage_taken should not emit for zero damage")

	# Test negative damage
	result = health_comp.take_damage(-10)
	assert(result == false, "Negative damage should return false")
	assert(health_comp.current_health == 100, "Health should not change with negative damage")
	assert(not signal_tracker.was_signal_emitted("damage_taken"), "damage_taken should not emit for negative damage")
	print("✓ Zero and negative damage handled correctly")

	health_comp.queue_free()

func test_zero_and_negative_healing():
	print("\n--- Testing Zero and Negative Healing ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 50
	health_comp.max_health = 100

	# Connect signal
	signal_tracker.reset()
	health_comp.healed.connect(func(amount, current): signal_tracker.track_signal("healed", [amount, current]))

	# Test zero healing
	var result = health_comp.heal(0)
	assert(result == false, "Zero healing should return false")
	assert(health_comp.current_health == 50, "Health should not change with zero healing")
	assert(not signal_tracker.was_signal_emitted("healed"), "healed should not emit for zero healing")

	# Test negative healing
	result = health_comp.heal(-10)
	assert(result == false, "Negative healing should return false")
	assert(health_comp.current_health == 50, "Health should not change with negative healing")
	assert(not signal_tracker.was_signal_emitted("healed"), "healed should not emit for negative healing")
	print("✓ Zero and negative healing handled correctly")

	health_comp.queue_free()

func test_overheal_functionality():
	print("\n--- Testing Overheal Functionality ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.max_health = 100
	health_comp.current_health = 100
	health_comp.can_overheal = true
	health_comp.overheal_limit = 150

	# Connect signal
	signal_tracker.reset()
	health_comp.healed.connect(func(amount, current): signal_tracker.track_signal("healed", [amount, current]))

	# Test overhealing
	var result = health_comp.heal(30)
	assert(result == true, "Overhealing should work when enabled")
	assert(health_comp.current_health == 130, "Health should exceed max when overhealing")
	assert(signal_tracker.was_signal_emitted("healed"), "healed signal should emit on overheal")

	# Test overheal limit
	result = health_comp.heal(30)
	assert(health_comp.current_health == 150, "Health should be capped at overheal limit")

	# Test overhealing when disabled
	health_comp.can_overheal = false
	health_comp.current_health = 100
	result = health_comp.heal(20)
	assert(result == false, "Healing should fail when at max health and overheal disabled")
	assert(health_comp.current_health == 100, "Health should not exceed max when overheal disabled")
	print("✓ Overheal functionality works correctly")

	health_comp.queue_free()

func test_multiple_death_calls():
	print("\n--- Testing Multiple Death Calls ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 1

	# Connect signals
	signal_tracker.reset()
	health_comp.died.connect(func(): signal_tracker.track_signal("died"))
	health_comp.health_depleted.connect(func(): signal_tracker.track_signal("health_depleted"))

	# First death
	health_comp.kill()
	assert(health_comp.is_dead == true, "Should be dead after first kill")
	assert(signal_tracker.get_signal_count("died") == 1, "died signal should emit once")
	assert(signal_tracker.get_signal_count("health_depleted") == 1, "health_depleted signal should emit once")

	# Subsequent death calls should not emit signals again
	signal_tracker.reset()
	health_comp.kill()
	health_comp.take_damage(100)
	assert(signal_tracker.get_signal_count("died") == 0, "died signal should not emit again")
	assert(signal_tracker.get_signal_count("health_depleted") == 0, "health_depleted signal should not emit again")
	print("✓ Multiple death calls handled correctly")

	health_comp.queue_free()

func test_armor_integration_basic():
	print("\n--- Testing Basic Armor Integration ---")

	# Create a parent node to hold both components
	var parent_node = Node.new()
	add_child(parent_node)

	# Create health component
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	parent_node.add_child(health_comp)
	health_comp.current_health = 100
	health_comp.max_health = 100

	# Create armor component
	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	parent_node.add_child(armor_comp)
	armor_comp.current_armor = 50
	armor_comp.max_armor = 50
	# Use the enum value directly - ABSORPTION = 2 based on the enum definition
	armor_comp.damage_reduction_type = 2 # DamageReductionType.ABSORPTION

	# Test damage with armor
	var result = health_comp.take_damage(30)
	assert(result == true, "Damage should be applied")
	assert(health_comp.current_health == 100, "Health should not be reduced when armor absorbs damage")
	assert(armor_comp.current_armor == 20, "Armor should be reduced by damage amount")

	# Test damage that exceeds armor
	result = health_comp.take_damage(30)
	assert(health_comp.current_health == 90, "Health should be reduced by overflow damage")
	assert(armor_comp.current_armor == 0, "Armor should be depleted")
	print("✓ Basic armor integration works correctly")

	parent_node.queue_free()

func test_armor_integration_no_armor():
	print("\n--- Testing Armor Integration Without Armor Component ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 100

	# Test damage without armor component (should work normally)
	var result = health_comp.take_damage(25)
	assert(result == true, "Damage should be applied normally without armor")
	assert(health_comp.current_health == 75, "Health should be reduced by full damage amount")
	print("✓ Health component works correctly without armor")

	health_comp.queue_free()

func test_armor_integration_full_absorption():
	print("\n--- Testing Full Armor Absorption ---")

	# Create a parent node to hold both components
	var parent_node = Node.new()
	add_child(parent_node)

	# Create health component
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	parent_node.add_child(health_comp)
	health_comp.current_health = 100

	# Create armor component with high armor
	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	parent_node.add_child(armor_comp)
	armor_comp.current_armor = 100
	# Use the enum value directly - ABSORPTION = 2 based on the enum definition
	armor_comp.damage_reduction_type = 2 # DamageReductionType.ABSORPTION

	# Test damage that is fully absorbed
	var result = health_comp.take_damage(50)
	assert(result == true, "Damage should be applied")
	assert(health_comp.current_health == 100, "Health should remain unchanged")
	assert(armor_comp.current_armor == 50, "Armor should absorb all damage")

	# Test exact armor depletion
	result = health_comp.take_damage(50)
	assert(health_comp.current_health == 100, "Health should still be unchanged")
	assert(armor_comp.current_armor == 0, "Armor should be exactly depleted")
	print("✓ Full armor absorption works correctly")

	parent_node.queue_free()

func test_utility_methods():
	print("\n--- Testing Utility Methods ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.max_health = 100
	health_comp.current_health = 75

	# Test get_health_percentage
	var percentage = health_comp.get_health_percentage()
	assert(percentage == 0.75, "Health percentage should be 0.75 for 75/100 health")

	# Test is_at_full_health
	assert(health_comp.is_at_full_health() == false, "Should not be at full health")
	health_comp.current_health = 100
	assert(health_comp.is_at_full_health() == true, "Should be at full health")

	# Test is_alive
	assert(health_comp.is_alive() == true, "Should be alive with health > 0")
	health_comp.current_health = 0
	assert(health_comp.is_alive() == false, "Should not be alive with 0 health")
	health_comp.is_dead = true
	health_comp.current_health = 50
	assert(health_comp.is_alive() == false, "Should not be alive when marked as dead")

	# Test edge cases
	health_comp.max_health = 1
	health_comp.current_health = 1
	health_comp.is_dead = false
	percentage = health_comp.get_health_percentage()
	assert(percentage == 1.0, "Health percentage should be 1.0 for full health")

	print("✓ Utility methods work correctly")

	health_comp.queue_free()
