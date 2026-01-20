extends Node

## VFX pooling service to reduce instancing spikes for bursty effects.
## Maintains pools of reusable scene instances (scrap, particles, decals).

signal pool_exhausted(scene_path: String)

@export var default_pool_size: int = 32

var _pools: Dictionary = {} # scene_path -> Array of instances
var _active: Dictionary = {} # scene_path -> count of active instances


func _ready() -> void:
	# Pre-warm common VFX pools
	call_deferred("_prewarm_pools")


func _prewarm_pools() -> void:
	var vfx_catalog = Preloads.get_vfx_catalog()
	if vfx_catalog and vfx_catalog.scrap_scene:
		_ensure_pool(vfx_catalog.scrap_scene.resource_path, vfx_catalog.scrap_scene)


func _ensure_pool(path: String, scene: PackedScene) -> void:
	if path in _pools:
		return
	
	_pools[path] = []
	_active[path] = 0
	
	for i in range(default_pool_size):
		var instance = scene.instantiate()
		instance.set_meta("_pool_path", path)
		instance.visible = false
		add_child(instance)
		_pools[path].append(instance)


func get_instance(scene: PackedScene) -> Node:
	if not scene:
		return null
	
	var path = scene.resource_path
	
	# Ensure pool exists
	if path not in _pools:
		_ensure_pool(path, scene)
	
	# Find available instance
	for instance in _pools[path]:
		if not instance.visible:
			instance.visible = true
			_active[path] = _active.get(path, 0) + 1
			return instance
	
	# Pool exhausted - create overflow instance
	pool_exhausted.emit(path)
	var overflow = scene.instantiate()
	overflow.set_meta("_pool_path", path)
	overflow.set_meta("_pool_overflow", true)
	return overflow


func release_instance(instance: Node) -> void:
	if not instance:
		return
	
	var path = instance.get_meta("_pool_path", "")
	
	# Handle overflow instances
	if instance.get_meta("_pool_overflow", false):
		instance.queue_free()
		return
	
	# Return to pool
	instance.visible = false
	if instance.get_parent() != self:
		instance.get_parent().remove_child(instance)
		add_child(instance)
	
	if path in _active:
		_active[path] = max(0, _active[path] - 1)
	
	# Reset common properties
	if instance is RigidBody3D:
		instance.linear_velocity = Vector3.ZERO
		instance.angular_velocity = Vector3.ZERO
	if "position" in instance:
		instance.position = Vector3.ZERO


func get_pool_stats() -> Dictionary:
	var stats = {}
	for path in _pools:
		var available = 0
		for instance in _pools[path]:
			if not instance.visible:
				available += 1
		stats[path] = {
			"pool_size": _pools[path].size(),
			"active": _active.get(path, 0),
			"available": available
		}
	return stats
