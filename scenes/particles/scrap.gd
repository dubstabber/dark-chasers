extends RigidBody3D

var scrap_type: String
var _catalog: ParticleCatalog

var grounded_frame: int
var is_moving: bool = true
var last_texture_change_time: float = 0.0
var texture_change_interval: float = 0.12 # Controlled animation timing
var current_texture_index: int = 0 # Track current texture to avoid immediate repeats
var is_settled: bool = false # Track if particle has settled to prevent further animation

@onready var sprite_3d = $Sprite3D

func _ready():
	_catalog = Services.preloads.get_particle_catalog()
	# Ensure immediate initialization to prevent spawn delays
	if scrap_type:
		_initialize_texture()

func _process(delta):
	# Skip processing if sprite_3d is not ready yet (fixes spawn delay)
	if not sprite_3d:
		return

	# Skip processing if already settled (prevents unnecessary animation)
	if is_settled:
		return

	last_texture_change_time += delta

	match scrap_type:
		"small wood scrap":
			_handle_scrap_animation(_catalog.small_wood_images)
		"big wood scrap":
			_handle_scrap_animation(_catalog.big_wood_images)
		"white scrap":
			_handle_scrap_animation(_catalog.white_scrap_images)
		"pot scrap":
			_handle_scrap_animation(_catalog.pot_scrap_images)
		"circle ground scrap":
			if abs(linear_velocity.x) > 0.01 or abs(linear_velocity.y) > 0.01 or abs(linear_velocity.z) > 0.01:
				if sprite_3d.texture != _catalog.circle_ground_scrap_image:
					sprite_3d.texture = _catalog.circle_ground_scrap_image
			else:
				queue_free()
		"small ground scrap":
			if abs(linear_velocity.x) > 0.01 or abs(linear_velocity.y) > 0.01 or abs(linear_velocity.z) > 0.01:
				if sprite_3d.texture != _catalog.small_ground_scrap_image:
					sprite_3d.texture = _catalog.small_ground_scrap_image
			else:
				queue_free()
		"grass scrap":
			if abs(linear_velocity.x) > 0.05 or abs(linear_velocity.y) > 0.05 or abs(linear_velocity.z) > 0.05:
				sprite_3d.texture = _catalog.grass_scrap_images.pick_random()
			else:
				queue_free()
		"paper scrap":
			if abs(linear_velocity.x) > 0.05 or abs(linear_velocity.y) > 0.05 or abs(linear_velocity.z) > 0.05:
				if not sprite_3d.texture:
					sprite_3d.texture = _catalog.paper_scrap_images.pick_random()
			else:
				queue_free()
		"glass scrap":
			if abs(linear_velocity.x) > 0.05 or abs(linear_velocity.y) > 0.05 or abs(linear_velocity.z) > 0.05:
				if not sprite_3d.texture:
					sprite_3d.texture = _catalog.glass_scrap_images.pick_random()
			else:
				queue_free()

func set_scrap_type(t):
	scrap_type = t
	match scrap_type:
		"small wood scrap":
			grounded_frame = 3
		"big wood scrap":
			grounded_frame = [2, 4].pick_random()
			if grounded_frame == 2: sprite_3d.position.y = -0.1
		"white scrap":
			grounded_frame = 0
			sprite_3d.position.y = -0.06
		"pot scrap":
			grounded_frame = 6
			sprite_3d.position.y = -0.08
		"circle ground scrap", "small ground scrap":
			sprite_3d.scale = Vector3(3, 3, 3)
		"grass scrap":
			sprite_3d.scale = Vector3(2.5, 2.5, 2.5)
			gravity_scale = 0.5
		"glass scrap":
			sprite_3d.scale = Vector3(0.6, 0.6, 0.6)

	# Initialize texture immediately to prevent spawn delay
	_initialize_texture()

func _initialize_texture():
	# Get sprite reference immediately if not available
	if not sprite_3d:
		sprite_3d = $Sprite3D

	# Ensure catalog is loaded for set_scrap_type calls before _ready
	if not _catalog:
		_catalog = Services.preloads.get_particle_catalog()
	
	# Set initial texture immediately to prevent delay
	if sprite_3d and scrap_type:
		match scrap_type:
			"small wood scrap":
				current_texture_index = randi() % _catalog.small_wood_images.size()
				sprite_3d.texture = _catalog.small_wood_images[current_texture_index]
			"big wood scrap":
				current_texture_index = randi() % _catalog.big_wood_images.size()
				sprite_3d.texture = _catalog.big_wood_images[current_texture_index]
			"white scrap":
				current_texture_index = randi() % _catalog.white_scrap_images.size()
				sprite_3d.texture = _catalog.white_scrap_images[current_texture_index]
			"pot scrap":
				current_texture_index = randi() % _catalog.pot_scrap_images.size()
				sprite_3d.texture = _catalog.pot_scrap_images[current_texture_index]
			"circle ground scrap":
				sprite_3d.texture = _catalog.circle_ground_scrap_image
			"small ground scrap":
				sprite_3d.texture = _catalog.small_ground_scrap_image
			"grass scrap":
				current_texture_index = randi() % _catalog.grass_scrap_images.size()
				sprite_3d.texture = _catalog.grass_scrap_images[current_texture_index]
			"paper scrap":
				current_texture_index = randi() % _catalog.paper_scrap_images.size()
				sprite_3d.texture = _catalog.paper_scrap_images[current_texture_index]
			"glass scrap":
				current_texture_index = randi() % _catalog.glass_scrap_images.size()
				sprite_3d.texture = _catalog.glass_scrap_images[current_texture_index]

func _handle_scrap_animation(texture_array: Array):
	var velocity_threshold = 0.06
	var currently_moving = abs(linear_velocity.x) > velocity_threshold or abs(linear_velocity.y) > velocity_threshold or abs(linear_velocity.z) > velocity_threshold

	# State change: moving to stationary (SETTLE)
	if is_moving and not currently_moving:
		is_moving = false
		is_settled = true # Mark as settled to stop all future animation
		sprite_3d.texture = texture_array[grounded_frame]
		return

	# State change: stationary to moving (START MOVING)
	if not is_moving and currently_moving:
		is_moving = true
		is_settled = false # Allow animation while moving
		last_texture_change_time = 0.0
		current_texture_index = randi() % texture_array.size()
		sprite_3d.texture = texture_array[current_texture_index]
		return

	# While moving: change texture occasionally for animation effect
	if is_moving and not is_settled and last_texture_change_time >= texture_change_interval:
		# Pick a different texture than the current one to avoid repetition
		var new_index = current_texture_index
		if texture_array.size() > 1:
			while new_index == current_texture_index:
				new_index = randi() % texture_array.size()
		current_texture_index = new_index
		sprite_3d.texture = texture_array[current_texture_index]
		last_texture_change_time = 0.0
