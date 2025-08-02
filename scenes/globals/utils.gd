extends Node


func safe_look_at(node: Node3D, target: Vector3) -> void:
	var origin: Vector3 = node.global_transform.origin
	var v_z := (origin - target).normalized()

	# Just return if at same position
	if origin == target:
		return

	# Find an up vector that we can rotate around
	var up := Vector3.ZERO
	for entry in [Vector3.UP, Vector3.RIGHT, Vector3.BACK]:
		var v_x: Vector3 = entry.cross(v_z).normalized()
		if v_x.length() != 0:
			up = entry
			break

	# Look at the target
	if up != Vector3.ZERO:
		node.look_at(target, up)

func play_sound(sound_source: AudioStream, parent_node:Node = self, pos: Vector3 = Vector3.ZERO, volume: float = -25):
	var sound = AudioStreamPlayer3D.new()
	parent_node.add_child.call_deferred(sound)
	sound.position = pos
	sound.stream = sound_source
	sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	sound.volume_db = volume
	sound.connect("finished", sound.queue_free)
	sound.play.call_deferred()
	return sound


func play_footstep_sound(sound_source: AudioStream, parent_node:Node = self):
	var sound = AudioStreamPlayer3D.new()
	parent_node.add_child(sound)
	sound.stream = sound_source
	sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	sound.volume_db = -20
	sound.connect("finished", sound.queue_free)
	sound.play()
