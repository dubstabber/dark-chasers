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


func _ready() -> void:
	texture_albedo = _get_weighted_random_splat()
	
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
	modulate = dimmed_color
