@tool
class_name ParticleCatalog
extends Resource

## Catalog of particle/scrap images and related sounds.
## Replaces hardcoded arrays in Preloads for better maintainability and editor tooling.
##
## NOTE: Entries are stored as concrete Resource types so the catalog can be extended
## via inspector edits without modifying this script.

@export var texture_sets: Array[ParticleTextureSetEntry] = []
@export var sounds: Array[ParticleSoundEntry] = []
@export var scenes: Array[ParticleSceneEntry] = []

# NOTE: GDScript does not support nested typed collections like Dictionary[StringName, Array[Texture2D]].
# These dictionaries are logically typed as:
# - _textures_by_id: StringName -> Array[Texture2D]
# - _weights_by_id: StringName -> Array[int]
var _textures_by_id: Dictionary = {}
var _weights_by_id: Dictionary = {}
var _sounds_by_id: Dictionary[StringName, AudioStream] = {}
var _scenes_by_id: Dictionary[StringName, PackedScene] = {}
var _cache_valid := false


func _init() -> void:
	changed.connect(_invalidate_cache)


func _invalidate_cache() -> void:
	_cache_valid = false


func _ensure_cache() -> void:
	if _cache_valid:
		return

	_textures_by_id.clear()
	_weights_by_id.clear()
	_sounds_by_id.clear()
	_scenes_by_id.clear()

	for entry in texture_sets:
		if entry == null:
			continue
		if entry.id == &"":
			continue
		if _textures_by_id.has(entry.id):
			push_warning("ParticleCatalog: Duplicate texture_set id '%s'" % String(entry.id))

		var textures: Array[Texture2D] = []
		var weights: Array[int] = []
		var can_use_weights := entry.weights.size() == entry.textures.size()
		for i in range(entry.textures.size()):
			var tex := entry.textures[i]
			if tex == null:
				continue
			textures.append(tex)
			var w := 1
			if can_use_weights:
				w = maxi(1, entry.weights[i])
			weights.append(w)

		_textures_by_id[entry.id] = textures
		_weights_by_id[entry.id] = weights

	for entry in sounds:
		if entry == null:
			continue
		if entry.id == &"":
			continue
		if _sounds_by_id.has(entry.id):
			push_warning("ParticleCatalog: Duplicate sound id '%s'" % String(entry.id))
		_sounds_by_id[entry.id] = entry.sound

	for entry in scenes:
		if entry == null:
			continue
		if entry.id == &"":
			continue
		if _scenes_by_id.has(entry.id):
			push_warning("ParticleCatalog: Duplicate scene id '%s'" % String(entry.id))
		_scenes_by_id[entry.id] = entry.scene

	_cache_valid = true


func get_textures(id: StringName) -> Array[Texture2D]:
	_ensure_cache()
	if _textures_by_id.has(id):
		var textures: Array[Texture2D] = _textures_by_id[id]
		return textures
	var empty: Array[Texture2D] = []
	return empty


func get_random_texture(id: StringName) -> Texture2D:
	var textures := get_textures(id)
	return textures.pick_random() if not textures.is_empty() else null


func get_first_texture(id: StringName) -> Texture2D:
	var textures := get_textures(id)
	return textures[0] if not textures.is_empty() else null


func get_weighted_random_texture(id: StringName, fallback_weights: Array[int] = []) -> Texture2D:
	_ensure_cache()
	if not _textures_by_id.has(id):
		return null

	var textures: Array[Texture2D] = _textures_by_id[id]
	if textures.is_empty():
		return null

	var weights: Array[int] = []
	if _weights_by_id.has(id):
		var cached_weights: Array[int] = _weights_by_id[id]
		if cached_weights.size() == textures.size():
			weights = cached_weights
	else:
		for _i in range(textures.size()):
			weights.append(1)

	var can_use_fallback := fallback_weights.size() == textures.size()
	var all_ones := true
	for w in weights:
		if w != 1:
			all_ones = false
			break
	if all_ones and can_use_fallback:
		weights = fallback_weights

	var total_weight := 0
	for w in weights:
		total_weight += w
	if total_weight <= 0:
		return textures[0]

	var random_value := randi() % total_weight
	var cumulative := 0
	for i in range(weights.size()):
		cumulative += weights[i]
		if random_value < cumulative:
			return textures[i]

	return textures[0]


func get_sound(id: StringName) -> AudioStream:
	_ensure_cache()
	return _sounds_by_id[id] if _sounds_by_id.has(id) else null


func get_scene(id: StringName) -> PackedScene:
	_ensure_cache()
	return _scenes_by_id[id] if _scenes_by_id.has(id) else null


func get_scrap_scene() -> PackedScene:
	return get_scene(&"scrap")


# Legacy-friendly convenience helpers.
func get_random_small_wood() -> Texture2D:
	return get_random_texture(&"small_wood")


func get_random_big_wood() -> Texture2D:
	return get_random_texture(&"big_wood")


func get_random_paper() -> Texture2D:
	return get_random_texture(&"paper")


func get_random_glass() -> Texture2D:
	return get_random_texture(&"glass")


func get_random_pot() -> Texture2D:
	return get_random_texture(&"pot")


func get_random_doom_decal() -> Texture2D:
	return get_random_texture(&"doom_decal")
