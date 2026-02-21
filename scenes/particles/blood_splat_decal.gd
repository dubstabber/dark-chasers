extends Decal

## This decal is spawned when an enemy is shot and there's a wall behind them.
## The color can be customized per-enemy (e.g., blue for AoOni, red for normal enemies).

const DEFAULT_BLOOD_SPLAT_WEIGHTS := [2, 1, 5, 5, 5, 5, 6]

var _selected_texture: Texture2D
var _pending_color: Color = Color(-1, -1, -1, -1)
var _catalog: ParticleCatalog


func _ready() -> void:
	_catalog = Services.get_particle_catalog()
	_selected_texture = _get_weighted_random_splat()
	texture_albedo = _selected_texture
	modulate = Color.WHITE
	
	# Apply pending color if set_blood_color was called before _ready
	if _pending_color.r >= 0:
		_apply_blood_tint(_pending_color)
	
	# Random rotation for variety (replaces flip_h/flip_v from Sprite3D)
	# Decals don't have flip properties, so we rotate in 90-degree increments
	var random_rotation := randi() % 4
	rotate_y(random_rotation * PI / 2.0)


func _get_weighted_random_splat() -> Texture2D:
	## Select a blood splat image using weighted random selection.
	if not _catalog or _catalog.blood_splat_images.is_empty():
		return null

	var splat_images := _catalog.blood_splat_images
	var weights := _catalog.blood_splat_weights if _catalog.blood_splat_weights.size() == splat_images.size() else DEFAULT_BLOOD_SPLAT_WEIGHTS
	if weights.size() != splat_images.size():
		weights = []
		for _i in range(splat_images.size()):
			weights.append(1)

	var total_weight := 0
	for weight in weights:
		total_weight += weight
	
	if total_weight <= 0:
		return splat_images[0]

	var random_value := randi() % total_weight
	var cumulative := 0
	
	for i in range(weights.size()):
		cumulative += weights[i]
		if random_value < cumulative:
			return splat_images[i]
	
	return splat_images[0]


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

	_apply_blood_tint(dimmed_color)


func _apply_blood_tint(tint_color: Color) -> void:
	modulate = tint_color
