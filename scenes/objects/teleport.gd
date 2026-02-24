extends Area3D

@export var level_name: String
@export var target_spawn_id: StringName = &""

var spawn_marker: Marker3D


func _ready():
	if not level_name:
		for n in get_children():
			if n.is_in_group("spawn_point"):
				spawn_marker = n


func _on_body_entered(body: Node3D) -> void:
	if level_name:
		if Services and Services.level_manager:
			Services.level_manager.request_level_transition(level_name, {
				"spawn_id": target_spawn_id,
				"from_teleport": get_path(),
				"triggering_body_name": body.name
			})
		else:
			push_warning("Teleport: Services.level_manager not available; cannot transition to %s" % level_name)
	elif spawn_marker:
		body.global_position = spawn_marker.global_position
