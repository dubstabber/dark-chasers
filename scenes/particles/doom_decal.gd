extends Decal


func _ready() -> void:
	texture_albedo = Preloads.DOOM_DECAL_IMAGES[randi() % Preloads.DOOM_DECAL_IMAGES.size()]
