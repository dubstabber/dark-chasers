@tool
extends Node3D

## Test script for DirectionalSprite3D component
## This script helps validate the different directional modes

@export var test_mode: DirectionalSprite3D.DirectionMode = DirectionalSprite3D.DirectionMode.THREE_DIRECTIONS:
	set(value):
		test_mode = value
		_update_test_mode()

@export var moving_state: bool = false:
	set(value):
		moving_state = value
		_update_moving_state()

var directional_sprite: DirectionalSprite3D

func _ready():
	_setup_directional_sprite()
	_update_test_mode()

func _setup_directional_sprite():
	# Find or create DirectionalSprite3D
	directional_sprite = get_node_or_null("DirectionalSprite3D")
	if directional_sprite == null:
		directional_sprite = DirectionalSprite3D.new()
		directional_sprite.name = "DirectionalSprite3D"
		add_child(directional_sprite)
	
	# Set target node path to self
	directional_sprite.target_node_path = NodePath(".")

func _update_test_mode():
	if directional_sprite == null:
		return
	
	directional_sprite.direction_mode = test_mode
	print("DirectionalSprite3D test mode set to: ", DirectionalSprite3D.DirectionMode.keys()[test_mode])

func _update_moving_state():
	# This property will be read by DirectionalSprite3D to determine animation state
	pass

func get_moving_state() -> bool:
	return moving_state

# Test function to print current direction calculation
func test_direction_calculation():
	if directional_sprite == null:
		return
	
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		print("No camera found for direction test")
		return
	
	var calculated_direction = directional_sprite._calculate_camera_direction(camera, self)
	print("Current calculated direction: ", calculated_direction)
	print("Current mode: ", DirectionalSprite3D.DirectionMode.keys()[test_mode])
	print("Moving state: ", moving_state)
