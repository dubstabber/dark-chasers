class_name DoorAabbUtils
extends RefCounted

## Shared utility for computing merged local AABB from door mesh instances.

static func get_door_aabb(meshes: Array[MeshInstance3D]) -> AABB:
	var has_mesh := false
	var merged_aabb: AABB

	for mesh_instance in meshes:
		if mesh_instance:
			var aabb := mesh_instance.get_aabb()
			aabb.position += mesh_instance.transform.origin
			if not has_mesh:
				merged_aabb = aabb
				has_mesh = true
			else:
				merged_aabb = merged_aabb.merge(aabb)

	if has_mesh:
		return merged_aabb

	return AABB(Vector3.ZERO, Vector3.ONE)
