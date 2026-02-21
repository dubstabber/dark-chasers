extends StaticBody3D


func _on_tree_exiting() -> void:
	Services.utils.play_sound(Services.get_sfx_catalog().wall_cut, get_parent(), global_position, -15)
