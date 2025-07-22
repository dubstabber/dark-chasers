extends CharacterBody3D

## Test character to demonstrate DirectionalSprite3D functionality

@export var speed: float = 5.0
@export var moving_state: bool = false

func _ready():
	print("Test character ready. Use WASD to move and see directional sprites change.")

func _physics_process(_delta):
	# Handle input
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		moving_state = true
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		moving_state = false
	
	move_and_slide()
	
	# Print debug info
	if Input.is_action_just_pressed("ui_accept"):
		var sprite = $DirectionalSprite3D
		sprite.debug_atlas_info()
