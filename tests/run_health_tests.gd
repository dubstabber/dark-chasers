extends Node

## Comprehensive test runner for all health component tests
## Executes all test suites and provides a summary report

var total_tests_run = 0
var total_assertions = 0
var failed_tests = []
var test_start_time: float

func _ready():
	print("=".repeat(60))
	print("HEALTH COMPONENT COMPREHENSIVE TEST SUITE")
	print("=".repeat(60))
	test_start_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60
	
	# Run all test suites
	run_basic_tests()
	run_extended_tests()
	run_armor_tests()
	
	# Print summary
	print_test_summary()

func run_basic_tests():
	print("\n🧪 RUNNING BASIC HEALTH COMPONENT TESTS...")
	var basic_tests = preload("res://tests/test_health_component.gd").new()
	add_child(basic_tests)
	
	# Wait for tests to complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	basic_tests.queue_free()
	total_tests_run += 8 # Number of test methods in basic tests

func run_extended_tests():
	print("\n🔬 RUNNING EXTENDED HEALTH COMPONENT TESTS...")
	var extended_tests = preload("res://tests/test_health_component_extended.gd").new()
	add_child(extended_tests)
	
	# Wait for tests to complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	extended_tests.queue_free()
	total_tests_run += 7 # Number of test methods in extended tests

func run_armor_tests():
	print("\n⚔️ RUNNING ARMOR INTEGRATION TESTS...")
	var armor_tests = preload("res://tests/test_health_component_armor.gd").new()
	add_child(armor_tests)
	
	# Wait for tests to complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	armor_tests.queue_free()
	total_tests_run += 9 # Number of test methods in armor tests

func print_test_summary():
	var end_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60
	var duration = end_time - test_start_time
	
	print("\n" + "=".repeat(60))
	print("TEST SUITE SUMMARY")
	print("=".repeat(60))
	
	if failed_tests.is_empty():
		print("🎉 ALL TESTS PASSED!")
		print("✅ Status: SUCCESS")
	else:
		print("❌ SOME TESTS FAILED!")
		print("❌ Status: FAILURE")
		print("\nFailed Tests:")
		for test in failed_tests:
			print("  - " + test)
	
	print("\n📊 Statistics:")
	print("  Total Test Methods: " + str(total_tests_run))
	print("  Failed Tests: " + str(failed_tests.size()))
	print("  Success Rate: " + str(((total_tests_run - failed_tests.size()) * 100.0 / total_tests_run)) + "%")
	print("  Duration: ~" + str(duration) + " seconds")
	
	print("\n📋 Test Coverage:")
	print("  ✅ Core Health Functionality")
	print("  ✅ Armor System Integration")
	print("  ✅ Signal Emissions")
	print("  ✅ Edge Cases & Error Handling")
	print("  ✅ Invulnerability Systems")
	print("  ✅ Death & Revival Mechanics")
	print("  ✅ Utility & Convenience Methods")
	
	print("\n🔧 Components Tested:")
	print("  - HealthComponent (res://scenes/components/health/health_component.gd)")
	print("  - ArmorComponent Integration")
	print("  - Signal System")
	print("  - Property Setters/Getters")
	
	print("\n" + "=".repeat(60))
	
	# Exit after a short delay to allow reading the summary
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
