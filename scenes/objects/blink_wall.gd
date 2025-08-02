extends StaticBody3D


func _on_tree_exiting() -> void:
	Utils.play_sound(Preloads.WALLCUT_SOUND, get_parent(), global_position, -15)
