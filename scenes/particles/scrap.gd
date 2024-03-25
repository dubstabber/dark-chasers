extends RigidBody3D

var scrap_type: String
var grounded_frame: int

@onready var sprite_3d = $Sprite3D


func _process(_delta):
	match scrap_type:
		"small wood scrap":
			if abs(linear_velocity.x) > 0.06 or abs(linear_velocity.y) > 0.06 or abs(linear_velocity.z) > 0.06:
				sprite_3d.texture = Preloads.SMALL_WOOD_IMAGES.pick_random()
			elif sprite_3d.texture != Preloads.SMALL_WOOD_IMAGES[grounded_frame]:
				sprite_3d.texture = Preloads.SMALL_WOOD_IMAGES[grounded_frame]
		"big wood scrap":
			if abs(linear_velocity.x) > 0.06 or abs(linear_velocity.y) > 0.06 or abs(linear_velocity.z) > 0.06:
				sprite_3d.texture = Preloads.BIG_WOOD_IMAGES.pick_random()
			elif sprite_3d.texture != Preloads.BIG_WOOD_IMAGES[grounded_frame]:
				sprite_3d.texture = Preloads.BIG_WOOD_IMAGES[grounded_frame]
		"white scrap":
			if abs(linear_velocity.x) > 0.06 or abs(linear_velocity.y) > 0.06 or abs(linear_velocity.z) > 0.06:
				sprite_3d.texture = Preloads.WHITE_SCRAP_IMAGES.pick_random()
			elif sprite_3d.texture != Preloads.WHITE_SCRAP_IMAGES[grounded_frame]:
				sprite_3d.texture = Preloads.WHITE_SCRAP_IMAGES[grounded_frame]
		"pot scrap":
			if abs(linear_velocity.x) > 0.06 or abs(linear_velocity.y) > 0.06 or abs(linear_velocity.z) > 0.06:
				sprite_3d.texture = Preloads.POT_SCRAP_IMAGES.pick_random()
			elif sprite_3d.texture != Preloads.POT_SCRAP_IMAGES[grounded_frame]:
				sprite_3d.texture = Preloads.POT_SCRAP_IMAGES[grounded_frame]
				

func set_scrap_type(t):
	scrap_type = t
	match scrap_type:
		"small wood scrap":
			grounded_frame = 3
		"big wood scrap":
			grounded_frame = [2,4].pick_random()
			if grounded_frame == 2: sprite_3d.position.y = -0.1
		"white scrap":
			grounded_frame = 0
			sprite_3d.position.y = -0.06
		"pot scrap":
			grounded_frame = 6
			sprite_3d.position.y = -0.08
