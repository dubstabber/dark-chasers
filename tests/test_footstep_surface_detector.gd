extends SceneTree


func _init() -> void:
	print("=== FOOTSTEP SURFACE DETECTOR TESTS ===")
	test_pick_mesh_instance_for_hit_prefers_containing_mesh()
	test_pick_mesh_instance_for_hit_falls_back_to_valid_mesh()
	test_surface_index_for_triangle_map_uses_surface_order()
	print("=== FOOTSTEP SURFACE DETECTOR TESTS COMPLETED ===")
	quit(0)


func test_pick_mesh_instance_for_hit_prefers_containing_mesh() -> void:
	var detector = DarkChasersFootstepSurfaceDetector.new()
	var left_mesh := _make_mesh_instance(Vector3(-2, 0, 0))
	var right_mesh := _make_mesh_instance(Vector3(2, 0, 0))

	var selected = detector._pick_mesh_instance_for_hit([left_mesh, right_mesh], Vector3(2, 0, 0))

	assert(selected == right_mesh, "Should choose the mesh containing the hit point")
	detector.free()
	left_mesh.free()
	right_mesh.free()
	print("✓ picks mesh containing the hit point")


func test_pick_mesh_instance_for_hit_falls_back_to_valid_mesh() -> void:
	var detector = DarkChasersFootstepSurfaceDetector.new()
	var node_without_mesh := Node3D.new()
	var valid_mesh := _make_mesh_instance(Vector3.ZERO)

	var selected = detector._pick_mesh_instance_for_hit([node_without_mesh, valid_mesh], Vector3(20, 0, 0))

	assert(selected == valid_mesh, "Should ignore non-mesh nodes and return a valid mesh fallback")
	detector.free()
	node_without_mesh.free()
	valid_mesh.free()
	print("✓ falls back to first valid mesh when needed")


func test_surface_index_for_triangle_map_uses_surface_order() -> void:
	var detector = DarkChasersFootstepSurfaceDetector.new()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _make_triangle_arrays(Vector3(0, 0, 0)))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _make_triangle_arrays(Vector3(2, 0, 0)))

	var surface0 := detector._get_surface_index_for_triangle(mesh, 0)
	var surface1 := detector._get_surface_index_for_triangle(mesh, 1)

	assert(surface0 == 0, "First triangle should resolve to surface 0")
	assert(surface1 == 1, "Second triangle should resolve to surface 1")
	detector.free()
	print("✓ maps triangle indices to the expected surfaces")


func _make_mesh_instance(position: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	mesh_instance.position = position
	return mesh_instance


func _make_triangle_arrays(origin: Vector3) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		origin + Vector3(0, 0, 0),
		origin + Vector3(1, 0, 0),
		origin + Vector3(0, 1, 0),
	])
	return arrays
