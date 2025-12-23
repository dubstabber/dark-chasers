extends Sprite3D

## Blood splat decal for wall blood stains (DOOM-style)
##
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

## Weighted probabilities matching DOOM's decaldef.txt:
## BloodSplat1: 2, BloodSplat2: 1, BloodSplat3-6: 5 each, BloodSplat7: 6
const BLOOD_SPLAT_WEIGHTS := [2, 1, 5, 5, 5, 5, 6]


func _ready() -> void:
	# Select random blood splat image using weighted probability
	texture = _get_weighted_random_splat()
	
	# Random flip for variety (like DOOM's randomflipx/randomflipy)
	if randf() > 0.5:
		flip_h = true
	if randf() > 0.5:
		flip_v = true


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
	"""Set the blood color for this decal
	
	The blood splat images are white with alpha transparency, so modulating
	with a color will tint them to that color. We dim the color by 50% like
	DOOM does (bloodcolor.r >>= 1, etc.) to make decals look more natural.
	"""
	# Dim the color like DOOM does for wall blood decals
	var dimmed_color := Color(
		color.r * 0.5,
		color.g * 0.5,
		color.b * 0.5,
		1.0 # Full alpha - the texture handles transparency
	)
	modulate = dimmed_color
