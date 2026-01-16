extends Decal

## This decal is spawned when an enemy is shot and there's a wall behind them.
## The color can be customized per-enemy (e.g., blue for AoOni, red for normal enemies).

const BLOOD_SPLAT_IMAGES := [
	preload("res://images/particles/bsplat1.png"),
	preload("res://images/particles/bsplat2.png"),
	preload("res://images/particles/bsplat3.png"),
	preload("res://images/particles/bsplat4.png"),
	preload("res://images/particles/bsplat5.png"),
	preload("res://images/particles/bsplat6.png"),
	preload("res://images/particles/bsplat7.png"),
]

const BLOOD_SPLAT_WEIGHTS := [2, 1, 5, 5, 5, 5, 6]

var _selected_texture: Texture2D
var _pending_color: Color = Color(-1, -1, -1, -1)


func _ready() -> void:
	_selected_texture = _get_weighted_random_splat()
	
	# Apply pending color if set_blood_color was called before _ready
	if _pending_color.r >= 0:
		texture_albedo = _create_colored_texture(_selected_texture, _pending_color)
	else:
		texture_albedo = _selected_texture
	
	# Random rotation for variety (replaces flip_h/flip_v from Sprite3D)
	# Decals don't have flip properties, so we rotate in 90-degree increments
	var random_rotation := randi() % 4
	rotate_y(random_rotation * PI / 2.0)


func _get_weighted_random_splat() -> Texture2D:
	"""Select a blood splat image using weighted random selection"""
	var total_weight := 0
	for weight in BLOOD_SPLAT_WEIGHTS:
		total_weight += weight
	
	var random_value := randi() % total_weight
	var cumulative := 0
	
	for i in range(BLOOD_SPLAT_WEIGHTS.size()):
		cumulative += BLOOD_SPLAT_WEIGHTS[i]
		if random_value < cumulative:
			return BLOOD_SPLAT_IMAGES[i]
	
	return BLOOD_SPLAT_IMAGES[0]


func set_blood_color(color: Color) -> void:
	var dimmed_color := Color(
		color.r * 0.5,
		color.g * 0.5,
		color.b * 0.5,
		1.0
	)
	
	# If _ready hasn't run yet, store color to apply later
	if not _selected_texture:
		_pending_color = dimmed_color
		return
	
	# Create a recolored texture since modulate only multiplies RGB
	# and can't change hue (e.g., blue to red)
	texture_albedo = _create_colored_texture(_selected_texture, dimmed_color)


func _create_colored_texture(source: Texture2D, target_color: Color) -> ImageTexture:
	var img := source.get_image()
	if img == null:
		return null
	
	img = img.duplicate()
	
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var pixel := img.get_pixel(x, y)
			# Extract luminance (brightness) from original pixel
			var luminance := maxf(maxf(pixel.r, pixel.g), pixel.b)
			# Apply target color with original luminance
			var new_color := Color(
				target_color.r * luminance,
				target_color.g * luminance,
				target_color.b * luminance,
				pixel.a
			)
			img.set_pixel(x, y, new_color)
	
	return ImageTexture.create_from_image(img)
