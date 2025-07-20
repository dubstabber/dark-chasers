extends Camera3D

## Simple camera controller for testing DirectionalSprite3D
## Use WASD to orbit around the target, QE to move up/down

@export var target: Node3D
@export var orbit_speed: float = 2.0
@export var orbit_distance: float = 5.0
@export var vertical_speed: float = 2.0

var orbit_angle: float = 0.0
var vertical_offset: float = 2.0

func _ready():
	if target == null:
		# Try to find a target node
		if get_parent().has_node("TestTarget"):
			target = get_parent().get_node("TestTarget")
		else:
			# For comparison scene, use the center point between sprites
			target = get_parent()

func _process(delta):
	if target == null:
		return
	
	# Handle input
	var horizontal_input = 0.0
	var vertical_input = 0.0
	
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("move_left"):
		horizontal_input -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right"):
		horizontal_input += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_forward"):
		vertical_input += 1.0
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_backward"):
		vertical_input -= 1.0
	
	# Update orbit angle
	orbit_angle += horizontal_input * orbit_speed * delta
	
	# Update vertical offset
	vertical_offset += vertical_input * vertical_speed * delta
	vertical_offset = clamp(vertical_offset, 0.5, 8.0)
	
	# Calculate camera position
	var target_pos = target.global_position
	var camera_pos = Vector3(
		target_pos.x + cos(orbit_angle) * orbit_distance,
		target_pos.y + vertical_offset,
		target_pos.z + sin(orbit_angle) * orbit_distance
	)

	# Set camera position and look at target
	global_position = camera_pos
	look_at(target_pos, Vector3.UP)

	# Debug output for billboard testing
	if Input.is_action_just_pressed("ui_accept"):
		var sprite = target.get_node("DirectionalSprite3D")
		if sprite:
			print("Camera angle: ", rad_to_deg(orbit_angle))
			print("Camera position: ", camera_pos)
			print("Target position: ", target_pos)
			print("Billboard enabled: ", sprite.billboard != 0)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				# Reset camera position
				orbit_angle = 0.0
				vertical_offset = 2.0
			KEY_B:
				# Toggle billboard mode for testing
				var sprite = null
				if target and target.has_node("DirectionalSprite3D"):
					sprite = target.get_node("DirectionalSprite3D")
				elif get_parent().has_node("DirectionalSprite3D"):
					sprite = get_parent().get_node("DirectionalSprite3D")

				if sprite:
					if sprite.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
						sprite.billboard = 2 # Y-axis billboard
						print("DirectionalSprite3D Billboard enabled (Y-axis)")
					else:
						sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
						print("DirectionalSprite3D Billboard disabled")
			KEY_ESCAPE:
				get_tree().quit()
