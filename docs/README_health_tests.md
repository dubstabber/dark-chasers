# Health Component Test Suite

This directory contains comprehensive unit tests for the HealthComponent system in the Dark Chasers project. The tests cover all aspects of the health system including core functionality, armor integration, signals, and edge cases.

## Test Files

### 1. `test_health_component.gd` - Core Health Functionality Tests
- **Health Initialization**: Default and custom values
- **Basic Damage Taking**: Health reduction and clamping
- **Basic Healing**: Health restoration and clamping
- **Health Percentage Calculation**: Accurate percentage calculations
- **Death Detection**: Proper death state transitions
- **Property Setters**: max_health and current_health setters
- **Direct Health Setting**: set_health() method functionality
- **Invulnerability Flag**: Damage blocking when invulnerable

### 2. `test_health_component_extended.gd` - Advanced Features Tests
- **Invulnerability Timer**: Time-based damage immunity
- **Kill Method**: Instant death functionality
- **Revive Method**: Resurrection with custom health amounts
- **Death with Delay**: Delayed destruction functionality
- **Signal Emissions**: All health-related signals (health_changed, damage_taken, healed, died, health_depleted)
- **Signal Parameters**: Correct parameter passing in signals

### 3. `test_health_component_armor.gd` - Armor Integration & Edge Cases
- **Zero/Negative Damage**: Invalid input handling
- **Zero/Negative Healing**: Invalid input handling
- **Overheal Functionality**: Health exceeding maximum with limits
- **Multiple Death Calls**: Prevention of duplicate death processing
- **Armor Integration**: All armor types (ABSORPTION, DOOM_GREEN, DOOM_BLUE)
- **Utility Methods**: Helper functions and convenience methods

## How to Run Tests

### Method 1: Using the Test Runner Scene (Recommended)
1. Open Godot Editor
2. Navigate to `tests/test_health_component_runner.tscn`
3. Run the scene (F6 or click the play scene button)
4. Check the output console for test results

### Method 2: Running Individual Test Files
1. Open Godot Editor
2. Create a new scene with a Node as root
3. Attach one of the test scripts to the root node:
   - `test_health_component.gd`
   - `test_health_component_extended.gd`
   - `test_health_component_armor.gd`
4. Run the scene
5. Check the output console for test results

### Method 3: Adding Tests to Existing Scene
1. Add a Node to any existing scene
2. Attach one of the test scripts to the node
3. The tests will run automatically when the scene starts

## Test Coverage

### Core Health Functionality ✅
- [x] Health initialization with default and custom values
- [x] Taking damage and health reduction
- [x] Healing and health restoration
- [x] Health clamping (not exceeding maximum, not going below zero)
- [x] Death state detection and transitions

### Armor System Integration ✅
- [x] Damage reduction calculations when armor is present
- [x] Armor value modifications and their effects on damage
- [x] Edge cases where armor reduces damage to zero or negative values
- [x] Integration with all armor types (ABSORPTION, DOOM_GREEN, DOOM_BLUE)
- [x] Interaction between health and armor components

### Signal Emissions ✅
- [x] Health changed signals with correct parameters
- [x] Death/alive state change signals
- [x] Damage taken signals
- [x] Healing signals
- [x] Signal emission prevention for invalid operations

### Edge Cases ✅
- [x] Zero health scenarios
- [x] Maximum health scenarios
- [x] Invalid input handling (negative damage/healing values)
- [x] Component initialization edge cases
- [x] Multiple death call prevention
- [x] Overheal functionality and limits
- [x] Invulnerability (flag and timer-based)

## Test Results Interpretation

### Successful Test Output
```
=== HEALTH COMPONENT COMPREHENSIVE TESTS ===

--- Testing Health Initialization (Default Values) ---
✓ Default initialization values correct

--- Testing Health Initialization (Custom Values) ---
✓ Custom initialization values correct

[... more test results ...]

=== ALL HEALTH COMPONENT TESTS COMPLETED ===
```

### Failed Test Output
If a test fails, you'll see an assertion error with details:
```
--- Testing Basic Damage Taking ---
SCRIPT ERROR: Assertion failed.
   at: test_take_damage_basic (res://tests/test_health_component.gd:123)
```

## Test Architecture

### SignalTracker Helper Class
Each test file includes a `SignalTracker` helper class that:
- Tracks signal emissions and counts
- Stores signal parameters for verification
- Provides methods to check if signals were emitted
- Can be reset between tests

### Test Structure
Each test method follows this pattern:
1. **Setup**: Create component instances and configure them
2. **Action**: Perform the operation being tested
3. **Assertion**: Verify the expected results
4. **Cleanup**: Free component instances

### Component Creation Pattern
Tests create components using:
```gdscript
var health_comp = preload("res://scenes/components/health/health_component.gd").new()
add_child(health_comp)
```

For armor integration tests, both components are added to a parent node:
```gdscript
var parent_node = Node.new()
add_child(parent_node)
parent_node.add_child(health_comp)
parent_node.add_child(armor_comp)
```

## Adding New Tests

To add new tests:

1. **Choose the appropriate test file** based on the functionality being tested
2. **Add a new test method** following the naming convention `test_feature_name()`
3. **Add the method call** to the `_ready()` function
4. **Follow the test structure pattern** (Setup, Action, Assertion, Cleanup)
5. **Use descriptive assertion messages** to help with debugging

Example:
```gdscript
func test_new_feature():
    print("\n--- Testing New Feature ---")
    
    var health_comp = preload("res://scenes/components/health/health_component.gd").new()
    add_child(health_comp)
    
    # Test setup
    health_comp.some_property = some_value
    
    # Test action
    var result = health_comp.some_method()
    
    # Test assertions
    assert(result == expected_value, "Feature should work as expected")
    assert(health_comp.some_property == expected_state, "Property should be in expected state")
    
    print("✓ New feature works correctly")
    
    health_comp.queue_free()
```

## Troubleshooting

### Common Issues

1. **Tests not running**: Make sure the test script is attached to a Node in the scene
2. **Assertion failures**: Check the console output for specific error messages
3. **Signal not detected**: Ensure signals are connected before the action that should emit them
4. **Component not found**: Verify the component paths in preload statements

### Debug Tips

1. Add `print()` statements to see intermediate values
2. Use `assert()` with descriptive messages
3. Check that components are properly initialized before testing
4. Verify signal connections are established correctly

## Integration with CI/CD

These tests can be integrated into automated testing pipelines by:
1. Running Godot in headless mode
2. Loading and executing the test scenes
3. Parsing console output for test results
4. Failing the build if any assertions fail

Example command:
```bash
godot --headless --script tests/test_health_component.gd
```
