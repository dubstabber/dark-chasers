extends Sprite3D


func _ready() -> void:
	texture = Preloads.DOOM_DECAL_IMAGES[randi() % Preloads.DOOM_DECAL_IMAGES.size()]