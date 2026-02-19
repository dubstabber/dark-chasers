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

func play_sound(sound_source: AudioStream, parent_node: Node = self, pos: Vector3 = Vector3.ZERO, volume: float = -25):
	# Use pooled audio service
	# If pos is default and parent_node has a position, use parent's global position
	var final_pos = pos
	if pos == Vector3.ZERO and parent_node is Node3D:
		final_pos = parent_node.global_position
	return Services.audio_pool.play_sound_3d(sound_source, final_pos, volume)


func play_footstep_sound(sound_source: AudioStream, parent_node: Node = self):
	# Use pooled audio service (parent_node kept for API compatibility)
	var pos = parent_node.global_position if parent_node is Node3D else Vector3.ZERO
	return Services.audio_pool.play_footstep(sound_source, pos)


func debug_log(message: String) -> void:
	if OS.is_debug_build() or Engine.is_editor_hint():
		print(message)


func debug_warning(message: String) -> void:
	if OS.is_debug_build() or Engine.is_editor_hint():
		push_warning(message)
