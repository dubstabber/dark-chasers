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

func play_sound(soundType: AudioStream, parentNode:Node = self):
	var sound = AudioStreamPlayer3D.new()
	parentNode.add_child(sound)
	sound.stream = soundType
	sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	sound.volume_db = -25
	sound.connect("finished", sound.queue_free)
	sound.play()

func play_footstep_sound(soundType: AudioStream, parentNode:Node = self):
	var sound = AudioStreamPlayer3D.new()
	parentNode.add_child(sound)
	sound.stream = soundType
	sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	sound.volume_db = -25
	sound.connect("finished", sound.queue_free)
	sound.play()
