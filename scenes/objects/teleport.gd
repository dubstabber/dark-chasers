extends Area3D

## Deprecated: raw res:// path. Prefer destination_catalog_key.
@export var level_name: String
## SceneCatalog property name to use as destination (e.g. &"room_1_scene", &"mansion_1_scene").
@export var destination_catalog_key: StringName = &""
@export var target_spawn_id: StringName = &""

var spawn_marker: Marker3D


func _ready():
	if not _has_level_destination():
		for n in get_children():
			if n.is_in_group("spawn_point"):
				spawn_marker = n
				break


func _on_body_entered(body: Node3D) -> void:
	if _has_level_destination():
		if not (Services and Services.level_manager):
			push_warning("Teleport: Services.level_manager not available; cannot transition")
			return

		var context := {
			"spawn_id": target_spawn_id,
			"from_teleport": get_path(),
			"triggering_body_name": body.name,
		}

		var scene := _resolve_destination_scene()
		if scene and Services.level_manager.has_method("request_level_transition_scene"):
			Services.level_manager.request_level_transition_scene(scene, context)
			return

		# Legacy fallback (raw path). Prefer destination_catalog_key.
		if level_name:
			Services.level_manager.request_level_transition(level_name, context)
			return

		push_warning("Teleport: Destination scene not configured (missing destination_catalog_key / level_name)")
	elif spawn_marker:
		body.global_position = spawn_marker.global_position


func _has_level_destination() -> bool:
	return destination_catalog_key != &"" or (level_name != null and level_name != "")


func _resolve_destination_scene() -> PackedScene:
	if destination_catalog_key == &"":
		return null
	if not Services:
		return null
	var catalog: SceneCatalog = Services.get_scene_catalog()
	if not catalog:
		return null

	var key := String(destination_catalog_key)
	var value: Variant = catalog.get(key)
	if value is PackedScene:
		return value
	push_warning("Teleport: SceneCatalog key '%s' is missing or not a PackedScene" % key)
	return null
