extends Enemy

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
		enemy_data = EnemyDb.get_by_name(specific_enemy)
	if not enemy_data:
		enemy_data = EnemyDb.get_random()
	
	image.texture = enemy_data.image
	
	# Scale image to target size
	var sizeto = 300
	var size = image.texture.get_size()
	if size.x > sizeto or size.y > sizeto or size.x <= sizeto or size.y <= sizeto:
		var sizeIt = size.x if size.x > size.y else size.y
		var scalefactor = sizeto / sizeIt
		image.scale = Vector3(scalefactor, scalefactor, 1)
	
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
