@tool
extends EditorScript


var materials_updated: int


func _run():
	update_all_materials_in_scene()


func update_all_materials_in_scene():
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		print("No scene is currently open")
		return
	
	materials_updated = 0
	_process_node_materials(root)
	print("Updated ", materials_updated, " materials")


func _process_node_materials(node: Node):
	# Check if node has a mesh (MeshInstance3D)
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		
		# Update materials on the mesh instance
		for i in range(mesh_instance.get_surface_override_material_count()):
			var material = mesh_instance.get_surface_override_material(i)
			if material and material is StandardMaterial3D:
				_update_material_settings(material)
				materials_updated += 1
		
		# Also check the mesh's built-in materials
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var material = mesh_instance.mesh.surface_get_material(i)
				if material and material is StandardMaterial3D:
					_update_material_settings(material)
					materials_updated += 1
	
	# Recursively process children
	for child in node.get_children():
		_process_node_materials(child)


func _update_material_settings(material: StandardMaterial3D):
	# Set transparency to alpha
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Set depth draw mode to always
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	
	# Optionally set other common settings
	# material.no_depth_test = false
	# material.albedo_color.a = 1.0  # Ensure alpha is set if needed
