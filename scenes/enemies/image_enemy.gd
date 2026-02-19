extends Enemy

## Target size for enemy sprite scaling (in pixels)
const TARGET_SPRITE_SIZE := 300

@export var specific_enemy: String

var enemy_data: EnemyDefinition

@onready var image = $Graphics/Sprite3D
@onready var sound_music = $SoundMusic


func _ready():
	super._ready()
	
	if not speed: speed = 8.0
	accel = 10
	
	# Get enemy definition by name or pick random
	if specific_enemy:
		enemy_data = Services.enemy_db.get_by_name(specific_enemy)
	if not enemy_data:
		enemy_data = Services.enemy_db.get_random()
	
	image.texture = enemy_data.image
	
	# Scale image to target size (always scale to normalize enemy sizes)
	var size = image.texture.get_size()
	var largest_dimension = maxf(size.x, size.y)
	if largest_dimension > 0:
		var scale_factor = TARGET_SPRITE_SIZE / largest_dimension
		image.scale = Vector3(scale_factor, scale_factor, 1)
	
	# Set up music
	if enemy_data.has_music():
		sound_music.stream = enemy_data.music
		sound_music.play()
	elif enemy_data.has_playlist():
		sound_music.connect("finished", _draw_music)
		_draw_music()


func _physics_process(delta):
	super._physics_process(delta)


func _draw_music():
	sound_music.stream = enemy_data.get_random_music()
	sound_music.play()
