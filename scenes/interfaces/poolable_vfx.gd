class_name PoolableVfx
extends RefCounted

## Interface adapter for pooled VFX lifecycle.
## Implementers may define optional hooks:
##   - on_borrowed()
##   - on_returned()


static func on_borrowed(instance: Node) -> void:
	if not instance:
		return

	_set_processing_enabled(instance, true)
	if instance.has_method("on_borrowed"):
		instance.on_borrowed()


static func on_returned(instance: Node) -> void:
	if not instance:
		return

	if instance.has_method("on_returned"):
		instance.on_returned()
	_stop_particles(instance)
	_stop_timers(instance)
	_set_processing_enabled(instance, false)


static func _set_processing_enabled(instance: Node, enabled: bool) -> void:
	instance.set_process(enabled)
	instance.set_physics_process(enabled)
	instance.set_process_input(enabled)
	instance.set_process_unhandled_input(enabled)
	instance.set_process_unhandled_key_input(enabled)
	instance.set_process_shortcut_input(enabled)

	for child in instance.get_children():
		if child is Node:
			_set_processing_enabled(child, enabled)


static func _stop_particles(instance: Node) -> void:
	if instance is GPUParticles3D:
		instance.emitting = false
	elif instance is CPUParticles3D:
		instance.emitting = false

	for child in instance.get_children():
		if child is Node:
			_stop_particles(child)


static func _stop_timers(instance: Node) -> void:
	if instance is Timer:
		instance.stop()

	for child in instance.get_children():
		if child is Node:
			_stop_timers(child)
