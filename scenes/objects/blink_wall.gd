extends StaticBody3D


func _on_tree_exiting() -> void:
	Services.utils.play_sound(Services.preloads.WALLCUT_SOUND, get_parent(), global_position, -15)
