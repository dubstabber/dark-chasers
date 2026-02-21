class_name DestructibleComponent
extends Node

## Reusable component for destructible objects.
## Handles health tracking, damage processing, and scrap spawning on destruction.

signal destroyed()

@export var health: int = 5
@export var destroy_sound: AudioStream
@export var scrap_definitions: Array[ScrapDefinition] = []
@export var free_on_destroy: bool = true

var _is_destroyed := false


func take_damage(dmg: int) -> void:
	if _is_destroyed:
		return

	health -= dmg
	if health <= 0:
		_destroy()


func _destroy() -> void:
	_is_destroyed = true
	var parent = owner

	if destroy_sound:
		Services.utils.play_sound(destroy_sound, parent.get_parent(), parent.position)

	var catalog: ParticleCatalog = Services.get_particle_catalog()

	for definition in scrap_definitions:
		var count = definition.count
		if not definition.count_variation.is_empty():
			count = definition.count_variation.pick_random()

		for i in count:
			var scrap = catalog.scrap_scene.instantiate()
			parent.get_parent().add_child(scrap)
			scrap.set_scrap_type(definition.scrap_type)
			scrap.position = parent.global_position + definition.position_offset
			scrap.linear_velocity = Vector3(
				randf_range(-definition.horizontal_velocity, definition.horizontal_velocity),
				definition.vertical_velocity,
				randf_range(-definition.horizontal_velocity, definition.horizontal_velocity)
			)

	destroyed.emit()

	if free_on_destroy:
		parent.queue_free()


func is_destroyed() -> bool:
	return _is_destroyed
