extends AudioStreamPlayer3D

class_name DarkChasersFootstepSurfaceDetector

@export var generic_fallback_footstep_profile: AudioStreamRandomizer
@export var footstep_material_library: Resource
@export var cache_grid_size: float = 0.5 # Size of grid cells for position snapping in cache

var last_result

# Cache: maps "collider_id:snapped_x:snapped_y:snapped_z" -> Material (or null for no material)
var _material_cache: Dictionary = {}
const MAX_CACHE_SIZE: int = 128

var _footstep_surface_child_cache: Dictionary = {}
const MAX_SURFACE_CACHE_SIZE: int = 128

var _triangle_surface_map_cache: Dictionary = {}
const MAX_TRIANGLE_MAP_CACHE_SIZE: int = 64


func play_footstep():
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -1, 0))
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		last_result = result
		if _play_by_footstep_surface(result.collider):
			return
		elif _play_by_material(result.collider):
			return
		#if no material, play generics
		else:
			_play_footstep(generic_fallback_footstep_profile)

func _play_by_footstep_surface(collider: Node3D) -> bool:
	#check for footstep surface as a child of the collider
	var footstep_surface_child: AudioStreamRandomizer = _get_footstep_surface_child(collider)
	#if a child footstep surface was found, then play the sound defined by it
	if footstep_surface_child:
		_play_footstep(footstep_surface_child)
		return true
	#handle footstep surface settings
	elif collider is FootstepSurface and collider.footstep_profile:
		_play_footstep(collider.footstep_profile)
		return true
	return false

func _play_by_material(collider: Node3D) -> bool:
	# if no footstep surface, see if we can get a material
	if footstep_material_library:
		#find surface material
		var material: Material = _get_surface_material(collider)
		#if a material was found
		if material:
			#get a profile from our library
			var material_name = material.resource_name
			var footstep_profile = footstep_material_library.get_footstep_profile_by_material_name(material_name)
			#found profile, use it
			if footstep_profile:
				_play_footstep(footstep_profile)
				return true
	return false

func _get_footstep_surface_child(collider: Node3D) -> AudioStreamRandomizer:
	var collider_id := collider.get_instance_id()
	if _footstep_surface_child_cache.has(collider_id):
		return _footstep_surface_child_cache[collider_id]

	var footstep_surface_child_profile: AudioStreamRandomizer = null
	var footstep_surfaces = collider.find_children("", "FootstepSurface")
	if footstep_surfaces:
		footstep_surface_child_profile = footstep_surfaces[0].footstep_profile

	if _footstep_surface_child_cache.size() >= MAX_SURFACE_CACHE_SIZE:
		var keys = _footstep_surface_child_cache.keys()
		for i in range(MAX_SURFACE_CACHE_SIZE >> 1):
			_footstep_surface_child_cache.erase(keys[i])
	_footstep_surface_child_cache[collider_id] = footstep_surface_child_profile
	return footstep_surface_child_profile

func _get_cache_key(collider: Node3D, hit_position: Vector3) -> String:
	# Snap position to grid for cache key
	var snapped_x = floori(hit_position.x / cache_grid_size)
	var snapped_y = floori(hit_position.y / cache_grid_size)
	var snapped_z = floori(hit_position.z / cache_grid_size)
	return "%d:%d:%d:%d" % [collider.get_instance_id(), snapped_x, snapped_y, snapped_z]


func _get_surface_material(collider: Node3D) -> Material:
	# Check cache first for expensive multi-surface mesh lookups
	var hit_position: Vector3 = last_result.get('position', global_position)
	var cache_key := _get_cache_key(collider, hit_position)
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	
	var material := _get_surface_material_uncached(collider)
	
	# Store in cache (with size limit)
	if _material_cache.size() >= MAX_CACHE_SIZE:
		# Simple eviction: clear half the cache
		var keys = _material_cache.keys()
		for i in range(MAX_CACHE_SIZE >> 1): # Evict half
			_material_cache.erase(keys[i])
	_material_cache[cache_key] = material
	
	return material


