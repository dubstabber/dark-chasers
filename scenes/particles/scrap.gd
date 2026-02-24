extends RigidBody3D

var scrap_type: String
var _catalog: ParticleCatalog

var grounded_frame: int
var is_moving: bool = true
var last_texture_change_time: float = 0.0
var texture_change_interval: float = 0.12 # Controlled animation timing
var current_texture_index: int = 0 # Track current texture to avoid immediate repeats
var is_settled: bool = false # Track if particle has settled to prevent further animation
var _process_scrap_behavior: Callable

@onready var sprite_3d: Sprite3D = $Sprite3D

func _ready():
	_catalog = Services.get_particle_catalog()
	# Ensure immediate initialization to prevent spawn delays
	if scrap_type:
		_configure_process_behavior()
		_initialize_texture()

func _process(delta):
	# Skip processing if sprite_3d is not ready yet (fixes spawn delay)
	if not sprite_3d:
		return

	# Skip processing if already settled (prevents unnecessary animation)
	if is_settled:
		return

	last_texture_change_time += delta
	if _process_scrap_behavior.is_valid():
		_process_scrap_behavior.call()

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

	_configure_process_behavior()

	# Initialize texture immediately to prevent spawn delay
	_initialize_texture()


func _configure_process_behavior() -> void:
	if not _catalog:
		_catalog = Services.get_particle_catalog()

	match scrap_type:
		"small wood scrap":
			_process_scrap_behavior = _process_animated_scrap.bind(_catalog.get_textures(&"small_wood"))
		"big wood scrap":
			_process_scrap_behavior = _process_animated_scrap.bind(_catalog.get_textures(&"big_wood"))
		"white scrap":
			_process_scrap_behavior = _process_animated_scrap.bind(_catalog.get_textures(&"white"))
		"pot scrap":
			_process_scrap_behavior = _process_animated_scrap.bind(_catalog.get_textures(&"pot"))
		"circle ground scrap":
			_process_scrap_behavior = _process_ground_scrap.bind(_catalog.get_first_texture(&"circle_ground"), 0.01)
		"small ground scrap":
			_process_scrap_behavior = _process_ground_scrap.bind(_catalog.get_first_texture(&"small_ground"), 0.01)
		"grass scrap":
			_process_scrap_behavior = _process_random_scrap.bind(_catalog.get_textures(&"grass"), 0.05, false)
		"paper scrap":
			_process_scrap_behavior = _process_random_scrap.bind(_catalog.get_textures(&"paper"), 0.05, true)
		"glass scrap":
			_process_scrap_behavior = _process_random_scrap.bind(_catalog.get_textures(&"glass"), 0.05, true)
		_:
			_process_scrap_behavior = Callable()


func _process_animated_scrap(texture_array: Array) -> void:
	_handle_scrap_animation(texture_array)


func _process_ground_scrap(texture: Texture2D, velocity_threshold: float) -> void:
	if _is_above_velocity_threshold(velocity_threshold):
		if sprite_3d.texture != texture:
			sprite_3d.texture = texture
	else:
		queue_free()


func _process_random_scrap(texture_array: Array, velocity_threshold: float, set_once: bool) -> void:
	if _is_above_velocity_threshold(velocity_threshold):
		if texture_array.is_empty():
			return
		if set_once:
			if not sprite_3d.texture:
				sprite_3d.texture = texture_array.pick_random()
		else:
			sprite_3d.texture = texture_array.pick_random()
	else:
		queue_free()


func _is_above_velocity_threshold(threshold: float) -> bool:
	return abs(linear_velocity.x) > threshold or abs(linear_velocity.y) > threshold or abs(linear_velocity.z) > threshold

func _initialize_texture():
	# Get sprite reference immediately if not available
	if not sprite_3d:
		sprite_3d = $Sprite3D

	# Ensure catalog is loaded for set_scrap_type calls before _ready
	if not _catalog:
		_catalog = Services.get_particle_catalog()
	
	# Set initial texture immediately to prevent delay
	if sprite_3d and scrap_type:
		match scrap_type:
			"small wood scrap":
				var textures := _catalog.get_textures(&"small_wood")
				if textures.is_empty():
					return
				current_texture_index = randi() % textures.size()
				sprite_3d.texture = textures[current_texture_index]
			"big wood scrap":
				var textures := _catalog.get_textures(&"big_wood")
				if textures.is_empty():
					return
				current_texture_index = randi() % textures.size()
				sprite_3d.texture = textures[current_texture_index]
			"white scrap":
				var textures := _catalog.get_textures(&"white")
				if textures.is_empty():
					return
				current_texture_index = randi() % textures.size()
				sprite_3d.texture = textures[current_texture_index]
			"pot scrap":
				var textures := _catalog.get_textures(&"pot")
				if textures.is_empty():
					return
				current_texture_index = randi() % textures.size()
				sprite_3d.texture = textures[current_texture_index]
			"circle ground scrap":
				sprite_3d.texture = _catalog.get_first_texture(&"circle_ground")
			"small ground scrap":
				sprite_3d.texture = _catalog.get_first_texture(&"small_ground")
			"grass scrap":
				var textures := _catalog.get_textures(&"grass")
				if textures.is_empty():
					return
				current_texture_index = randi() % textures.size()
				sprite_3d.texture = textures[current_texture_index]
			"paper scrap":
				var textures := _catalog.get_textures(&"paper")
				if textures.is_empty():
					return
				current_texture_index = randi() % textures.size()
				sprite_3d.texture = textures[current_texture_index]
			"glass scrap":
				var textures := _catalog.get_textures(&"glass")
				if textures.is_empty():
					return
				current_texture_index = randi() % textures.size()
				sprite_3d.texture = textures[current_texture_index]

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
