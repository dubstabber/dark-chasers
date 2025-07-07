extends RayCast3D

@onready var body = get_parent()


func _physics_process(_delta):
	if is_colliding():
		var collider = get_collider()
		if collider and collider.get_parent() is MeshInstance3D:
			var mesh = collider.get_parent()
			if mesh.mesh.get_surface_count() == 1:
				print(mesh.mesh)