func _get_surface_material_uncached(collider: Node3D) -> Material:
	var mesh_instance = null
	var meshes = []
	var hit_position: Vector3 = last_result.get('position', global_position)
	if collider is CSGShape3D:
		if collider is CSGCombiner3D:
			#composite mesh
			if collider.material_override:
				return collider.material_override
			meshes = collider.get_meshes()
		else:
			return collider.material
	elif collider is StaticBody3D or collider is RigidBody3D:
		#find all children of the collider static body that are of type "MeshInstance3D"
		#if there are multiple materials, just default to the first one found
		if collider.get_parent() is MeshInstance3D:
			mesh_instance = collider.get_parent()
		else:
			var mesh_instances = collider.find_children("", "MeshInstance3D")
			if mesh_instances:
				if len(mesh_instances) == 1:
					mesh_instance = mesh_instances[0]
				else:
					meshes = mesh_instances
	
	if meshes:
		mesh_instance = _pick_mesh_instance_for_hit(meshes, hit_position)
	
	if mesh_instance is MeshInstance3D:
		var mesh = mesh_instance.mesh
		if mesh == null:
			return null
		if mesh.get_surface_count() == 0:
			return null
		elif mesh.get_surface_count() == 1:
			return mesh.surface_get_material(0)
		else:
			var hit_triangle_index: int = int(last_result.get("face_index", -1))
			if hit_triangle_index < 0:
				hit_triangle_index = _find_hit_triangle_index(mesh_instance, mesh, hit_position)

			if hit_triangle_index >= 0:
				var surface_index: int = _get_surface_index_for_triangle(mesh, hit_triangle_index)
				if surface_index >= 0 and surface_index < mesh.get_surface_count():
					return mesh.surface_get_material(surface_index)
			return null
	return null


func _find_hit_triangle_index(mesh_instance: MeshInstance3D, mesh: Mesh, hit_position: Vector3) -> int:
	var ray: Vector3 = hit_position - global_position
	var faces: PackedVector3Array = mesh.get_faces()

	for i in range(int(faces.size() / 3.0)):
		var face_idx: int = i * 3
		var a: Vector3 = mesh_instance.to_global(faces[face_idx])
		var b: Vector3 = mesh_instance.to_global(faces[face_idx + 1])
		var c: Vector3 = mesh_instance.to_global(faces[face_idx + 2])
		var ray_t = Geometry3D.ray_intersects_triangle(global_position, ray, a, b, c)
		if ray_t:
			return i

	return -1


func _get_surface_index_for_triangle(mesh: Mesh, triangle_index: int) -> int:
	var mesh_id: int = mesh.get_instance_id()
	var triangle_to_surface: Array = _triangle_surface_map_cache.get(mesh_id, [])

	if triangle_to_surface.is_empty():
		triangle_to_surface = _build_triangle_surface_map(mesh)
		if _triangle_surface_map_cache.size() >= MAX_TRIANGLE_MAP_CACHE_SIZE:
			var keys: Array = _triangle_surface_map_cache.keys()
			for i in range(MAX_TRIANGLE_MAP_CACHE_SIZE >> 1):
				_triangle_surface_map_cache.erase(keys[i])
		_triangle_surface_map_cache[mesh_id] = triangle_to_surface

	if triangle_index < 0 or triangle_index >= triangle_to_surface.size():
		return -1

	return int(triangle_to_surface[triangle_index])


func _build_triangle_surface_map(mesh: Mesh) -> Array:
	var triangle_to_surface: Array = []
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue

		var triangle_count: int = 0
		var index_data = arrays[Mesh.ARRAY_INDEX]
		if index_data is PackedInt32Array and not index_data.is_empty():
			var indices: PackedInt32Array = index_data
			triangle_count = int(indices.size() / 3.0)
		else:
			var vertex_data = arrays[Mesh.ARRAY_VERTEX]
			if vertex_data is PackedVector3Array:
				var vertices: PackedVector3Array = vertex_data
				triangle_count = int(vertices.size() / 3.0)

		for _i in range(triangle_count):
			triangle_to_surface.append(surface_index)

	return triangle_to_surface


func _pick_mesh_instance_for_hit(meshes: Array, hit_position: Vector3) -> MeshInstance3D:
	var best_mesh: MeshInstance3D = null
	var best_distance_sq := INF

	for candidate in meshes:
		if not (candidate is MeshInstance3D):
			continue
		if candidate.mesh == null:
			continue

		var candidate_transform: Transform3D = candidate.global_transform if candidate.is_inside_tree() else candidate.transform
		var local_hit: Vector3 = candidate_transform.affine_inverse() * hit_position
		var mesh_aabb: AABB = candidate.mesh.get_aabb()
		var distance_sq: float = 0.0 if mesh_aabb.has_point(local_hit) else local_hit.distance_squared_to(mesh_aabb.get_center())

		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_mesh = candidate

	if best_mesh:
		return best_mesh

	for fallback in meshes:
		if fallback is MeshInstance3D:
			return fallback

	return null

func _play_footstep(footstep_profile: AudioStreamRandomizer):
	stream = footstep_profile
	play()
