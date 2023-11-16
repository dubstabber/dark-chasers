extends CharacterBody3D

const SPEED = 5.0
const ACCEL = 10

@export var specific_enemy: String

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var enemy_data: Dictionary
var direction: Vector3
var jump_speed: float = 0

@onready var nav := $NavigationAgent3D
@onready var image := $Sprite3D
@onready var find_path_timer := $FindPathTimer
@onready var sound_music := $SoundMusic


func _ready():
	target = get_tree().get_first_node_in_group("player")
	if specific_enemy:
		for enemy in EnemyDb.ENEMIES:
			if enemy.name == specific_enemy:
				enemy_data = enemy
				image.texture = enemy_data.image
				break
	if !enemy_data:
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
	if target:
		direction = (nav.get_next_path_position() - global_position).normalized()
		velocity = velocity.lerp(direction * (SPEED + jump_speed), ACCEL * delta)
		move_and_slide()


func makepath() -> void:
	if !!target:
		nav.target_position = target.global_position


func _on_find_path_timer_timeout():
	var distance_to_target = nav.distance_to_target()
	if distance_to_target < 5:
		find_path_timer.wait_time = 0.1
	elif distance_to_target < 10:
		find_path_timer.wait_time = 0.6
	elif distance_to_target < 20:
		find_path_timer.wait_time = 1.0
	elif distance_to_target < 50:
		find_path_timer.wait_time = 2.0
	else:
		find_path_timer.wait_time = 4.0
	makepath()


func _draw_music():
	sound_music.stream = enemy_data.musics.pick_random()
	sound_music.play()


func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		body.kill(position)
		target = null


func _on_navigation_agent_3d_link_reached(details):
	if details.owner.is_in_group("jump-up"):
		velocity.y = 12
		jump_speed = gravity
	if details.owner.is_in_group("jump-down"):
		jump_speed = gravity


func _on_navigation_agent_3d_waypoint_reached(_details):
	jump_speed = 0
