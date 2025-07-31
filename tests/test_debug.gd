extends Node

func _ready():
	print("=== DEBUG TEST ===")

	# Test just the basic health component first
	print("Creating health component...")
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	print("Health component loaded")

	add_child(health_comp)
	print("Health component added to scene")

	health_comp.current_health = 100
	health_comp.max_health = 100
	print("Health values set: ", health_comp.current_health, "/", health_comp.max_health)

	# Test basic damage without any sounds or complex features
	print("Testing damage...")
	var result = health_comp.take_damage(25)
	print("Damage applied. Result: ", result)
	print("Health after damage: ", health_comp.current_health)

	health_comp.queue_free()
	print("✓ Basic test completed successfully")

	print("=== DEBUG TEST COMPLETED ===")
	get_tree().quit()
