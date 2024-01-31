extends Enemy

@export var specific_enemy: String

var enemy_data: Dictionary

@onready var image = $RotationController/Sprite3D
@onready var sound_music = $SoundMusic


func _ready():
	super._ready()
	if not speed: speed = 8.0
	accel = 10
	if specific_enemy:
		for enemy in EnemyDb.ENEMIES:
			if enemy.name == specific_enemy:
				enemy_data = enemy
				image.texture = enemy_data.image
				break
	if not enemy_data:
		enemy_data = EnemyDb.ENEMIES.pick_random()
		image.texture = enemy_data.image
	var sizeto = 300
	var size = image.texture.get_size()
	if size.x > sizeto or size.y > sizeto or size.x <= sizeto or size.y <= sizeto:
		var sizeIt = size.x if size.x > size.y else size.y
		var scalefactor = sizeto / sizeIt
		image.scale = Vector3(scalefactor, scalefactor, 1)
	if "music" in enemy_data:
		sound_music.stream = enemy_data.music
		sound_music.play()
	elif "musics" in enemy_data:
		sound_music.connect("finished", _draw_music)
		_draw_music()


func _physics_process(delta):
	super._physics_process(delta)


func _draw_music():
	sound_music.stream = enemy_data.musics.pick_random()
	sound_music.play()

